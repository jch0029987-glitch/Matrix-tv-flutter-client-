import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Matrix SDK client storage/database
  final client = Client('MatrixTVClient');
  await client.init();

  runApp(
    const ProviderScope(
      child: MatrixApp(),
    ),
  );
}

class MatrixApp extends StatelessWidget {
  const MatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if a client is already logged in from a previous session
    final client = Client('MatrixTVClient');
    
    return MaterialApp(
      title: 'Matrix TV Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      // If already logged in, skip login screen and go straight to rooms
      home: client.isLoggedIn() 
          ? RoomListScreen(client: client) 
          : const LoginScreen(),
    );
  }
}
