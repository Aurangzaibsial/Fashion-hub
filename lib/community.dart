// ignore_for_file: unnecessary_cast

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'profilepage.dart';
import 'messege.dart';

const Color primaryColor = Colors.blueAccent;
const Color secondaryColor = Color.fromARGB(255, 125, 134, 255);
const Color accentColor = Colors.white;

class UserCache {
  static final Map<String, String> profileImageCache = {};
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  InputDecoration _buildSearchDecoration() {
    return InputDecoration(
      hintText: 'Search users...',
      prefixIcon: const Icon(Icons.search, color: primaryColor),
      suffixIcon: _searchQuery.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: primaryColor),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            )
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: secondaryColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                const defaultAvatar = CircleAvatar(
                  backgroundColor: accentColor,
                  child: Icon(Icons.person, color: primaryColor),
                );
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return defaultAvatar;
                }
                var userData = snapshot.data!.data() as Map<String, dynamic>;
                String profileImage = userData['profileImage'] ?? '';
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    ),
                    child: CircleAvatar(
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : const AssetImage('assets/images/man.jpg')
                              as ImageProvider,
                    ),
                  ),
                );
              },
            ),
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
                decoration: _buildSearchDecoration(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.message, color: accentColor),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MessagingPage(
                      contactName: "Danish",
                      contactImage: "assets/images/man.jpg",
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Removed the stories section permanently.
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  labelColor: Colors.black,
                  indicatorColor: Colors.black,
                  unselectedLabelColor: accentColor,
                  labelStyle:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  unselectedLabelStyle:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  labelPadding: EdgeInsets.symmetric(horizontal: 20),
                  tabs: [
                    Tab(text: 'For You'),
                    Tab(text: 'Following'),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      PostList(),
                      FollowingPostList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePostPage()),
            ),
            backgroundColor: primaryColor,
            child: const Icon(Icons.add, size: 30),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
        // Search overlay with a clean, full-screen look.
        if (_searchQuery.isNotEmpty)
          Container(
            color: Colors.white.withOpacity(0.95),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('username', isGreaterThanOrEqualTo: _searchQuery)
                  .where('username',
                      isLessThanOrEqualTo: _searchQuery + '\uf8ff')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs;
                if (users.isEmpty) {
                  return const Center(child: Text("No users found"));
                }
                return ListView.separated(
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.grey),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData =
                        users[index].data() as Map<String, dynamic>;
                    final username = userData['username'] ?? '';
                    final profileImage =
                        userData['profileImage'] ?? 'assets/images/profile.jpg';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profileImage.startsWith('http')
                            ? NetworkImage(profileImage)
                            : AssetImage(profileImage) as ImageProvider,
                      ),
                      title: Text(username),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfilePage(userId: users[index].id),
                          ),
                        );
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class PostList extends StatefulWidget {
  const PostList({Key? key}) : super(key: key);
  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final List<DocumentSnapshot> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchPosts();
      }
    });
  }

  Future<void> _fetchPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    Query query = FirebaseFirestore.instance
        .collectionGroup('communityPosts')
        .orderBy('clientTimestamp', descending: true)
        .limit(_limit);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    try {
      QuerySnapshot querySnapshot = await query.get();
      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _posts.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint("Error fetching posts: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text("No posts available"));
    }
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final docSnap = _posts[index];
            final data = docSnap.data() as Map<String, dynamic>;
            return PostCard(
              data: data,
              docId: docSnap.id,
              userDocId: data['userId'] ?? '',
            );
          } else {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

class FollowingPostList extends StatefulWidget {
  const FollowingPostList({Key? key}) : super(key: key);

  @override
  State<FollowingPostList> createState() => _FollowingPostListState();
}

class _FollowingPostListState extends State<FollowingPostList> {
  final List<DocumentSnapshot> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();
  List<String> _followingIds = [];
  StreamSubscription<DocumentSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToFollowingChanges();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchPosts();
      }
    });
  }

  void _listenToFollowingChanges() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _followingIds = List<String>.from(data['following'] ?? []);
        });
        _refreshPosts();
      }
    });
  }

  Future<void> _fetchPosts() async {
    if (_isLoading || _followingIds.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final chunks = _followingIds.length <= 10
          ? [_followingIds]
          : [_followingIds.sublist(0, 10)];
      Query query = FirebaseFirestore.instance
          .collectionGroup('communityPosts')
          .where('userId', whereIn: chunks.first)
          .orderBy('clientTimestamp', descending: true)
          .limit(_limit);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      final querySnapshot = await query.get();
      if (querySnapshot.docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        _lastDocument = querySnapshot.docs.last;
        _posts.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchPosts();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_followingIds.isEmpty) {
      return const Center(child: Text("You're not following anyone yet."));
    }
    if (_posts.isEmpty && !_isLoading) {
      return const Center(child: Text("No posts available"));
    }
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final docSnap = _posts[index];
            final data = docSnap.data() as Map<String, dynamic>;
            return PostCard(
              data: data,
              docId: docSnap.id,
              userDocId: data['userId'] ?? '',
            );
          } else {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String userDocId;

  const PostCard({
    Key? key,
    required this.data,
    required this.docId,
    required this.userDocId,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  int likeCount = 0;
  String caption = '';
  String postImage = '';
  String dateString = '';
  List<dynamic> likesArray = [];
  int commentsCount = 0;

  @override
  void initState() {
    super.initState();
    caption = widget.data['caption'] ?? '';
    postImage = widget.data['postImage'] ?? '';
    final clientTimestamp = widget.data['clientTimestamp'];
    if (clientTimestamp is Timestamp) {
      final dt = clientTimestamp.toDate();
      dateString = "${dt.day}/${dt.month}/${dt.year}";
    }
    likesArray = widget.data['likes'] ?? [];
    isLiked = likesArray.contains(FirebaseAuth.instance.currentUser?.uid);
    likeCount = likesArray.length;
    commentsCount = widget.data['commentCount'] ?? 0;
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final postRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userDocId)
        .collection('communityPosts')
        .doc(widget.docId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final currentLikes = List.from(data['likes'] ?? []);
      if (currentLikes.contains(uid)) {
        currentLikes.remove(uid);
      } else {
        currentLikes.add(uid);
      }
      transaction.update(postRef, {'likes': currentLikes});
      likeCount = currentLikes.length;
      isLiked = currentLikes.contains(uid);
    });

    setState(() {});
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsPage(
          postId: widget.docId,
          ownerUserId: widget.userDocId,
        ),
      ),
    );
  }

  void _openFullImage() {
    if (postImage.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullImagePage(imageUrl: postImage),
        ),
      );
    }
  }

  Future<bool> _isFollowing(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    if (currentUserDoc.exists) {
      final data = currentUserDoc.data() as Map<String, dynamic>;
      List<dynamic> following = data['following'] ?? [];
      return following.contains(userId);
    }
    return false;
  }

  Future<void> _followUser() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUserId);
      final targetUserRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userDocId);
      batch.update(currentUserRef, {
        'following': FieldValue.arrayUnion([widget.userDocId])
      });
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([currentUserId])
      });
      await batch.commit();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to follow user: $e")));
    }
  }

  Widget _iconButton(IconData icon, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      color: secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: UserAvatar(userId: widget.userDocId),
            title: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userDocId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final fullName =
                      "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                          .trim();
                  return Text(
                    fullName.isNotEmpty ? fullName : 'Anonymous',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  );
                }
                return const Text('Loading...',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black));
              },
            ),
            subtitle: Text(dateString,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<bool>(
                  future: _isFollowing(widget.userDocId),
                  builder: (context, snapshot) {
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == widget.userDocId) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    bool following = snapshot.data ?? false;
                    return following
                        ? const Text("Following",
                            style: TextStyle(color: Colors.green))
                        : TextButton(
                            onPressed: _followUser,
                            child: const Text("Follow",
                                style: TextStyle(color: primaryColor)),
                          );
                  },
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, color: Colors.black),
                ),
              ],
            ),
          ),
          if (postImage.isNotEmpty)
            GestureDetector(
              onTap: _openFullImage,
              child: Image.network(
                postImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              caption,
              style: const TextStyle(fontSize: 14, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconButton(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    likeCount, _toggleLike),
                _iconButton(
                    Icons.comment_outlined, commentsCount, _openComments),
                _iconButton(Icons.share_outlined, 0, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserAvatar extends StatefulWidget {
  final String userId;
  const UserAvatar({Key? key, required this.userId}) : super(key: key);
  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<String> _fetchProfileImage(String userId) async {
    if (UserCache.profileImageCache.containsKey(userId)) {
      return UserCache.profileImageCache[userId]!;
    }
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    final imageUrl = data?['profileImage'] ?? 'assets/images/profile.jpg';
    UserCache.profileImageCache[userId] = imageUrl;
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchProfileImage(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final profileImage = snapshot.data!;
          return CircleAvatar(
            radius: 20,
            backgroundImage: profileImage.startsWith('http')
                ? NetworkImage(profileImage)
                : AssetImage(profileImage) as ImageProvider,
          );
        }
        return const CircleAvatar(
          radius: 20,
          child: Icon(Icons.person),
        );
      },
    );
  }
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: _selectedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return Image.memory(snapshot.data!, height: 200, fit: BoxFit.cover);
          }
          return const SizedBox.shrink();
        },
      );
    } else {
      return Image.file(File(_selectedImage!.path),
          height: 200, fit: BoxFit.cover);
    }
  }

  Future<void> _submitPost() async {
    if (_captionController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a caption or an image")),
      );
      return;
    }
    setState(() => _isUploading = true);
    String imageUrl = "";
    if (_selectedImage != null) {
      try {
        imageUrl = await _uploadToCloudinary(_selectedImage!);
      } catch (e) {
        debugPrint("Image upload error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image upload failed: $e")),
        );
      }
    }
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('communityPosts')
          .add({
        'userId': user.uid,
        'caption': _captionController.text.trim(),
        'postImage': imageUrl,
        'likes': [],
        'commentCount': 0,
        'shares': 0,
        'clientTimestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post created successfully")),
      );
      Navigator.pop(context);
    }
    setState(() => _isUploading = false);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Post"),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: "Caption",
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            _buildImagePreview(),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image"),
                ),
                const SizedBox(width: 16),
                _isUploading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _submitPost,
                        icon: const Icon(Icons.send),
                        label: const Text("Post"),
                      ),
              ],
            ),
          ],
        ),
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
      appBar: AppBar(backgroundColor: primaryColor),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }
}

class CommentsPage extends StatefulWidget {
  final String postId;
  final String ownerUserId;

  const CommentsPage({
    Key? key,
    required this.postId,
    required this.ownerUserId,
  }) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  CollectionReference get _commentsRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.ownerUserId)
      .collection('communityPosts')
      .doc(widget.postId)
      .collection('comments');

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await _commentsRef.add({
      'userId': user.uid,
      'commentText': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    final postRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.ownerUserId)
        .collection('communityPosts')
        .doc(widget.postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(postRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final currentCount = data['commentCount'] ?? 0;
      transaction.update(postRef, {'commentCount': currentCount + 1});
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Comments"), backgroundColor: primaryColor),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _commentsRef
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No comments yet."));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final commentData =
                        docs[index].data() as Map<String, dynamic>;
                    final commentText = commentData['commentText'] ?? '';
                    return ListTile(
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(commentData['userId'])
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            final fullName =
                                "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                                    .trim();
                            return Text(
                              fullName.isNotEmpty ? fullName : 'Anonymous',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            );
                          }
                          return const Text('Loading...',
                              style: TextStyle(fontWeight: FontWeight.bold));
                        },
                      ),
                      subtitle: Text(commentText),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: "Write a comment...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
