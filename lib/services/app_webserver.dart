import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class AppWebserver {
  static final AppWebserver _instance = AppWebserver._internal();
  factory AppWebserver() => _instance;
  AppWebserver._internal();

  HttpServer? _server;
  final int _port = 8086;
  String? _lastError;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get lastError => _lastError;

  Future<void> start() async {
    if (_server != null) return;
    _lastError = null;

    try {
      // 1. Prepare local directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final webDir = Directory('${appDocDir.path}/web_assets');
      if (!await webDir.exists()) {
        await webDir.create(recursive: true);
      }

      // 2. Extract index.html with fallback protection
      try {
        final byteData = await rootBundle.load('assets/web/index.html');
        final file = File('${webDir.path}/index.html');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      } catch (e) {
        final fallbackFile = File('${webDir.path}/index.html');
        await fallbackFile.writeAsString('''
          <!DOCTYPE html>
          <html>
            <head><title>Matrix TV Control Panel</title></head>
            <body style="background: #111; color: #fff; font-family: sans-serif; text-align: center; padding-top: 50px;">
              <h1>Matrix TV Control Panel (Fallback)</h1>
              <p>Server is online!</p>
            </body>
          </html>
        ''');
      }

      final staticHandler = createStaticHandler(
        webDir.path,
        defaultDocument: 'index.html',
      );

      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(staticHandler);

      // 3. Bind to socket
      _server = await io.serve(
        handler,
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      debugPrint('🚀 AppWebserver successfully bound to port $_port');
    } catch (e, stackTrace) {
      _lastError = e.toString();
      debugPrint('❌ AppWebserver startup error: $e\n$stackTrace');
      _server = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}
