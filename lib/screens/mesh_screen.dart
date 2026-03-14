import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/screens/upi_scanner_screen.dart';
import 'package:crowd_link/screens/chat_screen.dart';

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _loadingController;
  bool isTogglingMesh = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection(BuildContext context) async {
    setState(() {
      isTogglingMesh = true;
    });
    _loadingController.repeat();

    final meshProvider = Provider.of<MeshProvider>(context, listen: false);
    final bool wasConnected = meshProvider.isMeshActive;

    try {
      await meshProvider.toggleMesh();
    } catch (e) {
      debugPrint("Mesh toggle error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isTogglingMesh = false;
        });
        _loadingController.stop();
        _loadingController.reset();

        // Pulse when active
        if (meshProvider.isMeshActive) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    final bool isConnected = meshProvider.isMeshActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Overview',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.normal),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => _openUPIScanner(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: isConnected ? _buildConnectedDashboard(context) : _buildDisconnectedView(context),
                ),
                if (meshProvider.pendingIncomingRequest != null)
                  _buildApprovalOverlay(context, meshProvider.pendingIncomingRequest!),
              ],
            ),
          ),
          // Loading indicator above Navbar
          AnimatedOpacity(
            opacity: isTogglingMesh ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isTogglingMesh ? 100 : 0,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FC82)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isConnected ? 'DEACTIVATING MESH...' : 'ACTIVATING MESH SYSTEM...',
                    style: TextStyle(
                      color: const Color(0xFF00FC82).withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalOverlay(BuildContext context, dynamic request) {
    final meshProvider = Provider.of<MeshProvider>(context, listen: false);
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_lock_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 16),
              const Text('Gateway Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Node ${request.senderMeshId} is requesting temporary internet access.', 
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => meshProvider.denyGatewayRequest(request.requestId),
                      child: const Text('Deny'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => meshProvider.approveGatewayRequest(request.requestId),
                      child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedView(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    return Center(
      key: const ValueKey('disconnected'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            'Mesh Network Offline',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (meshProvider.permissionError != null) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    meshProvider.permissionError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                  if (meshProvider.permissionError!.contains("Location")) ...[
                     const SizedBox(height: 12),
                     ElevatedButton.icon(
                       onPressed: () => meshProvider.toggleMesh(),
                       icon: const Icon(Icons.settings, size: 16),
                       label: const Text("Open Location Settings"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.redAccent,
                         foregroundColor: Colors.white,
                         textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                       ),
                     ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
          GestureDetector(
            onTap: isTogglingMesh ? null : () => _toggleConnection(context),
            child: AnimatedScale(
              scale: isTogglingMesh ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple Pulse Effect
                  if (isTogglingMesh)
                    ...List.generate(2, (index) => AnimatedBuilder(
                      animation: _loadingController,
                      builder: (context, child) {
                        final progress = (_loadingController.value + (index * 0.5)) % 1.0;
                        return Container(
                          width: 160 + (80 * progress),
                          height: 160 + (80 * progress),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5 * (1.0 - progress)),
                              width: 3 * (1.0 - progress),
                            ),
                          ),
                        );
                      },
                    )),

                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardTheme.color,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(isTogglingMesh ? 0.4 : 0.15),
                              spreadRadius: isTogglingMesh ? 25 : 20 * _pulseAnimation.value,
                              blurRadius: isTogglingMesh ? 45 : 40 * _pulseAnimation.value,
                            )
                          ],
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(isTogglingMesh ? 1.0 : 0.6),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: isTogglingMesh 
                            ? SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDashboard(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    return SingleChildScrollView(
      key: const ValueKey('connected'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status
          _buildHeaderStatus(context),
          const SizedBox(height: 24),

          // Main Metric Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildNearbyDevicesCard(context)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildSignalCard(context)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Secondary Info Grid
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildGatewayCard(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildSmallStatCard(context, 'Message Relay', 'Active', Icons.dynamic_feed_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSmallStatCard(context, 'Network Delay', '24 ms', Icons.speed_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildSmallStatCard(context, 'Sync Status', 'Up to date', Icons.cloud_done_rounded)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          
          const Text(
            'Nodes Connected',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _buildNodesConnectedList(context, meshProvider),

          const SizedBox(height: 28),
          _buildLogsHeader(context, meshProvider),
          const SizedBox(height: 12),
          _buildLogsCard(context, meshProvider),
          
          const SizedBox(height: 48),
          Center(
            child: GestureDetector(
              onTap: () => _showDisconnectSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showDisconnectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SlideToDisconnect(
        onDisconnected: () {
          Navigator.pop(ctx);
          _toggleConnection(context);
        },
      ),
    );
  }

  Widget _buildHeaderStatus(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    final int peerCount = meshProvider.connectedPeerCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      blurRadius: 10 * _pulseAnimation.value,
                      spreadRadius: 4 * _pulseAnimation.value,
                    )
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesh Network Active',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${meshProvider.connectedPeerCount} nodes nearby • ${meshProvider.gatewayNodes.length} gateways',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network Health',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Excellent',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_rounded, color: Theme.of(context).colorScheme.primary, size: 36),
          )
        ],
      ),
    );
  }

  Widget _buildNearbyDevicesCard(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nodes Connected',
            style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            '${meshProvider.connectedPeerCount} Active',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }


  Widget _buildSignalCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Signal Strength',
            style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(context, 14, true),
              const SizedBox(width: 4),
              _buildBar(context, 20, true),
              const SizedBox(width: 4),
              _buildBar(context, 28, true),
              const SizedBox(width: 4),
              _buildBar(context, 36, false),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Strong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, double height, bool active) {
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildGatewayCard(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    final gateways = meshProvider.gatewayNodes;
    final bool isGatewayAvailable = gateways.isNotEmpty;
    final activeSession = meshProvider.activeSession;
    
    // If we have an active session or are in queue
    final myMeshId = meshProvider.isMeshActive ? "You" : ""; // Simplified for labels
    final bool iAmInQueue = meshProvider.requestQueue.any((r) => r.senderMeshId == myMeshId);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isGatewayAvailable ? () => _showGatewayActionSheet(context, gateways.first) : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isGatewayAvailable ? Icons.public : Icons.public_off,
                  color: isGatewayAvailable ? Theme.of(context).colorScheme.primary : Colors.redAccent,
                  size: 28,
                ),
                 const SizedBox(height: 16),
                const Text(
                  'Internet Gateway',
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  isGatewayAvailable 
                    ? (activeSession != null ? 'Session Active' : 'Gateway Available') 
                    : 'No Gateway Found',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                ),
                if (isGatewayAvailable && !iAmInQueue && activeSession == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Tap to connect',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (iAmInQueue)
                   const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Waiting in queue...',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGatewayActionSheet(BuildContext context, dynamic gatewayNode) {
    final meshProvider = Provider.of<MeshProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Icon(Icons.wifi_tethering_rounded, color: Colors.blueAccent, size: 48),
            const SizedBox(height: 16),
            const Text('Request Internet Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Request a temporary internet session from ${gatewayNode.deviceName} via the mesh network.', 
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                meshProvider.requestInternet(gatewayNode.endpointId);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Internet access request submitted to queue.')),
                );
              },
              child: const Text('Connect to Gateway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(BuildContext context, String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
         color: Theme.of(context).cardTheme.color,
         borderRadius: BorderRadius.circular(24),
         boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 28),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsHeader(BuildContext context, MeshProvider meshProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Diagnostic Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        TextButton(
          onPressed: () => meshProvider.clearLogs(),
          child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildLogsCard(BuildContext context, MeshProvider meshProvider) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: meshProvider.logs.isEmpty
          ? const Center(child: Text("No logs yet", style: TextStyle(color: Colors.white24, fontSize: 12)))
          : ListView.builder(
              itemCount: meshProvider.logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    meshProvider.logs[index],
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(context, Icons.campaign_rounded, 'Broadcast', Colors.orangeAccent, 
          onTap: () => meshProvider.broadcastMessage("Mesh Broadcast from ${meshProvider.connectedPeerCount} nodes away", isSos: false)),
        _buildActionButton(context, Icons.person_add_alt_1_rounded, 'Add Friend', Theme.of(context).colorScheme.primary),
        _buildActionButton(context, Icons.sos_rounded, 'SOS Alert', Colors.redAccent,
          onTap: () => meshProvider.broadcastMessage("SOS ALERT! NEED HELP!", isSos: true)),
        _buildActionButton(context, Icons.share_location_rounded, 'Share Loc.', Colors.blueAccent),
      ],
    );
  }

  Widget _buildNodesConnectedList(BuildContext context, MeshProvider provider) {
    final nodes = provider.connectedPeers.values.toList();
    if (nodes.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Center(child: Text("No nodes connected", style: TextStyle(color: Colors.white24, fontSize: 12))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nodes.length,
      itemBuilder: (ctx, idx) {
        final node = nodes[idx];
        final bool isFriend = provider.friendMeshIds.contains(node.meshId);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: isFriend 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.white10,
            child: Text(
              node.deviceName.isNotEmpty ? node.deviceName[0].toUpperCase() : '?', 
              style: TextStyle(color: isFriend ? Theme.of(context).colorScheme.primary : Colors.white60)
            ),
          ),
          title: Text(node.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("ID: ${node.meshId} • ${node.isGateway ? 'GATEWAY' : 'NODE'} ${isFriend ? '(FRIEND)' : ''}", 
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatWindowScreen(friendUid: '', friendName: node.deviceName, friendMeshId: node.meshId),
          )),
        );
      },
    );
  }

  void _openUPIScanner(BuildContext context) {
    // We'll use mobile_scanner to scan. 
    // I need to implement a scanner dialog or screen.
     Navigator.push(context, MaterialPageRoute(builder: (context) => const UPIScannerScreen()));
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// ─── Slide to Disconnect Widget ──────────────────────────────────────────────
class _SlideToDisconnect extends StatefulWidget {
  final VoidCallback onDisconnected;
  const _SlideToDisconnect({required this.onDisconnected});

  @override
  State<_SlideToDisconnect> createState() => _SlideToDisconnectState();
}

class _SlideToDisconnectState extends State<_SlideToDisconnect> {
  double _dragPosition = 0;
  static const double _trackWidth = 280;
  static const double _thumbSize = 56;
  static const double _maxDrag = _trackWidth - _thumbSize - 8;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, _maxDrag);
    });
    if (_dragPosition >= _maxDrag) {
      widget.onDisconnected();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragPosition < _maxDrag) {
      setState(() => _dragPosition = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _dragPosition / _maxDrag;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Disconnect Network?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'You will lose access to the mesh and all peers.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Slider track
          Container(
            width: _trackWidth,
            height: _thumbSize + 8,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Fill track
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: (_dragPosition + _thumbSize + 8).clamp(_thumbSize + 8, _trackWidth),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15 + progress * 0.25),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),

                // Label
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: (1.0 - progress * 2.5).clamp(0.0, 1.0),
                    child: const Text(
                      'Slide to disconnect  ›',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ),
                ),

                // Thumb
                Positioned(
                  left: 4 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 16, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
