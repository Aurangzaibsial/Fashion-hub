import 'package:fitfuseapp/hover_tap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'content_moderation_screen.dart';
import 'recommender_status_screen.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'NextGen Cloth Engine Admin Panel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF121A33),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE0A58F),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
            Tab(icon: Icon(Icons.security_rounded), text: 'Moderation'),
            Tab(icon: Icon(Icons.psychology_rounded), text: 'AI Backend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminOverviewScreen(),
          UserManagementScreen(),
          ContentModerationScreen(),
          RecommenderStatusScreen(),
        ],
      ),
    );
  }
}

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview & Key Metrics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // Realtime Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricStreamCard(
                  stream: firestore.collection('users').snapshots(),
                  title: 'Total Users',
                  icon: Icons.people_outline,
                  color: const Color(0xFF121A33),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricStreamCard(
                  stream: firestore.collection('trendingPosts').snapshots(),
                  title: 'Trending Posts',
                  icon: Icons.auto_awesome,
                  color: const Color(0xFFE0A58F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricStreamCard(
                  stream: firestore.collection('security_alerts').snapshots(),
                  title: 'Security Alerts',
                  icon: Icons.shield_outlined,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick System Status Card
          HoverCard(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Color(0xFF121A33)),
                      SizedBox(width: 8),
                      Text(
                        'Admin Access Active',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are logged in as a Super Admin. Role-Based Access Control (RBAC) is active across all collections.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricStreamCard({
    required Stream<QuerySnapshot> stream,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return HoverCard(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  '$count',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}
