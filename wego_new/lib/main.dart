import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ ADD
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/providers/settings_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/providers/privacy_provider.dart';
import 'package:wego_marriage/screen/splash_screen.dart';
import 'package:wego_marriage/screen/incoming_call_screen.dart';
import 'package:wego_marriage/screen/epic_badges_screen.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/message_badge_service.dart';
import 'package:wego_marriage/screen/app_localizations.dart';
import 'package:wego_marriage/screen/app_translations.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App-wide RouteObserver — feed video cards (aur koi bhi auto-playing
/// media) `RouteAware` mixin use karke push/pop par foran pause/resume
/// hote hain. Bina iske Navigator.push pe video peeche bajti rehti hai.
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorageService().init();

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      MessageBadgeService.startListening();
    } else {
      MessageBadgeService.stopListening();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // PrivacyProvider auth changes ko khud listen karta hai aur jis
        // user ka session active hai uska `users/{uid}/privacy/settings`
        // doc live-stream kar leta hai. Constructor ke andar bhi listener
        // attach hota hai, plus explicit call yahan kar dete hain agar
        // app launch ke waqt already-signed-in user ho.
        ChangeNotifierProvider(
          create: (_) => PrivacyProvider()..listenToPrivacySettings(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final Set<String> _shownCallIds = {};

  StreamSubscription? _authSubscription;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCallListener();
    // App launch par presence true mark karo. PrivacyProvider khud hi
    // hideOnline/hideLastSeen ko respect karta hai — agar woh toggles ON
    // hon to RTDB par presence force-false rahe gi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PrivacyProvider>().setOnlinePresence(true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App foreground / background — presence flip karo.
    // NOTE: `inactive` deliberately handle nahi karte — yeh keyboard pop,
    //       notification panel pull-down, ya call screen overlay par bhi
    //       fire hota hai, jisse online flicker hota tha. `paused` aur
    //       `detached` hi true backgrounding indicate karte hain.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final privacy = ctx.read<PrivacyProvider>();
    if (state == AppLifecycleState.resumed) {
      privacy.setOnlinePresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      privacy.setOnlinePresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  void _startCallListener() {
    print('🚀 Call listener shuru ho raha hai...');

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
          _callSubscription?.cancel();
          _callSubscription = null;
          _shownCallIds.clear();

          if (user == null) {
            print('❌ User logged out hai');
            return;
          }

          print('✅ User logged in: ${user.uid}');

          _callSubscription = FirebaseFirestore.instance
              .collection('calls')
              .where('receiverId', isEqualTo: user.uid)
              .snapshots()
              .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              final data =
                  change.doc.data() as Map<String, dynamic>? ?? {};
              final status = data['status'] as String? ?? '';
              final callId = change.doc.id;

              print(
                  '📄 Change: ${change.type} | callId: $callId | status: $status');

              if (change.type == DocumentChangeType.added &&
                  status == 'ringing') {
                if (_shownCallIds.contains(callId)) {
                  print('⚠️ Already shown: $callId');
                  continue;
                }

                _shownCallIds.add(callId);

                final callType = (data['callType'] as String? ??
                    data['type'] as String? ??
                    'voice');
                final callerId = data['callerId'] as String? ?? '';

                print(
                    '📲 Call aa rahi hai! callId: $callId | type: $callType');

                _fetchCallerAndShowScreen(
                  callId: callId,
                  callerId: callerId,
                  callType: callType,
                );
              }

              if (status == 'ended' ||
                  status == 'declined' ||
                  status == 'cancelled' ||
                  status == 'timeout' ||
                  change.type == DocumentChangeType.removed) {
                print('🔕 Call khatam: $callId');
                _shownCallIds.remove(callId);
              }

              if (change.type == DocumentChangeType.modified &&
                  status == 'ringing') {
                if (!_shownCallIds.contains(callId)) {
                  _shownCallIds.add(callId);
                  final callType = (data['callType'] as String? ??
                      data['type'] as String? ??
                      'voice');
                  final callerId = data['callerId'] as String? ?? '';
                  _fetchCallerAndShowScreen(
                    callId: callId,
                    callerId: callerId,
                    callType: callType,
                  );
                }
              }
            }
          }, onError: (e) {
            print('💥 Call listener error: $e');
          });
        });
  }

  Future<void> _fetchCallerAndShowScreen({
    required String callId,
    required String callerId,
    required String callType,
  }) async {
    print('🔔 Screen show karne ki koshish: $callId');

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();

      if (!callDoc.exists) {
        print('❌ Call doc exist nahi');
        _shownCallIds.remove(callId);
        return;
      }

      final status = callDoc.data()?['status'] as String?;

      if (status != 'ringing') {
        print('⚠️ Status ringing nahi ($status) — skip');
        _shownCallIds.remove(callId);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(callerId)
          .get();

      String callerName = 'Unknown';
      String callerImage = '';

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        callerName = userData['name'] as String? ??
            userData['displayName'] as String? ??
            userData['username'] as String? ??
            'Unknown';

        callerImage = userData['photoUrl'] as String? ??
            userData['profileImage'] as String? ??
            userData['image'] as String? ??
            userData['photoURL'] as String? ??
            '';
      }

      print('👤 Caller: $callerName | Type: $callType');

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        print('❌ Context null — screen show nahi ho sakti');
        return;
      }

      final currentRoute = ModalRoute.of(context);
      if (currentRoute?.settings.name == '/incoming_call') {
        print('⚠️ IncomingCallScreen pehle se open hai');
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/incoming_call'),
          builder: (_) => IncomingCallScreen(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerImage: callerImage,
            callType: callType,
          ),
        ),
      );

      print('✅ IncomingCallScreen show ho gayi!');
    } catch (e) {
      print('💥 Error: $e');
      _shownCallIds.remove(callId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          title: 'WeGo Marriage',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          // Routes par push/pop notifications — `RouteAware` widgets
          // (jaise feed video cards) instantly pause/resume kar sakein.
          navigatorObservers: [appRouteObserver],

          // ✅ LANGUAGE SYSTEM — YE TEEN CHEEZEIN ADD KI HAIN
          locale: settingsProvider.currentLocale,
          supportedLocales: const [
            Locale('en'), Locale('ur'), Locale('hi'), Locale('ar'),
            Locale('zh'), Locale('ko'), Locale('ja'), Locale('fr'),
            Locale('es'), Locale('de'), Locale('it'), Locale('pt'),
            Locale('ru'), Locale('tr'), Locale('fa'), Locale('bn'),
            Locale('pa'), Locale('gu'), Locale('mr'), Locale('ta'),
            Locale('te'), Locale('ml'), Locale('kn'), Locale('si'),
            Locale('ne'), Locale('th'), Locale('vi'), Locale('id'),
            Locale('ms'), Locale('fil'),Locale('nl'), Locale('pl'),
            Locale('uk'), Locale('ro'), Locale('hu'), Locale('cs'),
            Locale('sv'), Locale('no'), Locale('da'), Locale('fi'),
            Locale('el'), Locale('he'), Locale('sw'), Locale('am'),
            Locale('ha'), Locale('yo'), Locale('zu'), Locale('my'),
            Locale('km'), Locale('lo'), Locale('mn'), Locale('kk'),
            Locale('uz'), Locale('az'), Locale('ka'), Locale('hy'),
            Locale('sr'), Locale('hr'), Locale('sk'), Locale('bg'),
            Locale('ca'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,   // Material widgets
            GlobalWidgetsLocalizations.delegate,    // Text direction (RTL/LTR)
            GlobalCupertinoLocalizations.delegate,  // iOS style widgets
          ],
          // ✅ END LANGUAGE SYSTEM

          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Poppins',
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF4A6CF7),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            fontFamily: 'Poppins',
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: settingsProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}