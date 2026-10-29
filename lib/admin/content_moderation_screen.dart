import 'package:fitfuseapp/hover_tap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  State<ContentModerationScreen> createState() => _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedTab = 0; // 0 = Security Alerts, 1 = Community Posts

  Future<void> _deleteDoc(String collectionPath, String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $title'),
        content: Text('Are you sure you want to permanently delete this $title?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.doc('$collectionPath/$docId').delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Header Switcher
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      label: 'Security Alerts',
                      icon: Icons.shield_outlined,
                      activeColor: Colors.red.shade700,
                      stream: _firestore.collection('security_alerts').snapshots(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      label: 'Community Posts',
                      icon: Icons.forum_outlined,
                      activeColor: const Color(0xFF121A33),
                      stream: _firestore.collection('trendingPosts').snapshots(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildSecurityAlertsTab()
                  : _buildCommunityPostsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Stream<QuerySnapshot> stream,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: activeColor.withOpacity(0.3), width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (ctx, snap) {
                final count = snap.hasData ? snap.data!.docs.length : 0;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 0: SECURITY ALERTS (Unauthorized Uploads) ---
  Widget _buildSecurityAlertsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('security_alerts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading alerts: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 64, color: Colors.green.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No Security Violations Detected',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  'All uploaded images comply with safety and wardrobe guidelines.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String userName = data['userName'] ?? 'Unknown User';
            final String userEmail = data['userEmail'] ?? 'No Email';
            final String userId = data['userId'] ?? 'Unknown';
            final String violationType = data['violationType'] ?? 'UNAUTHORIZED_IMAGE';
            final String details = data['details'] ?? 'Unauthorized item upload blocked.';
            final String endpoint = data['endpoint'] ?? 'API';
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            final String timeStr = timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                    .toLocal()
                    .toString()
                    .split('.')[0]
                : 'Just now';

            // Determine badge color and icon based on violation type
            Color badgeColor = Colors.red;
            IconData badgeIcon = Icons.warning_amber_rounded;
            if (violationType == 'WEAPON_DETECTED') {
              badgeColor = Colors.red.shade700;
              badgeIcon = Icons.dangerous_rounded;
            } else if (violationType == 'BLOOD_VIOLENCE_DETECTED') {
              badgeColor = Colors.deepOrange.shade800;
              badgeIcon = Icons.bloodtype_outlined;
            } else if (violationType == 'NON_WARDROBE_ITEM') {
              badgeColor = Colors.amber.shade900;
              badgeIcon = Icons.not_interested_rounded;
            }

            return HoverCard(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: badgeColor.withOpacity(0.3), width: 1.2),
              ),
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: badgeColor.withOpacity(0.12),
                          radius: 22,
                          child: Icon(badgeIcon, color: badgeColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      violationType.replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$userEmail • UID: ${userId.length > 8 ? '${userId.substring(0, 8)}...' : userId}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          tooltip: 'Dismiss Alert',
                          onPressed: () => _deleteDoc('security_alerts', doc.id, 'Alert'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        details,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Source: $endpoint',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 1: COMMUNITY & TRENDING POSTS ---
  Widget _buildCommunityPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('trendingPosts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No community posts available for moderation.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String caption = data['caption'] ?? 'No Caption';
            final String postImage = data['postImage'] ?? '';
            final String userId = data['userId'] ?? '';

            return HoverCard(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF121A33),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(userId).get(),
                      builder: (ctx, userSnap) {
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData = userSnap.data!.data() as Map<String, dynamic>;
                          return Text(
                            '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        }
                        return Text('User UID: $userId');
                      },
                    ),
                    subtitle: Text('Post ID: ${doc.id}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _deleteDoc('trendingPosts', doc.id, 'Post'),
                    ),
                  ),
                  if (postImage.isNotEmpty && postImage.startsWith('http'))
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: Image.network(
                        postImage,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Text(
                      caption,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
