import 'package:flutter/material.dart';
import '../services/matrix_service.dart';

class RoomListScreen extends StatelessWidget {
  final MatrixService matrixService;

  const RoomListScreen({super.key, required this.matrixService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matrix Rooms')),
      body: const Center(
        child: Text('Room List (Coming Soon)', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
