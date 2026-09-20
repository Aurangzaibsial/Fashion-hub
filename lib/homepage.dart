import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> recommendations = [];

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) throw Exception("No user logged in");
      
      final position = await _getLocation();
      final weather = await _getWeather(position.latitude, position.longitude);

      final response = await http.get(Uri.parse(
        'http://127.0.0.1:8000/weather-recommendation?userId=$userId&weather=$weather',
      )).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recs = (data['recommended_outfit'] as Map<String, dynamic>?)
            ?.entries
            .where((e) => e.value['imageUrl'] != null && e.value['imageUrl'] != "")
            .map((e) => {
                  "title": e.value['title'] ?? 'Outfit',
                  "image": e.value['imageUrl'],
                  "description": "Suggested for $weather weather",
                })
            .toList() ?? [];

        if (recs.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            recommendations = recs;
          });
          return;
        }
      }
      throw Exception("Server failed or returned empty");
    } catch (e) {
      print("❌ Recommendation fetch error: $e, using fallback data");
      if (!mounted) return;
      setState(() {
        // Fallback data so the UI always looks good and carousel runs
        recommendations = [
          {
            "title": "Casual Denim Style",
            "image": "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=500&q=80",
            "description": "Perfect for a clear day out"
          },
          {
            "title": "Chic Evening Wear",
            "image": "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=500&q=80",
            "description": "Elegant choice for tonight"
          },
          {
            "title": "Urban Streetwear",
            "image": "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=500&q=80",
            "description": "Comfortable and trendy"
          }
        ];
      });
    }
  }


  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services disabled");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied");
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position? pos = await Geolocator.getLastKnownPosition();
    return pos ??
        await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 2),
        );
  }

  Future<String> _getWeather(double lat, double lon) async {
    const apiKey = "14b585681dce3dfb33835";
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return 'Clear';

      final data = json.decode(response.body);
      final condition = data['weather'][0]['main'];
      return condition.toString();
    } catch (_) {
      return 'Clear';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
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
        centerTitle: true,
        title: _isSearching
            ? _buildSearchField()
            : Text(
                'Fabric Fusion',
                style: GoogleFonts.lemon(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isSearching = true),
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildCarouselSlider(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Outfit Suggestions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildRecommendationSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C3DE8), Color(0xFFE040AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                'Fabric Fusion',
                style: GoogleFonts.lemon(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Color(0xFF6C3DE8)),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSlider() {
    final items = recommendations.isEmpty
        ? [
            Container(
              color: Colors.grey,
              child: const Center(
                child: Text("No outfits yet",
                    style: TextStyle(color: Colors.white)),
              ),
            )
          ]
        : recommendations.map((outfit) {
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FullImagePage(imageUrl: outfit['image'] ?? ''),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: outfit['image'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            );
          }).toList();

    return CarouselSlider(
      items: items,
      options: CarouselOptions(
        height: 250,
        autoPlay: true,
        enlargeCenterPage: true,
      ),
    );
  }

  Widget _buildRecommendationSection() {
    return recommendations.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recommendations.map((outfit) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: outfit['image'] ?? '',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      outfit['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1A2E)),
                    ),
                    subtitle: _buildTruncatedDescription(
                        outfit['description'] ?? '', outfit),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OutfitDetailPage(outfit: outfit),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          );
  }

  Widget _buildTruncatedDescription(
      String description, Map<String, dynamic> outfit) {
    const int maxLength = 100;
    if (description.length <= maxLength) return Text(description);
    final truncated = description.substring(0, maxLength) + '...';
    return Text.rich(
      TextSpan(
        text: truncated,
        children: [
          TextSpan(
            text: ' Read more',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OutfitDetailPage(outfit: outfit),
                  ),
                );
              },
          )
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Search...",
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final String imageUrl;
  const FullImagePage({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}

class OutfitDetailPage extends StatelessWidget {
  final Map<String, dynamic> outfit;
  const OutfitDetailPage({super.key, required this.outfit});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
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
        title: Text(outfit['title'] ?? 'Outfit Details',
            style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: outfit['image'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
            const SizedBox(height: 16),
            Text(
              outfit['title'] ?? 'No Title',
              style:
                  GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              outfit['description'] ?? 'No Description',
              style: GoogleFonts.lato(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
