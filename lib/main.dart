import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';
import 'services/app_webserver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 🔑 Initialize Native Android TV Notifications Channel on boot
  try {
    await AppWebserver().initNotifications();
    debugPrint('🔔 Native notifications initialized successfully.');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize notifications on boot: $e');
  }

  // 🔑 CRITICAL: Bind the client to the singleton webserver immediately after session load
  AppWebserver().setClient(client);

  // Automatically start the web server on app launch if enabled in preferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool autoStartOnLogin = prefs.getBool('autostart_on_login') ?? true;

    if (autoStartOnLogin) {
      final webserver = AppWebserver();
      if (!webserver.isRunning) {
        await webserver.start();
        debugPrint('🚀 Web server successfully auto-started on app boot.');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Failed to auto-start web server on boot: $e');
  }

  runApp(MatrixApp(client: client));
}

Future<sqflite.Database> _openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final dbPath = p.join(directory.path, 'matrix_tv_client.db');
  return sqflite.openDatabase(dbPath);
}

class MatrixApp extends StatefulWidget {
  final Client client;
  const MatrixApp({super.key, required this.client});

  @override
  State<MatrixApp> createState() => _MatrixAppState();
}

class _MatrixAppState extends State<MatrixApp> {
  @override
  void initState() {
    super.initState();
    
    // 🔑 Safely trigger the Android runtime permission dialog the moment 
    // the app's first frame renders (Activity is active & ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final granted = await AppWebserver().requestPermission();
        debugPrint('🔔 Notification permission status: $granted');
      } catch (e) {
        debugPrint('⚠️ Failed to request permission on app load: $e');
      }
    });
  }

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
      // Automatically route to RoomListScreen if logged in, or LoginScreen if not
      home: widget.client.isLogged() 
          ? RoomListScreen(client: widget.client) 
          : LoginScreen(client: widget.client),
    );
  }
}
