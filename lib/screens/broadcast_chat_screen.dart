import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:intl/intl.dart';

class BroadcastChatScreen extends StatefulWidget {
  const BroadcastChatScreen({super.key});

  @override
  State<BroadcastChatScreen> createState() => _BroadcastChatScreenState();
}

class _BroadcastChatScreenState extends State<BroadcastChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendBroadcast() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final meshProvider = Provider.of<MeshProvider>(context, listen: false);
    await meshProvider.broadcastMessage(text, isSos: false);
    
    _msgController.clear();
    
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Broadcast Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Nearby Group chat', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MeshProvider>(
              builder: (context, provider, child) {
                final broadcasts = provider.receivedPackets
                    .where((p) => p.type == MeshPacketType.broadcast || p.type == MeshPacketType.sos)
                    .toList()
                    .reversed // Oldest first for chat
                    .toList();

                if (broadcasts.isEmpty) {
                  return const Center(
                    child: Text("No broadcast messages yet.\nMessages sent here go to everyone nearby.", 
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: broadcasts.length,
                  itemBuilder: (ctx, idx) {
                    final packet = broadcasts[idx];
                    final isMe = false; // We don't easily track 'self' packets in the received list yet, 
                                       // but we can compare with our Mesh ID later.
                    return _BroadcastBubble(packet: packet, isMe: isMe);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Message everyone...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendBroadcast(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              onPressed: _sendBroadcast,
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastBubble extends StatelessWidget {
  final MeshPacket packet;
  final bool isMe;
  const _BroadcastBubble({required this.packet, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(packet.timestamp));
    final senderName = packet.metadata?['senderName'] ?? 'Device';
    final isSos = packet.type == MeshPacketType.sos;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(senderName, style: TextStyle(fontSize: 11, color: isSos ? Colors.redAccent : Colors.white38, fontWeight: FontWeight.bold)),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isSos 
                  ? Colors.redAccent.withOpacity(0.2) 
                  : (isMe ? Theme.of(context).colorScheme.primary : const Color(0xFF1E1E1E)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              border: isSos ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  packet.payload,
                  style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
