import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http_parser/http_parser.dart';

class MyWardrobe extends StatefulWidget {
  const MyWardrobe({Key? key}) : super(key: key);

  @override
@override
_MyWardrobeState createState() => _MyWardrobeState();}

class _MyWardrobeState extends State<MyWardrobe>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _wardrobeCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)
      .collection('wardrobe');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(String docId) async {
    await _wardrobeCollection.doc(docId).delete();
  }

  Future<String?> uploadImageToCloudinary({
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    if (imageFile == null && imageBytes == null) return null;
    final url =
        Uri.parse("https://api.cloudinary.com/v1_1/dxwp10qod/image/upload");
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'imageupload';

    if (kIsWeb && imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes,
          filename: 'image.png'));
    } else if (imageFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = json.decode(body);
      if (response.statusCode == 200) {
        return data['secure_url'] as String;
      }
    } catch (e) {
      debugPrint("Cloudinary upload error: $e");
    }
    return null;
  }

  void _showAddItemDialog(BuildContext context) {
    String? selectedCategory;
    String? selectedOccasion;
    final nameController = TextEditingController();
    File? selectedImageFile;
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: ['Tops', 'Bottoms', 'Dresses', 'Shoes', 'Accessories']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (c) => setStateDialog(() => selectedCategory = c),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select a Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: 'Item Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedOccasion,
                  items: [
                    'All',
                    'Weddings',
                    'Casual',
                    'Work',
                    'Daily Wear',
                    'Parties'
                  ]
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (o) => setStateDialog(() => selectedOccasion = o),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select an Occasion'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      if (kIsWeb) {
                        selectedImageBytes = await picked.readAsBytes();
                      } else {
                        selectedImageFile = File(picked.path);
                      }
                      setStateDialog(() {});
                    }
                  },
                  child: const Text('Select Image'),
                ),
                if (selectedImageBytes != null)
                  Image.memory(selectedImageBytes!,
                      height: 100, fit: BoxFit.cover)
                else if (selectedImageFile != null)
                  Image.file(selectedImageFile!,
                      height: 100, fit: BoxFit.cover),
                if (isUploading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategory != null &&
                    nameController.text.isNotEmpty &&
                    (selectedImageFile != null || selectedImageBytes != null)) {
                  setStateDialog(() => isUploading = true);

                  final imageUrl = await uploadImageToCloudinary(
                    imageFile: selectedImageFile,
                    imageBytes: selectedImageBytes,
                  );

                  if (imageUrl != null) {
                    await _wardrobeCollection.add({
                      'name': nameController.text,
                      'imageUrl': imageUrl,
                      'category': selectedCategory,
                      'occasion': selectedOccasion,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // ⬇️ Immediately create embeddings
                    final embedUri =
                        Uri.parse("http://127.0.0.1:8000/embed-item");
                    await http.post(
                      embedUri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'userId': _userId,
                        'imageUrl': imageUrl,
                        'title': nameController.text,
                        'category': selectedCategory,
                        'occasion': selectedOccasion ?? 'All',
                      }),
                    );

                    Navigator.pop(context);
                  }

                  setStateDialog(() => isUploading = false);
                }
              },
              child: const Text('Add Item',
                  style: TextStyle(color: Color.fromARGB(255, 8, 4, 7))),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditItemDialog(String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    String? selectedCategory = data['category'];
    String? selectedOccasion = data['occasion'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: ['Tops', 'Bottoms', 'Dresses', 'Shoes', 'Accessories']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (c) => setStateDialog(() => selectedCategory = c),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select a Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: 'Item Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedOccasion,
                  items: [
                    'All',
                    'Weddings',
                    'Casual',
                    'Work',
                    'Daily Wear',
                    'Parties'
                  ]
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (o) => setStateDialog(() => selectedOccasion = o),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select an Occasion'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _wardrobeCollection.doc(docId).update({
                  'name': nameController.text,
                  'category': selectedCategory,
                  'occasion': selectedOccasion,
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> data, String docId) {
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              _buildItemImage(data['imageUrl'] as String),
              _buildItemOverlay(data['name'] as String, data['occasion']),
              Positioned(
                top: 8,
                right: 8,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditItemDialog(docId, data);
                    } else if (value == 'delete') {
                      _deleteItem(docId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(color: Colors.grey.shade300),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

  Widget _buildItemOverlay(String name, String? occasion) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (occasion != null)
              Text(occasion,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserHeaderData(),
      builder: (context, snapshot) {
        String profileImage = '';
        int wardrobeCount = 0;
        int designedCount = 0;
        if (snapshot.hasData) {
          profileImage = snapshot.data!['profileImage'] as String;
          wardrobeCount = snapshot.data!['wardrobeCount'] as int;
          designedCount = snapshot.data!['designedCount'] as int;
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9EA5FF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              const Text("My Wardrobe",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              const Text("Easily manage and organize your outfits",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: profileImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: profileImage,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : const CircleAvatar(
                                radius: 40,
                                child: Icon(Icons.person, size: 40)),
                      ),
                      const SizedBox(height: 8),
                      _buildRatingStars(),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoText("Collection", wardrobeCount.toString()),
                        _buildInfoText("Designed", designedCount.toString()),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showAddItemDialog(context),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white),
                                child: const Text(
                                  "Add to Collection",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showRecommendationDialog(context),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white),
                                child: const Text("Suggest Outfit"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoText(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$title: $value",
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87)),
    );
  }

  Widget _buildRatingStars() {
    return const Row(
      children: [
        Icon(Icons.star, color: Colors.amber, size: 20),
        Icon(Icons.star, color: Colors.amber, size: 20),
        Icon(Icons.star, color: Colors.amber, size: 20),
        Icon(Icons.star, color: Colors.amber, size: 20),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search Wardrobe',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.2),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.black,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Tops'),
          Tab(text: 'Bottoms'),
          Tab(text: 'Dresses'),
          Tab(text: 'Shoes'),
          Tab(text: 'Accessories'),
        ],
      ),
    );
  }

  Widget _buildGridView(String gridCategory) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getWardrobeStream(gridCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No items available"));
        }
        final docs = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildItemCard(data, docs[index].id);
            },
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getWardrobeStream(String category) {
    final query = _wardrobeCollection;

    print("🔍 Querying category: $category");

    return category == 'All'
        ? query.orderBy('timestamp', descending: true).snapshots()
        : query.where('category', isEqualTo: category).snapshots();
  }

  void _showRecommendationDialog(BuildContext context) {
    bool loading = false;
    Map<String, dynamic>? outfit;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Smart Outfit Suggestion"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text("Select Outfit Image"),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setStateDialog(() => loading = true);
                    final result = await _getSmartRecommendations(picked);
                    setStateDialog(() {
                      outfit = result;
                      loading = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              if (loading) const CircularProgressIndicator(),
              if (outfit != null)
                ...outfit!.entries.map((entry) {
                  final cat = entry.key;
                  final item = entry.value;
                  return item['imageUrl'] == ""
                      ? Text("❌ Not enough ${cat.toLowerCase()} to recommend")
                      : ListTile(
                          leading: Image.network(item['imageUrl'],
                              width: 50, fit: BoxFit.cover),
                          title: Text(item['title']),
                          subtitle: Text(cat),
                        );
                }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getSmartRecommendations(
      XFile pickedFile) async {
    try {
      final uri = Uri.parse(
          "http://127.0.0.1:8000/recommend-outfit?userId=$_userId");
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: pickedFile.name,
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          pickedFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body) as Map<String, dynamic>;
        return data['recommended_outfit'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("AI API Exception: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> _getUserHeaderData() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(_userId).get();
    final wardrobeCount =
        await _wardrobeCollection.get().then((snap) => snap.size);
    final designedCount = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('posts')
        .get()
        .then((snap) => snap.size);

    return {
      'profileImage': userDoc.data()?['profileImage'] ?? '',
      'wardrobeCount': wardrobeCount,
      'designedCount': designedCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7D86FF),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildSearchBar(),
              _buildTabs(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.68,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGridView('All'),
                    _buildGridView('Tops'),
                    _buildGridView('Bottoms'),
                    _buildGridView('Dresses'),
                    _buildGridView('Shoes'),
                    _buildGridView('Accessories'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
