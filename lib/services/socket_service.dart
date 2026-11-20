import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

/// Realtime link to the backend.
///
/// Two things make this more than a thin wrapper around the socket:
///
///  * The handshake carries the access token, which expires every 15 minutes.
///    A refresh has to rebuild the connection, so listeners and room joins are
///    tracked here and replayed — otherwise a refreshed session would keep a
///    dead token and silently stop receiving events.
///  * Server-side room membership does not survive a reconnect. Rooms joined
///    through [joinRoom] are re-entered on every connect, so a dropped network
///    does not leave a chat or clique screen quietly deaf.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  /// Listeners registered by screens, re-attached whenever the socket is
  /// rebuilt for a new token.
  final Map<String, List<void Function(dynamic)>> _handlers = {};

  /// Room joins to replay after a (re)connect, as emit event -> ids.
  final Map<String, Set<String>> _rooms = {};

  /// The token the live socket handshook with, so a no-op refresh does not
  /// tear down a perfectly good connection.
  String? _connectedToken;

  bool _listeningForTokenChanges = false;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    _watchTokenChanges();

    final token = ApiClient().token;
    if (token == null || token.isEmpty) return;
    if (_socket != null && _connectedToken == token) return;

    // A token change means the existing socket can never re-authenticate.
    _teardown();
    _connectedToken = token;

    final socket = io.io(
      ApiClient().socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      debugPrint('Socket connected: ${socket.id}');
      _rejoinRooms();
    });

    socket.onDisconnect((_) => debugPrint('Socket disconnected'));
    socket.onError((err) => debugPrint('Socket error: $err'));
    socket.onConnectError((err) {
      debugPrint('Socket connect error: $err');
      // Most often an expired token. Refreshing publishes a new one, which
      // brings us back through [_onTokenChanged] with working credentials.
      ApiClient().refreshToken();
    });

    // Re-attach everything screens registered before this rebuild.
    _handlers.forEach((event, callbacks) {
      for (final cb in callbacks) {
        socket.on(event, cb);
      }
    });
  }

  void _watchTokenChanges() {
    if (_listeningForTokenChanges) return;
    _listeningForTokenChanges = true;
    ApiClient().accessTokenNotifier.addListener(_onTokenChanged);
  }

  void _onTokenChanged() {
    final token = ApiClient().accessTokenNotifier.value;
    if (token == null || token.isEmpty) {
      // Signed out: drop the connection but keep nothing stale behind.
      _teardown();
      _rooms.clear();
      return;
    }
    if (token == _connectedToken) return;
    connect();
  }

  void _rejoinRooms() {
    _rooms.forEach((event, ids) {
      for (final id in ids) {
        _socket?.emit(event, id);
      }
    });
  }

  /// Enters a server-side room and remembers it for reconnects.
  void joinRoom(String joinEvent, String id) {
    _rooms.putIfAbsent(joinEvent, () => <String>{}).add(id);
    connect();
    emit(joinEvent, id);
  }

  /// Leaves a room and stops replaying it.
  void leaveRoom(String joinEvent, String leaveEvent, String id) {
    _rooms[joinEvent]?.remove(id);
    emit(leaveEvent, id);
  }

  void _teardown() {
    final socket = _socket;
    _socket = null;
    _connectedToken = null;
    if (socket == null) return;
    socket.clearListeners();
    socket.dispose();
  }

  void disconnect() {
    _teardown();
    _handlers.clear();
    _rooms.clear();
  }

  void emit(String event, dynamic data) {
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit(event, data);
    }
  }

  void on(String event, void Function(dynamic) callback) {
    _handlers.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  /// Removes one handler, or every handler for the event when none is given.
  ///
  /// Several screens listen to the same event at once — the Clique tab and an
  /// open session both watch the lobby. Removing the lot when one of them
  /// closed left the other permanently deaf.
  void off(String event, [void Function(dynamic)? callback]) {
    if (callback == null) {
      _handlers.remove(event);
      _socket?.off(event);
      return;
    }
    final handlers = _handlers[event];
    if (handlers == null) return;
    handlers.remove(callback);
    _socket?.off(event, callback);
    if (handlers.isEmpty) _handlers.remove(event);
  }
}
