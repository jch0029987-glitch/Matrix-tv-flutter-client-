import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

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

  bool get isRunning => _server != null;
  int get port => _port;
  String? get lastError => _lastError;

  void setClient(Client client) {
    _matrixClient = client;
    
    _matrixSub?.cancel();
    
    // Listen directly to standard notification/timeline events using Matrix 12.0.1 client streams
    _matrixSub = _matrixClient!.onNotification.stream.listen((event) {
      if (_matrixClient == null) return;
      
      try {
        if (event.type == 'm.room.message' && event.content.containsKey('body')) {
          final room = event.room;
          final senderId = event.senderId ?? '';
          final isSelf = senderId == _matrixClient!.userID;
          
          _eventController.add({
            'type': 'room_event',
            'roomId': room?.id ?? '',
            'roomName': room?.getLocalizedDisplayname() ?? 'Unknown Room',
            'sender': senderId,
            'body': event.body,
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

    if (_eventController.isClosed) {
      _eventController = StreamController.broadcast();
    }

    try {
      // Try binding to anyIPv4 first for Tailscale/LAN, fallback to loopback if restricted
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      } catch (bindErr) {
        debugPrint('⚠️ Failed to bind to anyIPv4, falling back to loopback: $bindErr');
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port, shared: true);
      }

      _server!.listen((HttpRequest request) async {
        // Add CORS headers to all responses so external browsers never block them
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

          // --- API: System Status & Diagnostics ---
          if (method == 'GET' && path == '/api/status') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'userId': _matrixClient?.userID ?? 'Not Logged In',
              'homeserver': _matrixClient?.homeserver?.toString() ?? 'Unknown',
              'isLoggedIn': _matrixClient?.userID != null,
              'roomCount': _matrixClient?.rooms.length ?? 0,
              'uptimeSeconds': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            }));
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

            request.response.done.then((_) {
              subscription.cancel();
            }).catchError((_) {
              subscription.cancel();
            });
            return;
          }

          // --- API: Clipboard Bridge ---
          if (method == 'POST' && path == '/api/clipboard') {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content);
            final String? text = data['text'];

            if (text != null) {
              await Clipboard.setData(ClipboardData(text: text));
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'status': 'success'}));
            } else {
              _sendError(request, 'Invalid payload: missing text', 400);
            }
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
              _sendError(request, 'Invalid payload or client uninitialized', 400);
            }
            return;
          }

          // --- API: Get Rooms & Spaces ---
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

          // --- API: Get Room Message History ---
          if (method == 'GET' && path == '/api/messages') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            final roomId = request.uri.queryParameters['roomId'];
            
            if (_matrixClient != null && roomId != null) {
              try {
                final room = _matrixClient!.getRoomById(roomId);
                if (room != null) {
                  final messages = <Map<String, dynamic>>[];
                  
                  // Properly await the timeline future
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
                debugPrint('⚠️ Error fetching room history: $e');
                request.response.write(jsonEncode([]));
              }
            } else {
              request.response.write(jsonEncode([]));
            }
            return;
          }

          // --- Static Files / SPA Fallback ---
          var cleanPath = path == '/' || path.isEmpty ? '/index.html' : path;
          if (cleanPath.startsWith('/')) {
            cleanPath = cleanPath.substring(1);
          }
          try {
            final byteData = await rootBundle.load('assets/web/$cleanPath');
            final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = _getContentType(cleanPath);
            request.response.add(bytes);
          } catch (_) {
            final fallbackData = await rootBundle.load('assets/web/index.html');
            final fallbackBytes = fallbackData.buffer.asUint8List(fallbackData.offsetInBytes, fallbackData.lengthInBytes);
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.html;
            request.response.add(fallbackBytes);
          }
        } catch (e) {
          _sendError(request, 'Server Error: $e', 500);
        } finally {
          if (request.uri.path != '/api/events') {
            await request.response.close();
          }
        }
      });

      debugPrint('🚀 Advanced Webserver bound to port $_port successfully');
    } catch (e, stackTrace) {
      _lastError = e.toString();
      debugPrint('❌ Server fatal startup error: $e\n$stackTrace');
      _server = null;
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
    if (path.endsWith('.png')) return ContentType.parse('image/png');
    if (path.endsWith('.jpg')) return ContentType.parse('image/jpeg');
    return ContentType.binary;
  }

  Future<void> stop() async {
    _matrixSub?.cancel();
    await _eventController.close();
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}
