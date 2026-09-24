import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';
import 'services/app_webserver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sqfDb = kIsWeb ? null : await _openDatabase();

  final client = Client(
    'MatrixTVClient',
    database: await MatrixSdkDatabase.init(
      'MatrixTVClient',
      database: sqfDb,
    ),
  );

  await client.init();

  // 1. Initialize notification channels on boot
  try {
    await AppWebserver().initNotifications();
    debugPrint('🔔 Native notifications initialized successfully.');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize notifications on boot: $e');
  }

  // Bind the active Matrix client to the web server singleton
  AppWebserver().setClient(client);

  // 2. Auto-start web server and foreground service on boot if enabled in preferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool autoStartOnLogin = prefs.getBool('autostart_on_login') ?? true;

    if (autoStartOnLogin && client.isLogged()) {
      final webserver = AppWebserver();
      if (!webserver.isRunning) {
        await webserver.start();
        debugPrint('🚀 Web server & foreground service successfully auto-started on app boot.');
      }
      
      // 3. Automatically show/activate the overlay window if already logged in
      await _initializeOverlayWindow();
    }
  } catch (e) {
    debugPrint('⚠️ Failed to auto-start web server/overlay on boot: $e');
  }

  runApp(MatrixApp(client: client));
}

Future<sqflite.Database> _openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final dbPath = p.join(directory.path, 'matrix_tv_client.db');
  return sqflite.openDatabase(dbPath);
}

/// Helper to safely request permission and activate the overlay window
Future<void> _initializeOverlayWindow() async {
  try {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      final requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        debugPrint('⚠️ Overlay permission denied by user.');
        return;
      }
    }

    if (!await FlutterOverlayWindow.isActive) {
      await FlutterOverlayWindow.showOverlay(
        height: 150,
        width: 400,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.defaultFlag,
        enableDrag: false,
      );
      debugPrint('📺 Flutter overlay window successfully activated.');
    }
  } catch (e) {
    debugPrint('❌ Failed to activate overlay window: $e');
  }
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
    
    // Perform a background permission check once the app frame mounts if logged in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.client.isLogged()) {
        try {
          debugPrint('🔍 Verifying notification status on boot...');
          final granted = await AppWebserver().requestPermission();
          debugPrint('🔔 Startup permission check result: $granted');
          
          // Ensure overlay is active if logged in
          await _initializeOverlayWindow();
        } catch (e) {
          debugPrint('❌ Failed to verify permission on boot: $e');
        }
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
      home: widget.client.isLogged() 
          ? RoomListScreen(client: widget.client) 
          : LoginScreen(client: widget.client),
    );
  }
}

/// Mandatory background entry point for flutter_overlay_window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: Text(
            'Matrix Notification Overlay',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    ),
  );
}
