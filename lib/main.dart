import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/providers/settings_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/screen/splash_screen.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';
import 'package:wego_marriage/services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalStorageService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          title: 'WeGo Marriage',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Poppins',
            primaryColor: const Color(0xFF7A1730),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7A1730),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF7A1730),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            fontFamily: 'Poppins',
            primaryColor: const Color(0xFF7A1730),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7A1730),
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomeFeedScreen(),
        );
      },
    );
  }
}
