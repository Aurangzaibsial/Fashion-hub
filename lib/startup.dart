import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fitfuseapp/hover_tap.dart';
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

  static const _navItems = <List<Object>>[
    [Icons.home_outlined, Icons.home_rounded, 'Home'],
    [Icons.checkroom_outlined, Icons.checkroom_rounded, 'Wardrobe'],
    [Icons.people_alt_outlined, Icons.people_alt_rounded, 'Community'],
    [Icons.explore_outlined, Icons.explore_rounded, 'Explore'],
    [Icons.person_outline_rounded, Icons.person_rounded, 'Profile'],
  ];

  Widget _buildSidebar() {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE7E4EC))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121A33),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('N',
                          style: GoogleFonts.sora(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Positioned(
                        right: 8,
                        bottom: 9,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFFE0A58F), shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.sora(
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: const Color(0xFF0E1220)),
                      children: const [
                        TextSpan(text: 'NextGen\n'),
                        TextSpan(
                            text: 'Cloth Engine',
                            style: TextStyle(color: Color(0xFFA15A44))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < _navItems.length; i++) _buildSideItem(i),
          const Spacer(),
          _buildUserCard(),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final first = (d?['firstName'] ?? '').toString().trim();
        final last = (d?['lastName'] ?? '').toString().trim();
        var name = '$first $last'.trim();
        if (name.isEmpty) name = (user.displayName ?? '').trim();
        if (name.isEmpty) name = 'My account';
        final photo = (d?['profilePicURL'] ?? d?['profileImage'] ?? '').toString();
        final initials = name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
        return HoverTap(
          lift: false,
          onTap: () => onItemTapped(4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E4EC)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF3E3DD),
                  backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                  child: photo.startsWith('http')
                      ? null
                      : Text(initials,
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFA15A44))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0E1220))),
                      Text('View profile',
                          style: GoogleFonts.manrope(
                              fontSize: 12, color: const Color(0xFF5B6177))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideItem(int index) {
    final item = _navItems[index];
    final selected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverTap(
        lift: false,
        onTap: () => onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF121A33) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                (selected ? item[1] : item[0]) as IconData,
                size: 22,
                color: selected ? Colors.white : const Color(0xFF5B6177),
              ),
              const SizedBox(width: 12),
              Text(
                item[2] as String,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF5B6177),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(child: pages[selectedIndex]),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, Icons.home_rounded, "Home", 0),
                _buildNavItem(Icons.checkroom_outlined, Icons.checkroom_rounded, "Wardrobe", 1),
                _buildNavItem(Icons.people_alt_outlined, Icons.people_alt_rounded, "Community", 2),
                _buildNavItem(Icons.explore_outlined, Icons.explore_rounded, "Explore", 3),
                _buildNavItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile", 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    return HoverTap(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF121A33), Color(0xFF1E2A4F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: isSelected ? _animation : const AlwaysStoppedAnimation(1.0),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : const Color(0xFFAAAAAA),
                size: 22,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
