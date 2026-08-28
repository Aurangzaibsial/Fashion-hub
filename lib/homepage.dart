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
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final position = await _getLocation();
    final weather = await _getWeather(position.latitude, position.longitude);

    final response = await http.get(Uri.parse(
      'http://127.0.0.1:8000/weather-recommendation?userId=$userId&weather=$weather',
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final recs = (data['recommended_outfit'] as Map<String, dynamic>)
          .entries
          .where((e) => e.value['imageUrl'] != "")
          .map((e) => {
                "title": e.value['title'],
                "image": e.value['imageUrl'],
                "description": "Suggested for $weather weather",
              })
          .toList();

      if (!mounted) return;   // <-- FIX HERE
í
      setState(() {
        recommendations = recs;
      });
    } else {
      print("❌ Server responded with ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Recommendation fetch error: $e");
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

    return await Geolocator.getCurrentPosition();
  }

  Future<String> _getWeather(double lat, double lon) async {
    const apiKey = "14b585681dce3dfb33835";
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return 'Clear';

    final data = json.decode(response.body);
    final condition = data['weather'][0]['main'];
    return condition.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      backgroundColor: const Color.fromARGB(255, 125, 134, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(226, 94, 110, 255),
        centerTitle: true,
        title: _isSearching
            ? _buildSearchField()
            : Text(
                'fabric fusion',
                style: GoogleFonts.lemon(
                  fontSize: 24,
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
          children: [
            _buildCarouselSlider(),
            const SizedBox(height: 30),
            _buildRecommendationSection(),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration:
                const BoxDecoration(color: Color.fromARGB(226, 94, 110, 255)),
            child: Center(
              child: Text(
                'FitFuse',
                style: GoogleFonts.lemon(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
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
        : Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recommendations.map((outfit) {
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: outfit['image'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(outfit['title'] ?? 'Untitled'),
                  subtitle: _buildTruncatedDescription(
                      outfit['description'] ?? '', outfit),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OutfitDetailPage(outfit: outfit),
                      ),
                    );
                  },
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
      backgroundColor: const Color.fromARGB(255, 125, 134, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 113, 121, 231),
        title: Text(outfit['title'] ?? 'Outfit Details'),
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
