import 'dart:convert';
import 'package:crowd_link/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crowd_link/services/auth_service.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:crowd_link/models/mesh_node.dart';
import 'package:crowd_link/screens/login_screen.dart';
import 'package:crowd_link/screens/qr_scanner_screen.dart';
import 'package:crowd_link/screens/broadcast_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crowd_link/components/payment_request_card.dart';

// ─── Chat Screen (root) ───────────────────────────────────────────────────────
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snap) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chat', style: TextStyle(fontSize: 28, fontWeight: FontWeight.normal)),
            actions: [
              if (snap.hasData)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: 'Add Friend',
                  onPressed: () => _showAddFriendSheet(context),
                ),
              IconButton(
                icon: Icon(snap.hasData ? Icons.logout : Icons.login),
                tooltip: snap.hasData ? 'Sign Out' : 'Sign In',
                onPressed: () async {
                  if (snap.hasData) {
                    await AuthService().signOut();
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  }
                },
              ),
            ],
          ),
          body: snap.hasData ? _LoggedInChatBody() : _LoggedOutPrompt(),
        );
      },
    );
  }

  void _showAddFriendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AddFriendSheet(),
    );
  }
}

// ─── Logged out prompt ────────────────────────────────────────────────────────
class _LoggedOutPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.15), blurRadius: 40, spreadRadius: 5)],
              ),
              child: Icon(Icons.lock_person_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 28),
            const Text('Sign in to Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Create an account to get your Mesh ID, add friends, and message them even without internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logged in: Friends list + Broadcast ─────────────────────────────────────
class _LoggedInChatBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // My ID card
        SliverToBoxAdapter(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: AuthService().getUserProfile(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final meshId = snap.data?['meshId'] ?? '…';
              final name = snap.data?['name'] ?? '…';
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _MyIdCard(meshId: meshId, name: name),
              );
            },
          ),
        ),

        // Broadcast
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: _BroadcastCard(),
          ),
        ),


        // Friends header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.radar, color: Color(0xFF00FC82)),
                SizedBox(width: 8),
                Text(
                  "Friends",
                  style: TextStyle(
                    color: Color(0xFF00FC82),
                    fontSize: 18,
                    fontWeight: FontWeight.w600
                  ),
                ),
                Spacer(),
                Icon(Icons.filter_list, color: Colors.white54, size: 20),
              ],
            ),
          ),
        ),

        // Friends stream
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: AuthService().friendsStream(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const SliverToBoxAdapter(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
            }
            final friends = snap.data ?? [];
            if (friends.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No friends found.\nSync with Firebase or add via Mesh ID.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, height: 1.6)),
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _FriendTile(friend: friends[i]),
                childCount: friends.length,
              ),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── My ID Card ───────────────────────────────────────────────────────────────
class _MyIdCard extends StatelessWidget {
  final String meshId;
  final String name;
  const _MyIdCard({required this.meshId, required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // QR preview tap area
            GestureDetector(
              onTap: () => _showQrDialog(context),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: 'CROWDLINK:$meshId',
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: meshId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mesh ID copied!'), behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF1E1E1E)),
                      );
                    },
                    child: Row(
                      children: [
                        Text(meshId, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 1)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('Tap QR to expand · Tap ID to copy', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your QR Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Share this with friends to let them add you.', style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: QrImageView(data: 'CROWDLINK:$meshId', version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(meshId, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('Your Mesh ID', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Broadcast Card ───────────────────────────────────────────────────────────
class _BroadcastCard extends StatelessWidget {
  void _showBroadcastDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Broadcast Message'),
        content: TextField(
          controller: ctrl, maxLines: 3, autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type your message…',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastChatScreen())),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.campaign_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Broadcast Message', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Send an alert or announcement to all nearby nodes.', style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nearby Node Tile ──────────────────────────────────────────────────────────
class _NearbyNodeTile extends StatelessWidget {
  final MeshNode node;
  const _NearbyNodeTile({required this.node});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        color: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00FC82).withOpacity(0.12), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatWindowScreen(friendUid: '', friendName: node.deviceName, friendMeshId: node.meshId),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF1E1E1E),
                      child: Text(node.deviceName.isNotEmpty ? node.deviceName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FC82),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF141414), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.hub_rounded, size: 12, color: const Color(0xFF00FC82).withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(node.meshId, style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Friend Tile ───────────────────────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final name = friend['name'] ?? 'Unknown';
    final meshId = friend['meshId'] ?? '';
    final uid = friend['uid'] ?? '';

    return Consumer<MeshProvider>(
      builder: (context, meshProvider, child) {
        final bool isNearby = meshProvider.isFriendNearby(meshId);
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: isNearby ? BorderSide(color: const Color(0xFF00FC82).withOpacity(0.1), width: 1) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatWindowScreen(friendUid: uid, friendName: name, friendMeshId: meshId),
              )),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white10,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        if (isNearby)
                          Positioned(
                            bottom: 1, right: 1,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FC82),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF141414), width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              if (isNearby) ...[
                                const SizedBox(width: 8),
                                const Text('NEARBY', style: TextStyle(color: Color(0xFF00FC82), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(meshId, style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (meshProvider.unreadCounts[meshId] != null && meshProvider.unreadCounts[meshId]! > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF00FC82), shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        child: Text(
                          meshProvider.unreadCounts[meshId].toString(),
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Add Friend Sheet ─────────────────────────────────────────────────────────
class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();
  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _idController = TextEditingController();
  bool _loading = false;
  String? _status;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _addById() async {
    setState(() { _loading = true; _status = null; _success = false; });
    final err = await AuthService().addFriendByMeshId(_idController.text);
    setState(() {
      _loading = false;
      _success = err == null;
      _status = err ?? 'Friend added successfully!';
    });
    if (err == null) {
      Future.delayed(const Duration(seconds: 1), () { if (mounted) Navigator.pop(context); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('Add Friend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Connect using a Mesh ID or scan their QR code.', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [Tab(text: 'Enter ID'), Tab(text: 'Scan QR')],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 180,
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Enter ID ──
                Column(
                  children: [
                    TextField(
                      controller: _idController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
                      decoration: InputDecoration(
                        hintText: 'e.g. MN-A3F9K2',
                        hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
                        prefixIcon: const Icon(Icons.tag_rounded, color: Colors.white38),
                        filled: true, fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 10),
                      Text(_status!, style: TextStyle(color: _success ? Theme.of(context).colorScheme.primary : Colors.redAccent, fontSize: 13)),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loading ? null : _addById,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('Send Friend Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),

                // ── Scan QR ──
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.qr_code_scanner_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => QrScannerScreen(
                            onScanned: (meshId) async {
                              final err = await AuthService().addFriendByMeshId(meshId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(err ?? 'Friend added: $meshId'),
                                backgroundColor: err == null ? const Color(0xFF1E1E1E) : Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                          ),
                        ));
                      },
                      child: const Text('Open Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Window ──────────────────────────────────────────────────────────────
class ChatWindowScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;
  final String friendMeshId;
  const ChatWindowScreen({super.key, required this.friendUid, required this.friendName, required this.friendMeshId});

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  void _handleChatOption(String value) {
    final provider = Provider.of<MeshProvider>(context, listen: false);
    switch (value) {
      case 'mute':
        provider.toggleMute(widget.friendMeshId);
        break;
      case 'clear':
        _showClearChatDialog();
        break;
      case 'select':
        setState(() {
          _isSelectionMode = true;
          _selectedMessageIds.clear();
        });
        break;
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear this conversation locally?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<MeshProvider>(context, listen: false).clearChat(widget.friendMeshId);
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedMessages() {
    final provider = Provider.of<MeshProvider>(context, listen: false);
    provider.deleteMessages(_selectedMessageIds.toList());
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String? id) {
    if (id == null) return;
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MeshProvider>(context, listen: false).setActiveChat(widget.friendMeshId);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final meshProvider = Provider.of<MeshProvider>(context, listen: false);
    bool sent = false;

    // 1. Priority: Online (Firebase) if device has internet and friend has UID
    if (meshProvider.isInternetAvailable && widget.friendUid.isNotEmpty) {
      try {
        debugPrint("Internet available, sending via Firebase...");
        await AuthService().sendMessage(widget.friendUid, text);
        sent = true;
      } catch (e) {
        debugPrint("Firebase send failed: $e. Falling back to mesh.");
      }
    }

    // 2. Mesh: If internet failed or not available, try direct Mesh
    if (!sent && meshProvider.isMeshActive && meshProvider.isFriendNearby(widget.friendMeshId)) {
      debugPrint("Attempting to send message via DIRECT MESH to ${widget.friendMeshId}");
      sent = await meshProvider.sendDirectMessage(widget.friendMeshId, text);
    }

    // 3. Gateway: If still not sent and mesh active, try Gateway
    if (!sent && meshProvider.isMeshActive) {
      debugPrint("Friend not nearby, attempting to send via GATEWAY");
      if (meshProvider.gatewayNodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No internet gateway available. Message will be delivered when a gateway node is found."),
          behavior: SnackBarBehavior.floating,
        ));
      }
      await meshProvider.sendGatewayMessage(widget.friendMeshId, widget.friendUid, text);
      sent = true; // Gateway queues it
    }
    
    if (!sent) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text("Connection unavailable. Message will be sent when you are back online or near the mesh."),
         behavior: SnackBarBehavior.floating,
       ));
    }

    _msgController.clear();

    Future.delayed(const Duration(milliseconds: 150), () {
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
    final myUid = AuthService().currentUser?.uid ?? '';
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedMessageIds.clear();
          });
          return;
        }
        Provider.of<MeshProvider>(context, listen: false).setActiveChat(null);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedMessageIds.clear(); }))
            : const BackButton(),
        title: _isSelectionMode 
            ? Text('${_selectedMessageIds.length} selected')
            : Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white12,
              child: Text(widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(widget.friendMeshId, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ],
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _selectedMessageIds.isEmpty ? null : _deleteSelectedMessages,
            )
          else
            Consumer<MeshProvider>(
              builder: (context, provider, _) {
                bool isMuted = provider.isMuted(widget.friendMeshId);
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: _handleChatOption,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(isMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Text(isMuted ? 'Unmute' : 'Mute Notifications'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                    const PopupMenuItem(value: 'select', child: Text('Select Messages')),
                  ],
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MeshProvider>(
              builder: (context, meshProvider, child) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.friendUid.isNotEmpty 
                      ? AuthService().messagesStream(widget.friendUid)
                      : const Stream.empty(),
                  builder: (ctx, snap) {
                    // Reset count inside the builder ensures we catch new messages that arrive while screen is active
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      meshProvider.resetUnreadCount(widget.friendMeshId);
                    });
                    
                    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Combined messages logic
                    List<Map<String, dynamic>> onlineMessages = snap.data ?? [];
                    final String myId = AuthService().currentUser?.uid ?? '';
                    
                    // Filter mesh messages for this conversation
                    List<Map<String, dynamic>> meshMessages = meshProvider.receivedPackets
                        .where((p) {
                          if (p.type == MeshPacketType.internetResponse) {
                            try {
                              final data = jsonDecode(p.payload);
                              if (data['type'] == 'INTERNET_RESPONSE') {
                                return data['friendUid'] == widget.friendUid || data['receiverMeshId'] == widget.friendMeshId;
                              }
                            } catch (_) {}
                            return false;
                          }
                          return p.senderMeshId == widget.friendMeshId || p.destinationMeshId == widget.friendMeshId || p.metadata?['receiverMeshId'] == widget.friendMeshId;
                        })
                        .map((p) {
                              if (p.type == MeshPacketType.internetResponse) {
                                try {
                                  final data = jsonDecode(p.payload);
                                  return {
                                    'text': data['message'] ?? '',
                                    'senderId': (data['friendUid'] == widget.friendUid || data['friendUid'] != null) ? widget.friendUid : 'gateway_${p.senderMeshId}',
                                    'timestamp': data['timestamp'] ?? p.timestamp,
                                    'isMesh': true,
                                    'viaGateway': true,
                                    'type': MeshPacketType.message.index,
                                    'packetId': p.packetId,
                                  };
                                } catch (_) {}
                              }
                              
                              return {
                                'text': p.payload,
                                'senderId': p.senderMeshId == widget.friendMeshId ? 'mesh_${p.senderMeshId}' : myId,
                                'timestamp': p.timestamp,
                                'isMesh': true,
                                'packetId': p.packetId,
                                'type': p.type.index,
                                'metadata': p.metadata,
                              };
                            })
                        .toList();
                        
                    // deduplicate: if an online message exists with same text and similar time, skip the mesh one
                    final Set<String> seenTexts = onlineMessages.map((m) => "${m['text']}_${(m['timestamp'] as int) ~/ 5000}").toSet();
                    
                    final Set<String> seenPacketIds = {};
                    final List<Map<String, dynamic>> filteredMeshMessages = [];
                    
                    for (var m in meshMessages) {
                      final key = "${m['text']}_${(m['timestamp'] as int) ~/ 5000}";
                      if (seenTexts.contains(key)) continue;
                      
                      final pid = m['packetId'];
                      if (pid != null) {
                        if (seenPacketIds.contains(pid)) continue;
                        seenPacketIds.add(pid);
                      }
                      
                      filteredMeshMessages.add(m);
                    }

                    final allMessages = [...onlineMessages, ...filteredMeshMessages];
                    
                    // Filter deleted messages
                    final visibleMessages = allMessages.where((m) {
                      final id = m['packetId'] ?? m['id'] ?? m['key'];
                      return !meshProvider.isMessageDeleted(id?.toString(), m['timestamp'] as int?, widget.friendMeshId);
                    }).toList();

                    visibleMessages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));

                    if (visibleMessages.isEmpty) {
                      return Center(
                        child: Text('No messages yet.\nSay hello!', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 14, height: 1.6)),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: visibleMessages.length,
                      itemBuilder: (ctx, i) {
                        final msg = visibleMessages[i];
                        final isMine = (msg['senderId'] ?? '') == myUid;
                        final msgId = (msg['packetId'] ?? msg['id'] ?? msg['key'])?.toString();
                        final isSelected = _selectedMessageIds.contains(msgId);
                        
                        // Handle different type formats (integer from Mesh, string from Firebase)
                        final dynamic typeData = msg['type'];
                        MeshPacketType type = MeshPacketType.message;
                        if (typeData is int) {
                          if (typeData >= 0 && typeData < MeshPacketType.values.length) {
                             type = MeshPacketType.values[typeData];
                          }
                        } else if (typeData == 'PAYMENT_REQUEST') {
                          type = MeshPacketType.paymentRequest;
                        }

                        Widget bubble;
                        if (type == MeshPacketType.paymentRequest) {
                          bubble = _buildPaymentBubble(ctx, msg, isMine);
                        } else if (type == MeshPacketType.paymentConfirmation) {
                          bubble = _buildConfirmationBubble(ctx, msg['text'] ?? '', isMine, msg['timestamp']);
                        } else {
                          bubble = _buildBubble(ctx, msg['text'] ?? '', isMine, msg['timestamp'], isMesh: msg['isMesh'] ?? false);
                        }

                        return GestureDetector(
                          onLongPress: () => _toggleMessageSelection(msgId),
                          onTap: _isSelectionMode ? () => _toggleMessageSelection(msgId) : null,
                          child: Container(
                            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                            child: bubble,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    ));
  }

  Widget _buildPaymentBubble(BuildContext context, Map<String, dynamic> msg, bool isMine) {
    // ALWAYS prioritize internal metadata or payload over raw text
    final metadata = msg['metadata'] ?? msg;
    
    String amountStr = "0";
    try {
      final amt = metadata['amount'];
      if (amt != null) {
        // Correct parsing as per requirement
        double parsed = double.parse(amt.toString());
        amountStr = parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 2);
      }
    } catch (_) {}

    final upiId = metadata['upiId'] ?? metadata['pa'] ?? '';
    final note = metadata['note'] ?? metadata['reason'] ?? metadata['tn'] ?? 'Mesh Payment';
    final senderName = isMine ? 'Me' : widget.friendName;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: PaymentRequestCard(
        senderName: senderName,
        amount: amountStr,
        note: note,
        upiId: upiId,
        isMine: isMine,
        onPay: () {
          final provider = Provider.of<MeshProvider>(context, listen: false);
          provider.sendPaymentConfirmation(widget.friendMeshId, amountStr);
          PaymentRequestCard.launchUPI(upiId, widget.friendName, amountStr, note);
        },
        onReject: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Request Declined')));
        },
      ),
    );
  }

  Widget _buildConfirmationBubble(BuildContext context, String text, bool isMine, dynamic ts) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF00FC82).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00FC82), size: 20),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Color(0xFF00FC82), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, String text, bool isMine, dynamic ts, {bool isMesh = false}) {
    String timeStr = '';
    if (ts != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts is int ? ts : int.tryParse(ts.toString()) ?? 0);
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? Theme.of(context).colorScheme.primary : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMine ? Colors.black : Colors.white, fontSize: 14, height: 1.4)),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMesh) ...[
                    Icon(Icons.hub_rounded, size: 10, color: isMine ? Colors.black54 : Colors.white38),
                    const SizedBox(width: 4),
                  ],
                  Text(timeStr, style: TextStyle(color: isMine ? Colors.black54 : Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white54),
            onPressed: () => _showAttachmentMenu(context),
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    ));
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.payments_rounded, color: Colors.blueAccent),
            title: const Text('Request Payment'),
            onTap: () {
              Navigator.pop(ctx);
              _showPaymentRequestDialog(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPaymentRequestDialog(BuildContext context) {
    final amtCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Request Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final provider = Provider.of<MeshProvider>(context, listen: false);
              provider.sendPaymentRequest(widget.friendMeshId, amtCtrl.text, reasonCtrl.text);
              Navigator.pop(ctx);
            }, 
            child: const Text('Send Request')
          ),
        ],
      ),
    );
  }
}
