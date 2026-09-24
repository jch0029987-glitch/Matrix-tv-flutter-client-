import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

class AppWebserver {
  static final AppWebserver _instance = AppWebserver._internal();
  factory AppWebserver() => _instance;
  AppWebserver._internal();

  HttpServer? _server;
  Client? _client;
  bool _isRunning = false;
  String? _lastError;
  final int _port = 8086;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get lastError => _lastError;

  void setClient(Client client) {
    _client = client;
  }

  /// Initialize notification channels and settings safely for Android TV banners
  Future<void> initNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('🔔 Notification tapped: ${details.payload}');
        },
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'matrix_tv_channel',
        'Matrix TV Notifications',
        description: 'High-priority heads-up alerts for incoming Matrix messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('🔔 Android TV notification channel successfully created & registered.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing notifications: $e');
      debugPrint('❌ StackTrace: $stackTrace');
    }
  }

  /// Checks runtime permissions with an OS-level settings fallback for Android TV
  Future<bool> requestPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // 🔑 Fallback check: Verify if already enabled at the Android OS level
        final bool? alreadyEnabled = await androidPlugin.areNotificationsEnabled();
        if (alreadyEnabled == true) {
          debugPrint('🔔 Notifications are already enabled in system settings.');
          return true;
        }

        // Otherwise, request the permission explicitly
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Notification permission dialog result: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('❌ Exception requesting notification permissions: $e');
    }
    return false;
  }

  /// Fire a test notification banner via the server backend
  Future<void> showTestNotification() async {
    final bool hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Permission denied or failed.');
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'matrix_tv_channel',
      'Matrix TV Notifications',
      channelDescription: 'High-priority heads-up alerts for incoming Matrix messages',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Matrix Message',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      'Matrix TV Remote',
      'Test notification from local web server!',
      details,
    );
    debugPrint('✅ Test notification successfully dispatched via web handler.');
  }

  Future<void> start() async {
    if (_isRunning) return;

    try {
      var cascade = Cascade()
          .add(_apiHandler())
          .add(createStaticHandler('assets/web', defaultDocument: 'index.html'));

      _server = await shelf_io.serve(cascade.handler, '0.0.0.0', _port);
      _isRunning = true;
      _lastError = null;
      debugPrint('🚀 Web server running on port $_port');
    } catch (e) {
      _isRunning = false;
      _lastError = e.toString();
      debugPrint('❌ Web server start error: $_lastError');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    debugPrint('🛑 Web server stopped.');
  }

  Handler _apiHandler() {
    return (Request request) async {
      final path = request.url.path;

      if (path == 'api/status') {
        return Response.ok(
          jsonEncode({
            'userId': _client?.userID ?? 'Not Logged In',
            'homeserver': _client?.homeserver.toString() ?? '-',
            'roomCount': _client?.rooms.length ?? 0,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (path == 'api/test_notification' && request.method == 'POST') {
        try {
          await showTestNotification();
          return Response.ok(jsonEncode({'success': true}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          return Response.internalServerError(
              body: jsonEncode({
                'success': false,
                'error': e.toString().replaceAll('Exception: ', '')
              }),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path == 'api/clipboard' && request.method == 'POST') {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);
          final text = data['text'] as String?;
          if (text != null) {
            await Clipboard.setData(ClipboardData(text: text));
            return Response.ok(jsonEncode({'success': true}),
                headers: {'Content-Type': 'application/json'});
          }
        } catch (e) {
          return Response.internalServerError(
              body: jsonEncode({'success': false, 'error': e.toString()}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      return Response.notFound('API endpoint not found');
    };
  }
}
