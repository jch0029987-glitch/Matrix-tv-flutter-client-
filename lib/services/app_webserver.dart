import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class AppWebserver {
  static final AppWebserver _instance = AppWebserver._internal();
  factory AppWebserver() => _instance;
  AppWebserver._internal();

  HttpServer? _server;
  bool get isRunning => _server != null;
  int get port => 8086;

  Future<void> start() async {
    if (_server != null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final webDir = Directory('${appDir.path}/web');
      if (!await webDir.exists()) {
        await webDir.create(recursive: true);
      }

      final byteData = await rootBundle.load('assets/web/index.html');
      final file = File('${webDir.path}/index.html');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      var staticHandler = createStaticHandler(
        webDir.path,
        defaultDocument: 'index.html',
      );

      var handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(staticHandler);

      _server = await io.serve(handler, '0.0.0.0', port);
      debugPrint('Web UI successfully hosted at http://0.0.0.0:$port');
    } catch (e) {
      debugPrint('Error starting embedded webserver: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('Web server stopped.');
  }
}
