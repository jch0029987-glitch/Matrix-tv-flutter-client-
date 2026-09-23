import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timeline? _timeline;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    _timeline = await widget.room.getTimeline(
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await widget.room.sendTextEvent(text);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _timeline?.events
            .where((e) => 
                (e.messageType == MessageTypes.Text || e.messageType == MessageTypes.Notice) && 
                e.body.isNotEmpty)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.getLocalizedDisplayname()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: events.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages in this room yet. Say hello!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true, // Forces the scroll thumb to stay visible
                          thickness: 8.0, // Makes it easier to see on a TV display
                          radius: const Radius.circular(4),
                          child: ListView.builder(
                            reverse: true, // Newest messages at the bottom
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              // Correct index mapping for reversed list
                              final event = events[events.length - 1 - index];
                              final isMe = event.senderId == widget.room.client.userID;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.teal.shade700 : Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe) ...[
                                        Text(
                                          event.senderFromMemoryOrFallback.calcDisplayname(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.tealAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        event.body,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          autofocus: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFF1E1E1E),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
