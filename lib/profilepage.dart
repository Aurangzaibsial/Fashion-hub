// ignore_for_file: unnecessary_cast

import 'dart:convert';
import 'package:fitfuseapp/login.dart';
import 'package:fitfuseapp/preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({Key? key, this.userId}) : super(key: key);
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _usersRef = _firestore.collection('users');

  List<DocumentSnapshot> _posts = [];
  bool _isLoadingPosts = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastPost;
  final int _postLimit = 10;
  final ScrollController _scrollController = ScrollController();

  User? get _currentUser => _auth.currentUser;
  // Use the provided userId if available; otherwise, use the current user's UID.
  String get effectiveUserId => widget.userId ?? _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingPosts &&
          _hasMorePosts) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _uploadToCloudinary(XFile pickedFile) async {
    const String cloudName = "dxwp10qod";
    const String uploadPreset = "imageupload";
    final url =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    final bytes = await pickedFile.readAsBytes();
    String fileName = pickedFile.name;
    if (fileName.endsWith('.jpgs')) {
      fileName = fileName.replaceAll('.jpgs', '.jpg');
    }
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final response = await request.send();
    if (response.statusCode == 200) {
      final resData = jsonDecode(await response.stream.bytesToString());
      return resData['secure_url'];
    } else {
      throw Exception("Image upload failed");
    }
  }

  Future<void> _updateProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && _currentUser != null) {
      try {
        final imageUrl = await _uploadToCloudinary(picked);
        if (imageUrl.isNotEmpty) {
          await _usersRef
              .doc(_currentUser!.uid)
              .update({'profileImage': imageUrl});
        }
      } catch (e) {
        debugPrint("Error updating profile image: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update image: $e")),
          );
        }
      }
    }
  }

  Future<void> _confirmAndUpdateProfileImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm"),
        content:
            const Text("Are you sure you want to change your profile picture?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateProfileImage();
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No date';
    if (timestamp is Timestamp) {
      return DateFormat('MMMM d, y').format(timestamp.toDate());
    } else if (timestamp is int) {
      return DateFormat('MMMM d, y')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    }
    return 'Invalid date';
  }

  Future<Map<String, int>> _getUserStats() async {
    int totalLikes = 0;
    try {
      final postsSnapshot = await _usersRef
          .doc(effectiveUserId)
          .collection('communityPosts')
          .get();
      for (var post in postsSnapshot.docs) {
        final data = post.data() as Map<String, dynamic>;
        final likesList = data['likes'] is List ? data['likes'] as List : [];
        totalLikes += likesList.length;
      }
    } catch (e) {
      debugPrint("Error fetching posts stats: $e");
    }
    final userDoc = await _usersRef.doc(effectiveUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    int followersCount = (userData?['followers'] is List)
        ? (userData?['followers'] as List).length
        : 0;
    int followingCount = (userData?['following'] is List)
        ? (userData?['following'] as List).length
        : 0;
    return {
      'followers': followersCount,
      'following': followingCount,
      'totalLikes': totalLikes,
    };
  }

  void _showEditProfileDialog(Map<String, dynamic> userData) {
    final firstNameController =
        TextEditingController(text: userData['firstName'] ?? '');
    final lastNameController =
        TextEditingController(text: userData['lastName'] ?? '');
    final usernameController =
        TextEditingController(text: userData['username'] ?? '');
    final bioController = TextEditingController(text: userData['bio'] ?? '');
    final emailController =
        TextEditingController(text: userData['email'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: "First Name"),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: "Last Name"),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: "Bio"),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _usersRef.doc(_currentUser!.uid).update({
                    'firstName': firstNameController.text,
                    'lastName': lastNameController.text,
                    'username': usernameController.text,
                    'bio': bioController.text,
                    'email': emailController.text,
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error saving profile: $e")));
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInitialPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
      _hasMorePosts = true;
    });
    try {
      Query query = _usersRef
          .doc(effectiveUserId)
          .collection('communityPosts')
          .orderBy('clientTimestamp', descending: true)
          .limit(_postLimit);
      QuerySnapshot querySnapshot = await query.get();
      if (!mounted) return;
      setState(() {
        _posts = querySnapshot.docs;
        if (querySnapshot.docs.length < _postLimit) {
          _hasMorePosts = false;
        }
        if (_posts.isNotEmpty) {
          _lastPost = _posts.last;
        }
        _isLoadingPosts = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error loading posts: $e")));
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _lastPost == null) return;
    if (!mounted) return;
    setState(() => _isLoadingPosts = true);
    try {
      Query query = _usersRef
          .doc(effectiveUserId)
          .collection('communityPosts')
          .orderBy('clientTimestamp', descending: true)
          .startAfterDocument(_lastPost!)
          .limit(_postLimit);
      QuerySnapshot querySnapshot = await query.get();
      if (!mounted) return;
      setState(() {
        if (querySnapshot.docs.isNotEmpty) {
          _posts.addAll(querySnapshot.docs);
          _lastPost = querySnapshot.docs.last;
        }
        if (querySnapshot.docs.length < _postLimit) {
          _hasMorePosts = false;
        }
        _isLoadingPosts = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading more posts: $e")));
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    if (!mounted) return;
    setState(() {
      _posts.clear();
      _lastPost = null;
      _hasMorePosts = true;
    });
    await _loadInitialPosts();
  }

  void _openUserList(String title, List<dynamic> userIds) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserListPage(title: title, userIds: userIds.cast<String>()),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    final String name =
        (("${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}")
                    .trim()
                    .isEmpty
                ? 'Your Name'
                : "${userData['firstName']} ${userData['lastName']}")
            .trim();
    final String profileImage = userData['profileImage'] ?? '';
    List<dynamic> followersList = userData['followers'] ?? [];
    List<dynamic> followingList = userData['following'] ?? [];

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 250,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/probg.jpg"),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
            // Only show logout if viewing own profile.
            if (effectiveUserId == _auth.currentUser!.uid)
              Positioned(
                top: 40,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.logout,
                      color: Color.fromARGB(255, 82, 82, 82), size: 28),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Confirm Logout"),
                        content:
                            const Text("Are you sure you want to log out?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                        );
                      }
                    }
                  },
                ),
              ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: effectiveUserId == _auth.currentUser!.uid
                        ? _confirmAndUpdateProfileImage
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 62,
                        backgroundColor: Colors.grey,
                        backgroundImage: profileImage.isNotEmpty
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage.isEmpty
                            ? const Icon(Icons.person, size: 63)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<Map<String, int>>(
          future: _getUserStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            final stats = snapshot.data ??
                {'followers': 0, 'following': 0, 'totalLikes': 0};
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat("Following", stats['following']!.toString(),
                    onTap: () => _openUserList("Following", followingList)),
                _buildStat("Followers", stats['followers']!.toString(),
                    onTap: () => _openUserList("Followers", followersList)),
                _buildStat("Likes", stats['totalLikes']!.toString()),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (effectiveUserId == _auth.currentUser!.uid)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                      color: Color.fromARGB(255, 5, 80, 241), width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const Preferences()),
                  );
                },
                child: const Text("Preferences",
                    style: TextStyle(color: Colors.black)),
              ),
              const SizedBox(width: 70),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                      color: Color.fromARGB(255, 5, 80, 241), width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showEditProfileDialog(userData),
                child: const Text("Edit Profile",
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStat(String label, String value, {VoidCallback? onTap}) {
    Widget content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration:
              BoxDecoration(color: Colors.pink[100], shape: BoxShape.circle),
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }
    return content;
  }

  Widget _buildPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Posts",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        RefreshIndicator(
          onRefresh: _refreshPosts,
          child: ListView.builder(
            controller: _scrollController,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length + 1,
            itemBuilder: (context, index) {
              if (index < _posts.length) {
                return _buildPostCard(_posts[index]);
              } else {
                if (_hasMorePosts) {
                  return _isLoadingPosts
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : TextButton(
                          onPressed: _loadMorePosts,
                          child: const Text("Load More"),
                        );
                } else {
                  return const SizedBox.shrink();
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(DocumentSnapshot postDoc) {
    final post = postDoc.data() as Map<String, dynamic>;
    final String userId = post['userId'] ?? '';
    final String caption = post['caption'] ?? '';
    final String postImage = post['postImage'] ?? '';
    final int likes =
        (post['likes'] is List) ? (post['likes'] as List).length : 0;
    final int comments = post['commentCount'] ?? 0;
    final int shares = post['shares'] ?? 0;
    final dynamic clientTimestamp = post['clientTimestamp'];
    final String date = _formatDate(clientTimestamp);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String profileImage = "assets/images/profile.jpg";
        String fullName = "Anonymous";
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          profileImage = userData['profileImage'] ?? profileImage;
          fullName =
              ("${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}")
                  .trim();
          if (fullName.isEmpty) fullName = "Anonymous";
        }
        return Card(
          margin: const EdgeInsets.all(10),
          color: const Color.fromARGB(255, 125, 134, 255),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: profileImage.startsWith("http")
                      ? NetworkImage(profileImage)
                      : AssetImage(profileImage) as ImageProvider,
                ),
                title: Text(fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
                subtitle: Text(date,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPost(postDoc);
                    } else if (value == 'delete') {
                      _deletePost(postDoc);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
              if (postImage.isNotEmpty)
                GestureDetector(
                  onTap: () => _openFullImage(postImage),
                  child: Image.network(postImage,
                      fit: BoxFit.cover, width: double.infinity, height: 200),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(caption,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _iconButton(Icons.thumb_up_outlined, likes),
                    _iconButton(Icons.comment, comments),
                    _iconButton(Icons.share, shares),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editPost(DocumentSnapshot postDoc) {
    final post = postDoc.data() as Map<String, dynamic>;
    final TextEditingController captionController =
        TextEditingController(text: post['caption']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Post"),
          content: TextField(
            controller: captionController,
            decoration: const InputDecoration(labelText: "Caption"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _usersRef
                    .doc(_currentUser!.uid)
                    .collection('communityPosts')
                    .doc(postDoc.id)
                    .update({'caption': captionController.text});
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _deletePost(DocumentSnapshot postDoc) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Post"),
          content: const Text("Are you sure you want to delete this post?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _usersRef
                    .doc(_currentUser!.uid)
                    .collection('communityPosts')
                    .doc(postDoc.id)
                    .delete();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Widget _iconButton(IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: Colors.black),
        const SizedBox(width: 4),
        Text("$count", style: const TextStyle(color: Colors.black)),
      ],
    );
  }

  void _openFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => FullImagePage(imageUrl: imageUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 125, 134, 255),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _usersRef.doc(effectiveUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(userData),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("Bio",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        userData['bio']?.toString() ?? 'No bio provided',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                _buildPostsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final String imageUrl;
  const FullImagePage({Key? key, required this.imageUrl}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }
}

class UserListPage extends StatelessWidget {
  final String title;
  final List<String> userIds;
  const UserListPage({Key? key, required this.title, required this.userIds})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          final userId = userIds[index];
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(title: Text("Loading..."));
              }
              if (!snapshot.data!.exists) {
                return const ListTile(title: Text("User not found"));
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final fullName =
                  ("${data['firstName'] ?? ''} ${data['lastName'] ?? ''}")
                      .trim();
              final profileImage =
                  data['profileImage'] ?? 'assets/images/profile.jpg';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: profileImage.startsWith('http')
                      ? NetworkImage(profileImage)
                      : AssetImage(profileImage) as ImageProvider,
                ),
                title: Text(fullName.isNotEmpty ? fullName : "Anonymous"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfilePage(userId: userId)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
