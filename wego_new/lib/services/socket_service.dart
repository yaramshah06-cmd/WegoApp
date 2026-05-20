import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;

/// Singleton Socket.IO service for signaling + random match queue.
///
/// Connects to the signaling server. Defaults to the Android emulator host
/// (10.0.2.2). For real devices, set [serverUrl] to your machine's LAN IP
/// (e.g. http://192.168.1.10:3000) before calling [connect].
class SocketService {
  SocketService._internal();

  static final SocketService instance = SocketService._internal();
  factory SocketService() => instance;

  /// Primary URL (Android emulator loopback to host).
  String serverUrl = 'http://10.0.2.2:3000';

  /// Fallback URL — change this to your machine's LAN IP for real-device tests.
  String fallbackUrl = 'http://192.168.1.10:3000';

  sio.Socket? _socket;
  String? _registeredUserId;
  bool _triedFallback = false;

  // ── Random match callbacks ──
  void Function(String matchedUserId)? onMatchFound;
  void Function()? onWaiting;
  void Function()? onMatchCancelled;
  void Function(String reason)? onError;

  sio.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// Connect to the signaling server and (optionally) register the user.
  /// Safe to call multiple times — re-uses existing connection.
  Future<void> connect({String? userId}) async {
    if (_socket != null && _socket!.connected) {
      if (userId != null) registerUser(userId);
      return;
    }

    _socket?.dispose();
    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1500)
          .build(),
    );

    _bindEvents();
    _socket!.connect();

    if (userId != null) {
      _registeredUserId = userId;
      // register fires after onConnect
    }
  }

  void _bindEvents() {
    final s = _socket!;
    s.onConnect((_) {
      _triedFallback = false;
      if (_registeredUserId != null) {
        s.emit('register', _registeredUserId);
      }
    });

    s.onConnectError((err) {
      if (!_triedFallback && fallbackUrl.isNotEmpty && fallbackUrl != serverUrl) {
        _triedFallback = true;
        serverUrl = fallbackUrl;
        s.io.uri = serverUrl;
        s.connect();
      } else {
        onError?.call('Connection error: $err');
      }
    });

    s.onError((err) => onError?.call('Socket error: $err'));

    // Match queue events
    s.on('waiting_for_match', (_) => onWaiting?.call());
    s.on('match_found', (data) {
      final id = (data is Map ? data['matchedUserId'] : null)?.toString();
      if (id != null && id.isNotEmpty) onMatchFound?.call(id);
    });
    s.on('match_cancelled', (_) => onMatchCancelled?.call());
  }

  /// Register the current Firebase user with the server.
  void registerUser(String userId) {
    _registeredUserId = userId;
    if (_socket == null) {
      connect(userId: userId);
      return;
    }
    if (_socket!.connected) {
      _socket!.emit('register', userId);
    }
  }

  void findMatch() {
    _socket?.emit('find_match');
  }

  void cancelMatch() {
    _socket?.emit('cancel_match');
  }

  /// Generic emit for call signaling reuse (call-user, answer-call, etc.).
  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  /// Generic listener helper for call signaling reuse.
  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  /// Remove only the random-match callbacks (keeps socket alive for calls).
  void clearMatchCallbacks() {
    onMatchFound = null;
    onWaiting = null;
    onMatchCancelled = null;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _registeredUserId = null;
  }
}
