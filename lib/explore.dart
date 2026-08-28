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
      appBar: AppBar(
        title: const Text("Fashion Trends"),
        backgroundColor: const Color.fromARGB(255, 84, 255, 68),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPost,
        child: const Icon(Icons.add),
      ),
      backgroundColor: const Color.fromARGB(255, 125, 134, 255),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const Center(
                child: Text(
                  "Fashion Trends",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Center(
                child: Text(
                  "Stay stylish with the latest trends",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(255, 26, 26, 26),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 15),
              // Search bar with debounced input.
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search Designs',
                    prefixIcon: const Icon(Icons.search, color: Colors.black),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear, color: Colors.black),
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Filter options.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      InkWell(
                        onTap: () => _changeFilter("Events"),
                        child: Image.asset(
                          'assets/images/event.png',
                          width: 65,
                          height: 65,
                        ),
                      ),
                      const Text(
                        "Events",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      InkWell(
                        onTap: () => _changeFilter("Weather"),
                        child: Image.asset(
                          'assets/images/sun.png',
                          width: 65,
                          height: 65,
                        ),
                      ),
                      const Text(
                        "Weather",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      InkWell(
                        onTap: () => _changeFilter("Design"),
                        child: Image.asset(
                          'assets/images/hanger.png',
                          width: 65,
                          height: 65,
                        ),
                      ),
                      const Text(
                        "Design",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                "Influencer's Choice",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserInfoCard(userId: postData['userId'] ?? ''),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          designName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 15),
                          width: MediaQuery.of(context).size.width * 0.35,
                          child: ExpandableText(text: caption, trimLength: 50),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _toggleVote,
                              icon: Icon(
                                isVoted
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "$voteCount Votes",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  FullImagePage(imageUrl: postImage)),
                        );
                      },
                      // Use CachedNetworkImage for consistent caching and error handling.
                      child: CachedNetworkImage(
                        imageUrl: postImage,
                        width: MediaQuery.of(context).size.width * 0.20,
                        height: MediaQuery.of(context).size.width * 0.25,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UserInfoCard extends StatefulWidget {
  final String userId;
  const UserInfoCard({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends State<UserInfoCard> {
  late Future<DocumentSnapshot> _userFuture;
  @override
  void initState() {
    super.initState();
    _userFuture =
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        String profileImg = 'assets/images/profile.jpg';
        String userName = 'Anonymous';
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          userName =
              "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
          if (userName.isEmpty) userName = "Anonymous";
          if (data['profileImage'] != null &&
              (data['profileImage'] as String).startsWith("http")) {
            profileImg = data['profileImage'];
          }
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProfileImage(profileImg),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                userName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(String profileImg) {
    if (profileImg.startsWith("http")) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CachedNetworkImage(
          imageUrl: profileImg,
          width: MediaQuery.of(context).size.width * 0.14,
          height: MediaQuery.of(context).size.width * 0.16,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const CircularProgressIndicator(strokeWidth: 2),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          profileImg,
          width: MediaQuery.of(context).size.width * 0.14,
          height: MediaQuery.of(context).size.width * 0.16,
          fit: BoxFit.cover,
        ),
      );
    }
  }
}

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
