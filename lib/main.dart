import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the local embedded web server on port 8086 (Skipped on Web platform if applicable)
  if (!kIsWeb) {
    _startLocalWebserver();
  }

  final sqfDb = kIsWeb ? null : await _openDatabase();

  // Initialize the client with the required MatrixSdkDatabase instance
  final client = Client(
    'MatrixTVClient',
    database: await MatrixSdkDatabase.init(
      'MatrixTVClient',
      database: sqfDb,
    ),
  );

  // Restore previous session from local storage (if any)
  await client.init();

  runApp(MatrixApp(client: client));
}

Future<void> _startLocalWebserver() async {
  try {
    // 1. Get local documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final webDir = Directory('${appDir.path}/web');
    if (!await webDir.exists()) {
      await webDir.create(recursive: true);
    }

    // 2. Extract index.html from Flutter assets to local storage
    final byteData = await rootBundle.load('assets/web/index.html');
    final file = File('${webDir.path}/index.html');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );

    // 3. Set up Shelf static handler pointing to the extracted folder
    var staticHandler = createStaticHandler(
      webDir.path,
      defaultDocument: 'index.html',
    );

    var handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(staticHandler);

    // 4. Bind to port 8086 across all interfaces for local/remote access
    final server = await io.serve(handler, '0.0.0.0', 8086);
    debugPrint('Web UI successfully hosted at http://0.0.0.0:${server.port}');
  } catch (e) {
    debugPrint('Error starting embedded webserver: $e');
  }
}

Future<sqflite.Database> _openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final dbPath = p.join(directory.path, 'matrix_tv_client.db');
  return sqflite.openDatabase(dbPath);
}

class MatrixApp extends StatelessWidget {
  final Client client;
  const MatrixApp({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matrix TV Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      // Automatically route to RoomListScreen if a session is already active
      home: client.isLogged() 
          ? RoomListScreen(client: client) 
          : LoginScreen(client: client),
    );
  }
}
