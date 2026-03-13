import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/mesh_node_icon.dart';
import '../widgets/pulse_dot.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({Key? key}) : super(key: key);

  @override
  _OverviewScreenState createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _isNetworkActive = false;

  void _toggleNetworkState() {
    setState(() {
      _isNetworkActive = !_isNetworkActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isNetworkActive
              ? _buildActiveOverview()
              : _buildOfflineOverview(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Overview',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOfflineOverview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const MeshNodeIcon(),
        const SizedBox(height: 32),
        Text(
          'Mesh Network Offline',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 64),
        GestureDetector(
          onTap: _toggleNetworkState,
          child: _buildPowerButton(),
        ),
      ],
    );
  }

  Widget _buildPowerButton() {
    return Container(
      width: 192,
      height: 192,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryNeonGreen, width: 2),
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNeonGreen.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceCharcoal,
          ),
          child: const Center(
            child: Icon(
              Icons.power_settings_new_rounded,
              color: AppColors.primaryNeonGreen,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOverview() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        _buildStatisticsGrid(),
        const SizedBox(height: 16),
        _buildPerformanceCards(),
        const SizedBox(height: 24),
        _buildNodesSectionHeader(),
        const SizedBox(height: 16),
        Container(
          height: 128,
          decoration: BoxDecoration(
            color: AppColors.surfaceCharcoal.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 80), 
      ],
    );
  }

  Widget _buildStatusCard() {
    return GestureDetector(
      onTap: _toggleNetworkState,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.statusActiveBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.statusActiveBorder),
        ),
        child: Row(
          children: [
            const PulseDot(),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesh Network Active', 
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)
                ),
                const SizedBox(height: 4),
                Text(
                  '0 nodes nearby • 0 gateways', 
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.inactiveGrey)
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildNodesConnectedCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildSignalStrengthCard()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInternetGatewayCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildMessageRelayCard()),
          ],
        )
      ],
    );
  }

  Widget _buildNodesConnectedCard() {
    return _buildCustomCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Nodes Connected', style: GoogleFonts.inter(color: AppColors.inactiveGrey, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 40),
          Text('0 Active', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSignalStrengthCard() {
    return _buildCustomCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Signal\nStrength', style: GoogleFonts.inter(color: AppColors.inactiveGrey, fontSize: 13, fontWeight: FontWeight.w500, height: 1.2)),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 6, height: 12, decoration: BoxDecoration(color: AppColors.primaryNeonGreen, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 20, decoration: BoxDecoration(color: AppColors.primaryNeonGreen, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 28, decoration: BoxDecoration(color: AppColors.primaryNeonGreen, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 16, decoration: BoxDecoration(color: AppColors.inactiveSignal, borderRadius: BorderRadius.circular(3))),
                ],
              ),
              const SizedBox(height: 8),
              Text('Strong', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInternetGatewayCard() {
    return _buildCustomCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.dangerRed, size: 32),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Internet Gateway', style: GoogleFonts.inter(color: AppColors.inactiveGrey, fontSize: 13)),
              const SizedBox(height: 4),
              Text('No Gateway Found', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.1)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMessageRelayCard() {
    return _buildCustomCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.hub_outlined, color: AppColors.inactiveGrey, size: 32),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Message Relay', style: GoogleFonts.inter(color: AppColors.inactiveGrey, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Active', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallPerformanceCard(
            icon: Icons.schedule_rounded,
            title: 'Network Delay',
            value: '24 ms',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSmallPerformanceCard(
            icon: Icons.sync_rounded,
            title: 'Sync Status',
            value: 'Up to date',
          ),
        ),
      ],
    );
  }

  Widget _buildSmallPerformanceCard({required IconData icon, required String title, required String value}) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCharcoal,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.inactiveGrey, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: AppColors.inactiveGrey, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ]
          )
        ]
      )
    );
  }

  Widget _buildCustomCard({required Widget child}) {
    return Container(
      height: 170, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCharcoal,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  Widget _buildNodesSectionHeader() {
    return Text(
      'Nodes Connected', 
      style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)
    );
  }
}
