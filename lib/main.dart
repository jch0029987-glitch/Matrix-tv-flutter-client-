import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite database for Matrix local caching
  final dbDir = await getApplicationSupportDirectory();
  final dbPath = p.join(dbDir.path, 'matrix_tv_client.db');
  final sqfDb = await sqflite.openDatabase(dbPath);

  final client = Client(
    'MatrixTVClient',
    databaseBuilder: (_) async => MatrixSdkDatabase('MatrixTVClient', database: sqfDb),
  );
  await client.init();

  runApp(MatrixApp(client: client));
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
      // Check if user session is already active
      home: client.isLogged() 
          ? RoomListScreen(client: client) 
          : const LoginScreen(),
    );
  }
}
