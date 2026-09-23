import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;

import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';

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

  runApp(MatrixApp(client: client));
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
