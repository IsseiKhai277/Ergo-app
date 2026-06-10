import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../jobs/post_job_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // The pages for each bottom navigation tab. We use an empty container for index 2 since it opens a new screen.
  final List<Widget> _pages = [
    const HomeScreen(), // 0: Bulletin Board
    const Center(child: Text('Search (Coming Soon)')), // 1
    const SizedBox(), // 2: Post Job (Intercepted in onTap)
    const Center(child: Text('Messages (Coming Soon)')), // 3
    const ProfileScreen(), // 4: Profile
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PostJobScreen()),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              label: 'Post',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.message_rounded),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
