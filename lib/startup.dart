import 'package:fitfuseapp/community.dart';
import 'package:fitfuseapp/explore.dart';
import 'package:fitfuseapp/homepage.dart';
import 'package:fitfuseapp/profilepage.dart';
import 'package:fitfuseapp/wardrobe.dart';
import 'package:flutter/material.dart';

class Startup extends StatefulWidget {
  const Startup({super.key});

  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> with TickerProviderStateMixin {
  int selectedIndex = 0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
      _controller.forward().then((_) {
        _controller.reverse();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> pages = [
    const MyHome(),
    const MyWardrobe(),
    const CommunityPage(),
    const ExplorePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Color.fromARGB(255, 39, 87, 176)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.7),
          items: [
            _buildAnimatedItem(
                Icons.home_outlined, Icons.home_filled, "Home", 0),
            _buildAnimatedItem(
                Icons.shopping_bag_outlined, Icons.shopping_bag, "Wardrobe", 1),
            _buildAnimatedItem(
                Icons.people_alt_outlined, Icons.people, "Community", 2),
            _buildAnimatedItem(Icons.travel_explore_outlined,
                Icons.travel_explore, "Explore", 3),
            _buildAnimatedItem(
                Icons.person_2_outlined, Icons.person, "Profile", 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedItem(
      IconData icon, IconData activeIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: selectedIndex == index
          ? ScaleTransition(
              scale: _animation,
              child: Icon(activeIcon),
            )
          : Icon(icon),
      label: label,
    );
  }
}
