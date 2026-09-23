import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'room_list_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

class SpaceListScreen extends StatefulWidget {
  final Client client;

  const SpaceListScreen({super.key, required this.client});

  @override
  State<SpaceListScreen> createState() => _SpaceListScreenState();
}

class _SpaceListScreenState extends State<SpaceListScreen> {
  @override
  void initState() {
    super.initState();
    widget.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final allRooms = widget.client.rooms;
    final spaces = allRooms.where((room) => room.isSpace).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix TV - Spaces'),
        actions: [
          IconButton(
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
      body: spaces.isEmpty
          ? RoomListScreen(client: widget.client)
          : GridView.builder(
              padding: const EdgeInsets.all(24.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.5,
              ),
              itemCount: spaces.length,
              itemBuilder: (context, index) {
                final space = spaces[index];
                return Card(
                  elevation: 4,
                  child: InkWell(
                    autofocus: index == 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpaceDetailScreen(client: widget.client, space: space),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_special, size: 40, color: Colors.blueAccent),
                          const SizedBox(height: 12),
                          Text(
                            space.getLocalizedDisplayname(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SpaceDetailScreen extends StatelessWidget {
  final Client client;
  final Room space;

  const SpaceDetailScreen({super.key, required this.client, required this.space});

  @override
  Widget build(BuildContext context) {
    final childRooms = space.spaceChildrenRooms;

    return Scaffold(
      appBar: AppBar(
        title: Text(space.getLocalizedDisplayname()),
      ),
      body: childRooms.isEmpty
          ? const Center(child: Text('No rooms found in this space.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: childRooms.length,
              itemBuilder: (context, index) {
                final room = childRooms[index];
                return Card(
                  child: InkWell(
                    autofocus: index == 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(room: room),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: const Icon(Icons.chat),
                      title: Text(room.getLocalizedDisplayname()),
                      subtitle: Text(room.lastEvent?.body ?? 'No messages yet', maxLines: 1),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
