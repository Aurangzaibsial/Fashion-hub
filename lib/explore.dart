import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String _selectedFilter = "Design";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _trendingPostsStream;

  @override
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _updateTrendingPostsStream();
  }

  void _updateTrendingPostsStream() {
    _trendingPostsStream = _firestore
        .collection('trendingPosts')
        .where('filter', isEqualTo: _selectedFilter)
        .orderBy('votes', descending: true)
        .snapshots();
  }

  // Debounce the search input to reduce rebuilds.
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {}); // Trigger filtering after user stops typing.
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _updateTrendingPostsStream();
    });
  }

  void _navigateToAddPost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTrendingPostPage()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Fashion Trends", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C3DE8), Color(0xFFE040AB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPost,
        backgroundColor: const Color(0xFF6C3DE8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Discover",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Stay stylish with the latest trends",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Search bar with debounced input.
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search Designs',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6C3DE8)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear, color: Colors.grey),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Filter options.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: ["Design", "Events", "Weather"].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF6C3DE8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _changeFilter(filter),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFF6C3DE8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : const Color(0xFF6C3DE8),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Influencer's Choice",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: _trendingPostsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint("Firestore query error: ${snapshot.error}");
                    return const Center(
                        child: Text("An error occurred. Please try again."));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  // Client-side filtering based on the search query.
                  final filteredDocs = _searchController.text.isEmpty
                      ? docs
                      : docs.where((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final designName = (data['designName'] ?? '')
                              .toString()
                              .toLowerCase();
                          return designName
                              .contains(_searchController.text.toLowerCase());
                        }).toList();
                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text("No posts found"));
                  }
                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      return TrendingPostRow(postDoc: filteredDocs[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrendingPostRow extends StatefulWidget {
  final DocumentSnapshot postDoc;
  const TrendingPostRow({Key? key, required this.postDoc}) : super(key: key);

  @override
  State<TrendingPostRow> createState() => _TrendingPostRowState();
}

class _TrendingPostRowState extends State<TrendingPostRow> {
  late Map<String, dynamic> postData;
  late List<dynamic> votesList;
  late int voteCount;
  late bool isVoted;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    postData = widget.postDoc.data() as Map<String, dynamic>;
    votesList = postData['votes'] is List ? postData['votes'] as List : [];
    voteCount = votesList.length;
    final currentUser = _auth.currentUser;
    isVoted = currentUser != null ? votesList.contains(currentUser.uid) : false;
  }

  Future<void> _toggleVote() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final docRef = widget.postDoc.reference;
    await _firestore.runTransaction((transaction) async {
      final freshSnapshot = await transaction.get(docRef);
      if (!freshSnapshot.exists) return;
      final freshData = freshSnapshot.data() as Map<String, dynamic>;
      List<dynamic> freshVotes =
          freshData['votes'] is List ? List.from(freshData['votes']) : [];
      if (freshVotes.contains(currentUser.uid)) {
        freshVotes.remove(currentUser.uid);
      } else {
        freshVotes.add(currentUser.uid);
      }
      transaction.update(docRef, {'votes': freshVotes});
      setState(() {
        voteCount = freshVotes.length;
        isVoted = freshVotes.contains(currentUser.uid);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String designName = postData['designName'] ?? 'Unnamed Design';
    final String caption = postData['caption'] ?? '';
    final String postImage = postData['postImage'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(postData['userId'] ?? '').get(),
              builder: (context, snapshot) {
                String profileImg = 'assets/images/profile.jpg';
                String userName = 'Anonymous';
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  userName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
                  if (userName.isEmpty) userName = "Anonymous";
                  if (data['profileImage'] != null && (data['profileImage'] as String).startsWith("http")) {
                    profileImg = data['profileImage'];
                  }
                }
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: profileImg.startsWith("http")
                          ? CachedNetworkImageProvider(profileImg)
                          : AssetImage(profileImg) as ImageProvider,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E)),
                    ),
                  ],
                );
              },
            ),
          ),
          // Large Image
          if (postImage.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FullImagePage(imageUrl: postImage)));
              },
              child: ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: postImage,
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width * 0.8,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: MediaQuery.of(context).size.width * 0.8,
                    color: Colors.grey.shade100,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          // Post Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  designName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 6),
                ExpandableText(text: caption, trimLength: 80),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleVote,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isVoted ? const Color(0xFF6C3DE8).withOpacity(0.1) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isVoted ? Icons.favorite : Icons.favorite_border,
                                  color: isVoted ? const Color(0xFFE040AB) : Colors.grey.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$voteCount",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isVoted ? const Color(0xFFE040AB) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// UserInfoCard removed as it's now inline

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLength;
  const ExpandableText({Key? key, required this.text, this.trimLength = 50})
      : super(key: key);
  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    if (widget.text.length <= widget.trimLength) {
      return Text(widget.text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isExpanded
              ? widget.text
              : widget.text.substring(0, widget.trimLength) + '...',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Text(
            _isExpanded ? 'Read less' : 'Read more',
            style: const TextStyle(color: Colors.blue, fontSize: 12),
          ),
        )
      ],
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
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}

class CreateTrendingPostPage extends StatefulWidget {
  const CreateTrendingPostPage({Key? key}) : super(key: key);
  @override
  State<CreateTrendingPostPage> createState() => _CreateTrendingPostPageState();
}

class _CreateTrendingPostPageState extends State<CreateTrendingPostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _designNameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _selectedFilter = "Design";
  XFile? _selectedImage;
  bool _isUploading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return const Text("No image selected");
    }
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: _selectedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return Image.memory(snapshot.data!, height: 200, fit: BoxFit.cover);
          }
          return const CircularProgressIndicator();
        },
      );
    } else {
      return Image.file(File(_selectedImage!.path),
          height: 200, fit: BoxFit.cover);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
      });
    }
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

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate() && _selectedImage != null) {
      setState(() => _isUploading = true);
      try {
        final imageUrl = await _uploadToCloudinary(_selectedImage!);
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _firestore.collection('trendingPosts').add({
            'userId': currentUser.uid,
            'designName': _designNameController.text.trim(),
            'caption': _captionController.text.trim(),
            'postImage': imageUrl,
            'votes': [],
            'filter': _selectedFilter,
            'timestamp': FieldValue.serverTimestamp(),
          });
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Error creating post: $e");
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _designNameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Trending Post"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _designNameController,
                decoration: const InputDecoration(
                  labelText: "Design Name (Unique)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Design Name is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: "Caption",
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Caption is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFilter,
                items: const [
                  DropdownMenuItem(value: "Design", child: Text("Design")),
                  DropdownMenuItem(value: "Weather", child: Text("Weather")),
                  DropdownMenuItem(value: "Events", child: Text("Events")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Filter",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePreview(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Select Image"),
              ),
              const SizedBox(height: 16),
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _submitPost,
                      icon: const Icon(Icons.send),
                      label: const Text("Post"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
