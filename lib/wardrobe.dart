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
import 'package:geolocator/geolocator.dart';
import 'package:fitfuseapp/image_guard.dart';

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
    final doc = await _wardrobeCollection.doc(docId).get();
    final data = doc.data() as Map<String, dynamic>?;
    final imageUrl = data?['imageUrl'];
    await _wardrobeCollection.doc(docId).delete();

    if (imageUrl != null) {
      final embs = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('embeddings')
          .where('imageUrl', isEqualTo: imageUrl)
          .get();
      for (final e in embs.docs) {
        await e.reference.delete();
      }
    }
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

                  // 1. AI Safety & Wardrobe Validation Check
                  final valResult = await _validateImageWithAI(
                    imageFile: selectedImageFile,
                    imageBytes: selectedImageBytes,
                    action: "wardrobe_add_${selectedCategory?.toLowerCase() ?? 'item'}",
                  );

                  if (!valResult.allowed) {
                    setStateDialog(() => isUploading = false);
                    showImageRejection(context, valResult);
                    return;
                  }

                  // 1b. Warn if the photo looks like another category (user can keep their choice)
                  final addCategory = await _confirmCategory(
                    chosen: selectedCategory!,
                    bytes: selectedImageBytes ?? await selectedImageFile?.readAsBytes(),
                  );
                  if (addCategory == null) {
                    setStateDialog(() => isUploading = false);
                    return;
                  }
                  selectedCategory = addCategory;

                  // 2. Upload to Cloudinary
                  final imageUrl = await uploadImageToCloudinary(
                    imageFile: selectedImageFile,
                    imageBytes: selectedImageBytes,
                  );

                  if (imageUrl != null) {
                    final newItem = await _wardrobeCollection.add({
                      'name': nameController.text,
                      'imageUrl': imageUrl,
                      'category': selectedCategory,
                      'occasion': selectedOccasion,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // ⬇️ Immediately create embeddings
                    final embedUri = Uri.parse("$kRecommenderUrl/embed-item");
                    final embedResp = await http.post(
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

                    // The backend re-checks the saved image; undo the item if it rejects it
                    if (embedResp.statusCode == 400) {
                      await newItem.delete();
                      setStateDialog(() => isUploading = false);
                      dynamic detail;
                      try {
                        detail = jsonDecode(embedResp.body)['detail'];
                      } catch (_) {}
                      _showSecurityAlertModal(context, detail);
                      return;
                    }

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
    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    String? selectedCategory = data['category']?.toString();
    String? selectedOccasion = data['occasion']?.toString();

    File? newImageFile;
    Uint8List? newImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: ['Tops', 'Bottoms', 'Dresses', 'Shoes', 'Accessories'].contains(selectedCategory)
                      ? selectedCategory
                      : null,
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
                  value: ['All', 'Weddings', 'Casual', 'Work', 'Daily Wear', 'Parties'].contains(selectedOccasion)
                      ? selectedOccasion
                      : null,
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
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3DE8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(
                    (newImageBytes != null || newImageFile != null)
                        ? 'Image Selected (Change Again)'
                        : 'Replace Image',
                  ),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      if (kIsWeb) {
                        newImageBytes = await picked.readAsBytes();
                      } else {
                        newImageFile = File(picked.path);
                      }
                      setStateDialog(() {});
                    }
                  },
                ),
                if (newImageBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(newImageBytes!, height: 100, fit: BoxFit.cover),
                  ),
                ] else if (newImageFile != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(newImageFile!, height: 100, fit: BoxFit.cover),
                  ),
                ],
                if (isUploading) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3DE8),
                foregroundColor: Colors.white,
              ),
              onPressed: isUploading
                  ? null
                  : () async {
                      setStateDialog(() => isUploading = true);

                      String? finalImageUrl = data['imageUrl'];

                      final hasNewImage = newImageFile != null || newImageBytes != null;

                      if (hasNewImage) {
                        // AI Safety Validation
                        final valResult = await _validateImageWithAI(
                          imageFile: newImageFile,
                          imageBytes: newImageBytes,
                          action: "wardrobe_edit_${selectedCategory?.toLowerCase() ?? 'item'}",
                        );

                        if (!valResult.allowed) {
                          setStateDialog(() => isUploading = false);
                          showImageRejection(context, valResult);
                          return;
                        }
                      }

                      // Warn if the photo (new or saved) looks like another category.
                      // Runs when the photo OR the category changed (user can keep their choice).
                      if (selectedCategory != null &&
                          (hasNewImage || selectedCategory != data['category'])) {
                        final editCategory = await _confirmCategory(
                          chosen: selectedCategory!,
                          bytes: newImageBytes ?? await newImageFile?.readAsBytes(),
                          imageUrl: hasNewImage ? null : data['imageUrl']?.toString(),
                        );
                        if (editCategory == null) {
                          setStateDialog(() => isUploading = false);
                          return;
                        }
                        setStateDialog(() => selectedCategory = editCategory);
                      }

                      if (hasNewImage) {
                        // Upload to Cloudinary
                        final uploadedUrl = await uploadImageToCloudinary(
                          imageFile: newImageFile,
                          imageBytes: newImageBytes,
                        );

                        if (uploadedUrl != null) {
                          finalImageUrl = uploadedUrl;
                        }
                      }

                      await _wardrobeCollection.doc(docId).update({
                        'name': nameController.text.trim(),
                        'category': selectedCategory,
                        'occasion': selectedOccasion,
                        if (finalImageUrl != null) 'imageUrl': finalImageUrl,
                      });

                      // Keep the AI embedding in step with the item (photo, category, occasion or name)
                      final photoChanged = finalImageUrl != data['imageUrl'];
                      final detailsChanged = photoChanged ||
                          selectedCategory != data['category'] ||
                          selectedOccasion != data['occasion'] ||
                          nameController.text.trim() != data['name'];
                      if (finalImageUrl != null && detailsChanged) {
                        try {
                          final embedUri = Uri.parse("$kRecommenderUrl/embed-item");
                          await http.post(
                            embedUri,
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'userId': _userId,
                              'imageUrl': finalImageUrl,
                              'title': nameController.text.trim(),
                              'category': selectedCategory,
                              'occasion': selectedOccasion ?? 'All',
                              if (photoChanged) 'oldImageUrl': data['imageUrl']?.toString() ?? '',
                            }),
                          );
                        } catch (_) {}
                      }

                      setStateDialog(() => isUploading = false);
                      Navigator.pop(dialogCtx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              const Text("My Wardrobe",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text("Easily manage and organize your outfits",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showAddItemDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C3DE8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Add Item",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showRecommendationDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE040AB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text("Suggest Outfit",
                                    style: TextStyle(fontSize: 12)),
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
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C3DE8), Color(0xFFE040AB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
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

  Future<String> _getLiveWeatherCondition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return 'Clear';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return 'Clear';
      }
      if (permission == LocationPermission.deniedForever) return 'Clear';

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 2),
      );

      const apiKey = "14b585681dce3dfb33835";
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['weather'][0]['main'].toString();
      }
    } catch (e) {
      debugPrint("Weather fetch fast-fallback: $e");
    }
    return 'Clear';
  }

  void _showRecommendationDialog(BuildContext context) {
    bool loading = false;
    Map<String, dynamic>? outfit;
    String selectedWeather = 'Sunny';
    bool fetchedWeather = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (!fetchedWeather) {
            fetchedWeather = true;
            _getLiveWeatherCondition().then((liveWeather) {
              setStateDialog(() {
                selectedWeather = liveWeather;
              });
            });
          }

          final weatherOptions = [
            'Sunny',
            'Summer',
            'Rainy',
            'Cold',
            'Winter',
            'Clouds',
            'Haze',
            'Casual',
          ];
          if (!weatherOptions.contains(selectedWeather)) {
            weatherOptions.insert(0, selectedWeather);
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color.fromARGB(255, 198, 82, 136)),
                SizedBox(width: 8),
                Text("Smart Outfit Suggestion", style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Weather / Occasion Context:",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedWeather,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.wb_sunny_outlined, size: 20),
                    ),
                    items: weatherOptions
                        .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => selectedWeather = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text("Select Outfit Image"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setStateDialog(() {
                            loading = true;
                            outfit = null;
                          });
                          final result = await _getSmartRecommendations(
                            picked,
                            selectedWeather,
                          );
                          if (!context.mounted) return;
                          setStateDialog(() {
                            loading = false;
                            outfit = result != null && result['status'] == 'success'
                                ? result['recommended_outfit'] as Map<String, dynamic>
                                : null;
                          });
                          if (result != null && result['status'] == 'unauthorized') {
                            _showSecurityAlertModal(context, result['detail']);
                          } else if (result == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to get recommendation. Please try again.")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (outfit != null) ...[
                    const Divider(),
                    ...outfit!.entries.map((entry) {
                      final cat = entry.key;
                      final item = entry.value;
                      return item['imageUrl'] == ""
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text("❌ Not enough ${cat.toLowerCase()} to recommend",
                                  style: const TextStyle(color: Colors.redAccent)),
                            )
                          : ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['imageUrl'],
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                              title: Text(item['title'] ?? 'Untitled',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text("$cat • $selectedWeather",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSecurityAlertModal(BuildContext ctx, dynamic detail) =>
      showSecurityAlert(ctx, detail);

  /// Warns when the photo looks like a different category than the one picked.
  /// Returns the category to save, or null if the user dismisses the warning.
  /// Never blocks: the user can always keep their own choice.
  Future<String?> _confirmCategory({
    required String chosen,
    Uint8List? bytes,
    String? imageUrl,
  }) async {
    final check = await checkCategory(category: chosen, bytes: bytes, imageUrl: imageUrl);
    if (!check.isMismatch || !mounted) return chosen;
    return showCategoryMismatchDialog(context, chosen: chosen, predicted: check.predicted!);
  }

  /// Checks an image with the backend. Fails closed: if the backend can't be
  /// reached the result is "unverified" and the image must not be accepted.
  Future<ImageCheck> _validateImageWithAI({
    File? imageFile,
    Uint8List? imageBytes,
    String action = "wardrobe_upload",
  }) async {
    final bytes = imageBytes ?? await imageFile?.readAsBytes();
    if (bytes == null) return const ImageCheck.unverified();
    return checkImage(bytes: bytes, userId: _userId, action: action);
  }

  Future<Map<String, dynamic>?> _getSmartRecommendations(
      XFile pickedFile, String weather) async {
    try {
      final uri = Uri.parse(
          "$kRecommenderUrl/recommend-outfit?userId=$_userId&weather=${Uri.encodeComponent(weather)}");
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
      final body = await response.stream.bytesToString();
      final data = json.decode(body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'status': 'success',
          'recommended_outfit': data['recommended_outfit'] as Map<String, dynamic>,
        };
      } else if (response.statusCode == 400 && data['detail'] != null) {
        return {
          'status': 'unauthorized',
          'detail': data['detail'],
        };
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
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        title: const Text(
          'My Wardrobe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildSearchBar(),
              const SizedBox(height: 6),
              _buildTabs(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.60,
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
