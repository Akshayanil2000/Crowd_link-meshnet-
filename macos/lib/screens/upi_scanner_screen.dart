import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/services/permission_service.dart';
import 'package:crowd_link/models/internet_packet.dart';
import 'package:crowd_link/models/mesh_node.dart';
import 'package:crowd_link/services/auth_service.dart';

class UPIScannerScreen extends StatefulWidget {
  const UPIScannerScreen({super.key});

  @override
  State<UPIScannerScreen> createState() => _UPIScannerScreenState();
}

class _UPIScannerScreenState extends State<UPIScannerScreen> {
  bool _isProcessing = false;
  bool _hasCameraPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool granted = await PermissionService.checkCameraPermissions();
    if (!granted) {
      granted = await PermissionService.requestCameraPermission();
    }
    setState(() {
      _hasCameraPermission = granted;
    });
    
    if (!granted) {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Camera permission is required to scan UPI QR codes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkPermission();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.startsWith('upi://')) {
        _isProcessing = true;
        _handleUPICode(code);
      }
    }
  }

  void _handleUPICode(String code) {
    try {
      final uri = Uri.parse(code);
      final pa = uri.queryParameters['pa']; // upiId
      final pn = uri.queryParameters['pn']; // payeeName
      final am = uri.queryParameters['am']; // amount
      
      if (pa == null) {
        throw "Invalid UPI QR: Missing ID";
      }

      _showPaymentConfirmation(pa, pn ?? 'Unknown', am ?? '0.00');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isProcessing = false);
    }
  }

  void _showPaymentConfirmation(String upiId, String name, String amount) {
    final TextEditingController amountController = TextEditingController(text: amount);
    final TextEditingController noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00FC82), size: 48),
              const SizedBox(height: 16),
              const Text('Mesh Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Paying to $name', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(upiId, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 24),
              
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00FC82)),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FC82))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Add a note (optional)',
                  hintText: 'e.g. For Coffee',
                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FC82))),
                ),
              ),
              const SizedBox(height: 32),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Friend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              _buildFriendPicker(upiId, amountController, noteController),
              
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = false);
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendPicker(String upiId, TextEditingController amountCtrl, TextEditingController noteCtrl) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AuthService().friendsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("No friends found. Add friends to request payments.", style: TextStyle(color: Colors.white38, fontSize: 13)),
          );
        }

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: friends.length,
            itemBuilder: (ctx, i) {
              final friend = friends[i];
              return _FriendSelectionTile(
                friend: friend,
                onTap: () => _handleFriendSelected(friend, upiId, amountCtrl.text, noteCtrl.text),
              );
            },
          ),
        );
      },
    );
  }

  void _handleFriendSelected(Map<String, dynamic> friend, String upiId, String amount, String note) async {
    final provider = Provider.of<MeshProvider>(context, listen: false);
    final friendMeshId = friend['meshId'] ?? '';
    
    // Use the provider's built-in routing logic
    await provider.sendPaymentRequest(friendMeshId, amount, note.isNotEmpty ? note : 'Mesh Payment', upiId: upiId);

    if (mounted) {
      Navigator.pop(context); // Close sheet
      Navigator.pop(context); // Close scanner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request sent!'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCameraPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan UPI QR')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_rounded, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text("Camera permission denied", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkPermission,
                child: const Text("Grant Permission"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan UPI QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Dark overlay with transparent center hole
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scanning Frame Border
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FC82), width: 2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FC82).withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
                ],
              ),
            ),
          ),
          // Animated Scan Line
          const _AnimatedScanLine(),
          // Helper text
          Positioned(
            bottom: 100,
            left: 0, right: 0,
            child: const Text(
              'Align the UPI QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSelectionTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onTap;

  const _FriendSelectionTile({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = friend['name'] ?? 'Unknown';
    final meshId = friend['meshId'] ?? '';

    return Consumer<MeshProvider>(
      builder: (context, meshProvider, child) {
        final bool isNearby = meshProvider.isFriendNearby(meshId);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: isNearby ? Border.all(color: const Color(0xFF00FC82).withOpacity(0.1), width: 1) : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white10,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (isNearby) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.radar, size: 10, color: Color(0xFF00FC82)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(meshId, style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.6), fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedScanLine extends StatefulWidget {
  const _AnimatedScanLine();
  @override
  State<_AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<_AnimatedScanLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height / 2 - 125 + (_controller.value * 250),
          left: MediaQuery.of(context).size.width / 2 - 125,
          child: Container(
            width: 250,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, const Color(0xFF00FC82), Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00FC82).withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}
