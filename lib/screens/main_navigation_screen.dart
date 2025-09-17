import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'analysis/analysis_screen.dart';
import 'education/education_screen.dart';
import 'community/community_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalysisScreen(),
    const EducationScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, Icons.home_outlined, 'Home'),
                _buildNavItem(1, Icons.search, Icons.search_outlined, 'Detection\nTool'),
                _buildNavItem(2, Icons.school, Icons.school_outlined, 'Education\nHub'),
                _buildNavItem(3, Icons.people, Icons.people_outline, 'Community'),
                _buildNavItem(4, Icons.person, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}