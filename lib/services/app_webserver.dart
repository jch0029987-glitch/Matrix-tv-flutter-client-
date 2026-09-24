import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppWebserver {
  static final AppWebserver _instance = AppWebserver._internal();
  factory AppWebserver() => _instance;
  AppWebserver._internal();

  HttpServer? _server;
  final int _port = 8086;
  String? _lastError;
  Client? _matrixClient;
  
  StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  StreamSubscription? _matrixSub;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool get isRunning => _server != null;
  int get port => _port;
  String? get lastError => _lastError;

  Future<void> initNotifications() async {
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
      description: 'Notifications for incoming Matrix chat messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      debugPrint('🔔 Android TV notification channel successfully created & registered.');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // 🔑 Fallback check: Verify if already enabled at the Android OS level
        final bool? alreadyEnabled = await androidPlugin.areNotificationsEnabled();
        if (alreadyEnabled == true) {
          debugPrint('🔔 Notifications are already enabled in system settings.');
          return true;
        }

        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Notification permission dialog result: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('❌ Exception requesting notification permissions: $e');
    }
    return true; // Fallback to true if plugin resolution fails on TV
  }

  Future<void> showNotification(String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'matrix_tv_channel',
        'Matrix TV Notifications',
        channelDescription: 'Incoming Matrix chat messages',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher', // 🔑 Explicit icon to prevent intent null reference exceptions on Android TV
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);

      int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
      );
      debugPrint('✅ Notification dispatched successfully.');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to show notification: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      rethrow;
    }
  }

  void setClient(Client client) {
    _matrixClient = client;
    _matrixSub?.cancel();
    
    _matrixSub = _matrixClient!.onNotification.stream.listen((event) {
      if (_matrixClient == null) return;
      
      try {
        if (event.type == 'm.room.message' && event.content.containsKey('body')) {
          final room = event.room;
          final senderId = event.senderId ?? '';
          final isSelf = senderId == _matrixClient!.userID;
          final roomName = room?.getLocalizedDisplayname() ?? 'Matrix Room';
          final bodyText = event.body;

          if (!isSelf) {
            showNotification(roomName, '$senderId: $bodyText');
          }
          
          _eventController.add({
            'type': 'room_event',
            'roomId': room?.id ?? '',
            'roomName': roomName,
            'sender': senderId,
            'body': bodyText,
            'isSelf': isSelf,
            'timestamp': event.originServerTs.millisecondsSinceEpoch,
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error handling matrix notification event: $e');
      }
    });
  }

  Future<void> start() async {
    if (_server != null) return;
    _lastError = null;
    await initNotifications();

    if (_eventController.isClosed) {
      _eventController = StreamController.broadcast();
    }

    try {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      } catch (bindErr) {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port, shared: true);
      }

      _server!.listen((HttpRequest request) async {
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        try {
          final path = request.uri.path;
          final method = request.method;

          // --- API: Status ---
          if (method == 'GET' && path == '/api/status') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'userId': _matrixClient?.userID ?? 'Not Logged In',
              'homeserver': _matrixClient?.homeserver?.toString() ?? 'Unknown',
              'isLoggedIn': _matrixClient?.userID != null,
              'roomCount': _matrixClient?.rooms.length ?? 0,
            }));
            return;
          }

          // --- API: Test Notification ---
          if (method == 'POST' && path == '/api/test_notification') {
            final hasPermission = await requestPermission();
            if (!hasPermission) {
              request.response.statusCode = HttpStatus.forbidden;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'error': 'Notification permission denied'}));
              return;
            }

            await showNotification('Matrix TV Test', 'This is a test notification banner on Google TV!');
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'status': 'success'}));
            return;
          }

          // --- API: Real-Time SSE Stream ---
          if (method == 'GET' && path == '/api/events') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.parse('text/event-stream');
            request.response.headers.add('Cache-Control', 'no-cache');
            request.response.headers.add('Connection', 'keep-alive');

            request.response.write('data: ${jsonEncode({'type': 'connected'})}\n\n');
            await request.response.flush();

            final subscription = _eventController.stream.listen((data) {
              try {
                request.response.write('data: ${jsonEncode(data)}\n\n');
                request.response.flush();
              } catch (_) {}
            });

            request.response.done.then((_) => subscription.cancel());
            return;
          }

          // --- API: Send Message ---
          if (method == 'POST' && path == '/api/send_message') {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content);
            final String? roomId = data['roomId'];
            final String? message = data['message'];

            if (roomId != null && message != null && _matrixClient != null) {
              final room = _matrixClient!.getRoomById(roomId);
              if (room != null) {
                await room.sendEvent({
                  'msgtype': 'm.text',
                  'body': message,
                }, type: 'm.room.message');
                request.response.statusCode = HttpStatus.ok;
                request.response.headers.contentType = ContentType.json;
                request.response.write(jsonEncode({'status': 'success'}));
              } else {
                _sendError(request, 'Room not found', 404);
              }
            } else {
              _sendError(request, 'Invalid payload', 400);
            }
            return;
          }

          // --- API: Rooms ---
          if (method == 'GET' && path == '/api/rooms') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            if (_matrixClient != null) {
              final rooms = _matrixClient!.rooms.map((r) => ({
                'id': r.id ?? '',
                'name': r.getLocalizedDisplayname() ?? 'Unnamed Room',
                'isSpace': r.isSpace,
              })).toList();
              request.response.write(jsonEncode(rooms));
            } else {
              request.response.write(jsonEncode([]));
            }
            return;
          }

          // --- API: Messages History ---
          if (method == 'GET' && path == '/api/messages') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            final roomId = request.uri.queryParameters['roomId'];
            
            if (_matrixClient != null && roomId != null) {
              try {
                final room = _matrixClient!.getRoomById(roomId);
                if (room != null) {
                  final messages = <Map<String, dynamic>>[];
                  final timeline = await room.getTimeline();
                  for (final event in timeline.events) {
                    if (event.type == 'm.room.message' && event.content.containsKey('body')) {
                      final senderId = event.senderId ?? '';
                      messages.add({
                        'sender': senderId,
                        'body': event.body,
                        'isSelf': senderId == _matrixClient!.userID,
                        'timestamp': event.originServerTs.millisecondsSinceEpoch,
                      });
                    }
                  }
                  request.response.write(jsonEncode(messages));
                } else {
                  request.response.write(jsonEncode([]));
                }
              } catch (e) {
                request.response.write(jsonEncode([]));
              }
            } else {
              request.response.write(jsonEncode([]));
            }
            return;
          }

          // --- Static Files / SPA Fallback (Bundled Assets) ---
          var cleanPath = path == '/' || path.isEmpty ? '/index.html' : path;
          if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
          try {
            final byteData = await rootBundle.load('assets/web/$cleanPath');
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = _getContentType(cleanPath);
            request.response.add(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
          } catch (_) {
            final fallbackData = await rootBundle.load('assets/web/index.html');
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.html;
            request.response.add(fallbackData.buffer.asUint8List(fallbackData.offsetInBytes, fallbackData.lengthInBytes));
          }
        } catch (e) {
          _sendError(request, 'Server Error: $e', 500);
        } finally {
          if (request.uri.path != '/api/events') {
            await request.response.close();
          }
        }
      });
      debugPrint('🚀 Native web server running on port $_port');
    } catch (e) {
      _server = null;
      _lastError = e.toString();
      debugPrint('❌ Web server start error: $_lastError');
      rethrow;
    }
  }

  void _sendError(HttpRequest request, String message, int code) {
    request.response.statusCode = code;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': message}));
  }

  ContentType _getContentType(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.css')) return ContentType.text;
    if (path.endsWith('.js')) return ContentType.parse('application/javascript');
    if (path.endsWith('.json')) return ContentType.json;
    return ContentType.binary;
  }

  Future<void> stop() async {
    _matrixSub?.cancel();
    await _eventController.close();
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('🛑 Web server stopped.');
    }
  }
}
