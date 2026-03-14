import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mesh_screen.dart';
import 'chat_screen.dart';
import 'activity_screen.dart';
import '../providers/mesh_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MeshScreen(),
    const ChatScreen(),
    const ActivityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final meshProvider = Provider.of<MeshProvider>(context);
    
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.space_dashboard_rounded, 'Overview', 
                 badge: meshProvider.isMeshActive ? meshProvider.connectedPeerCount : null),
              _buildNavItem(1, Icons.chat_bubble_rounded, 'Chats'),
              _buildNavItem(2, Icons.history_rounded, 'Activity'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int? badge}) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index < _pages.length) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 24 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white54,
                  size: 26,
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
