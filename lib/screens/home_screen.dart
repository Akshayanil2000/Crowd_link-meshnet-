import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'overview_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const OverviewScreen(),
    const ChatScreen(),
    const Center(child: Text('Activity', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      extendBody: true, // Allows content to flow behind transparent bottom nav
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.only(top: 12.0, bottom: 32.0, left: 24, right: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCharcoal.withOpacity(0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(index: 0, title: 'Overview', iconData: Icons.dashboard_outlined, activeIconData: Icons.dashboard),
              _buildNavItem(index: 1, title: 'Chats', iconData: Icons.chat_bubble_outline, activeIconData: Icons.chat),
              _buildNavItem(index: 2, title: 'Activity', iconData: Icons.notifications_outlined, activeIconData: Icons.notifications),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData iconData,
    required IconData activeIconData,
  }) {
    bool isActive = _selectedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIconData : iconData,
            color: isActive ? AppColors.primaryNeonGreen : Colors.grey[500],
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: isActive ? AppColors.primaryNeonGreen : Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
