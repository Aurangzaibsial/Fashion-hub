import 'package:fitfuseapp/img_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitfuseapp/hover_tap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users by name, username, or email...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF121A33)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'user', child: Text('Users')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _roleFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // User List Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final role = data['role']?.toString() ?? 'user';
                    final firstName = (data['firstName'] ?? '').toString().toLowerCase();
                    final lastName = (data['lastName'] ?? '').toString().toLowerCase();
                    final username = (data['username'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();

                    final matchesRole = _roleFilter == 'all' || role == _roleFilter;
                    final matchesSearch = _searchQuery.isEmpty ||
                        firstName.contains(_searchQuery) ||
                        lastName.contains(_searchQuery) ||
                        username.contains(_searchQuery) ||
                        email.contains(_searchQuery);

                    return matchesRole && matchesSearch;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found matching your criteria.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = doc.id;
                      final String firstName = data['firstName'] ?? '';
                      final String lastName = data['lastName'] ?? '';
                      final String username = data['username'] ?? 'No Username';
                      final String email = data['email'] ?? 'No Email';
                      final String role = data['role'] ?? 'user';
                      final bool isBlocked = data['isBlocked'] ?? false;
                      final String profileImage = data['profileImage'] ?? '';

                      final fullName = '$firstName $lastName'.trim();

                      return HoverCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF121A33).withOpacity(0.1),
                            backgroundImage: profileImage.startsWith('http')
                                ? CachedNetworkImageProvider(thumb(profileImage, 200))
                                : null,
                            child: profileImage.isEmpty || !profileImage.startsWith('http')
                                ? Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Color(0xFF121A33),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Text(
                                fullName.isNotEmpty ? fullName : username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: role == 'admin'
                                      ? Color(0xFFD5DBEC)
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: role == 'admin'
                                        ? Color(0xFF121A33)
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              if (isBlocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'BLOCKED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@$username • $email'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'toggle_block') {
                                await _firestore.collection('users').doc(uid).update({
                                  'isBlocked': !isBlocked,
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isBlocked ? 'User Unblocked' : 'User Blocked',
                                      ),
                                    ),
                                  );
                                }
                              } else if (value == 'toggle_role') {
                                final newRole = role == 'admin' ? 'user' : 'admin';
                                await _firestore.collection('users').doc(uid).update({
                                  'role': newRole,
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('User role updated to $newRole'),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle_block',
                                child: Text(isBlocked ? 'Unblock User' : 'Block User'),
                              ),
                              PopupMenuItem(
                                value: 'toggle_role',
                                child: Text(role == 'admin' ? 'Demote to User' : 'Make Admin'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
