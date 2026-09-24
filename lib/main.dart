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

    final active = await FlutterOverlayWindow.isActive();
    if (!active) {
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.client.isLogged()) {
        try {
          debugPrint('🔍 Verifying notification status on boot...');
          final granted = await AppWebserver().requestPermission();
          debugPrint('🔔 Startup permission check result: $granted');
          
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

/// Reactive overlay entry point for flutter_overlay_window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayControllerWidget(),
    ),
  );
}

class OverlayControllerWidget extends StatefulWidget {
  const OverlayControllerWidget({super.key});

  @override
  State<OverlayControllerWidget> createState() => _OverlayControllerWidgetState();
}

class _OverlayControllerWidgetState extends State<OverlayControllerWidget> {
  String _title = 'Matrix TV';
  String _body = 'Listening for messages...';

  @override
  void initState() {
    super.initState();
    // Listen for incoming payload updates dispatched from the main isolate
    FlutterOverlayWindow.dataStream.listen((data) {
      if (data is Map) {
        setState(() {
          _title = data['title']?.toString() ?? 'Matrix TV';
          _body = data['body']?.toString() ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _body,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
