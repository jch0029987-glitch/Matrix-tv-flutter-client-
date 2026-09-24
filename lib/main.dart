import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';
import 'services/app_webserver.dart';

// Native platform channel bridges for direct screen drawing and background persistence
const MethodChannel _nativeNotificationChannel = MethodChannel('com.jeremy.flutter_matrix_client/notifications');
const MethodChannel _foregroundServiceChannel = MethodChannel('com.jeremy.flutter_matrix_client/foreground');

Future<void> showScreenOverlay(String title, String body) async {
  try {
    debugPrint('🎨 [FlutterBridge] Invoking showScreenOverlay channel method with title: "$title"');
    await _nativeNotificationChannel.invokeMethod('showScreenOverlay', {
      'title': title,
      'body': body,
    });
    debugPrint('✅ [FlutterBridge] Native direct screen overlay banner dispatched successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ [FlutterBridge] Failed to draw overlay banner: $e');
    debugPrint('❌ [FlutterBridge] StackTrace: $stackTrace');
  }
}

Future<void> startNativeForegroundService() async {
  try {
    debugPrint('🚀 [ForegroundService] Requesting native background keeper service start...');
    await _foregroundServiceChannel.invokeMethod('startForegroundService');
    debugPrint('✅ [ForegroundService] Native background keeper service started successfully.');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [ForegroundService] Failed to start native foreground service: $e');
    debugPrint('⚠️ [ForegroundService] StackTrace: $stackTrace');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [AppBoot] Matrix TV Client initialization started...');

  final sqfDb = kIsWeb ? null : await _openDatabase();

  final client = Client(
    'MatrixTVClient',
    database: await MatrixSdkDatabase.init(
      'MatrixTVClient',
      database: sqfDb,
    ),
  );

  debugPrint('⏳ [AppBoot] Initializing Matrix client instance...');
  await client.init();
  debugPrint('✅ [AppBoot] Matrix client initialized. Logged in: ${client.isLogged()} (User: ${client.userID})');

  // 1. Direct Matrix notification listener in main with verbose debugging logs
  client.onNotification.stream.listen((event) {
    debugPrint('🔔 [MatrixEvent] Received notification stream event. Type: ${event.type}');
    try {
      if (event.type == 'm.room.message' && event.content.containsKey('body')) {
        final senderId = event.senderId ?? '';
        final isSelf = senderId == client.userID;
        debugPrint('💬 [MatrixEvent] Message from $senderId (IsSelf: $isSelf)');

        if (!isSelf) {
          final roomName = event.room?.getLocalizedDisplayname() ?? 'Matrix Room';
          final bodyText = event.body;
          
          debugPrint('🚀 [MatrixEvent] Triggering screen overlay for room "$roomName"');
          showScreenOverlay(roomName, '$senderId: $bodyText');
        } else {
          debugPrint('⏭️ [MatrixEvent] Ignoring self-sent message.');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ [MatrixEvent] Error handling Matrix notification in main: $e');
      debugPrint('$stackTrace');
    }
  });

  // Bind client to web server for API endpoints (/api/rooms, /api/send_message, etc.)
  AppWebserver().setClient(client);

  // 2. Auto-start local HTTP server and native foreground service on boot
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool autoStartOnLogin = prefs.getBool('autostart_on_login') ?? true;

    if (autoStartOnLogin && client.isLogged()) {
      final webserver = AppWebserver();
      if (!webserver.isRunning) {
        await webserver.start();
        debugPrint('🚀 [Webserver] Local web server successfully auto-started on port ${webserver.port}.');
        
        // Start native foreground service to keep everything alive over full-screen media
        await startNativeForegroundService();
      }
    }
  } catch (e) {
    debugPrint('⚠️ [Webserver] Failed to auto-start web server or foreground service on boot: $e');
  }

  debugPrint('📺 [AppBoot] Running MaterialApp root...');
  runApp(MatrixApp(client: client));
}

Future<sqflite.Database> _openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final dbPath = p.join(directory.path, 'matrix_tv_client.db');
  debugPrint('📦 [Database] Opening local SQLite database at path: $dbPath');
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
      home: client.isLogged() 
          ? RoomListScreen(client: client) 
          : LoginScreen(client: client),
    );
  }
}
