import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'settings_screen.dart'; // Imports your existing settings screen

class RoomListScreen extends StatefulWidget {
  final Client client;

  const RoomListScreen({super.key, required this.client});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to sync stream to update rooms live
    widget.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.client.rooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix Rooms'),
        actions: [
          // Focusable Settings button for TV remote / Bluetooth keyboard
          IconButton(
            autofocus: false,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(client: widget.client),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: rooms.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing Matrix rooms...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Card(
                    elevation: 2,
                    child: InkWell(
                      autofocus: index == 0, // Auto-focus the very first room on load
                      onTap: () {
                        // TODO: Navigate to your Chat/Timeline screen for this room
                        debugPrint('Selected room: ${room.getLocalizedDisplayname()}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Text(
                                room.getLocalizedDisplayname().isNotEmpty
                                    ? room.getLocalizedDisplayname()[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.getLocalizedDisplayname(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.lastEvent?.body ?? 'No messages yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (room.notificationCount > 0)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${room.notificationCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
