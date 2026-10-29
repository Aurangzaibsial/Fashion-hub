import 'package:fitfuseapp/hover_tap.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:fitfuseapp/profilepage.dart';
import 'package:fitfuseapp/wardrobe.dart';
import 'package:fitfuseapp/ai_outfit_matcher.dart';
import 'dart:convert';

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool _isSearching = false;
  final CarouselSliderController _carousel = CarouselSliderController();
  int _page = 0;
  bool _isWide = false;
  String? _weather;
  String? _firstName;
  Timer? _auto;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> recommendations = [];

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
    _loadName();
    _searchController.addListener(() {
      if (mounted) setState(() => _page = 0);
    });
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _isWide && _visible.length > 1) {
        setState(() => _page = (_page + 1) % _visible.length);
      }
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String? name;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final first = (snap.data()?['firstName'] ?? '').toString().trim();
      if (first.isNotEmpty) name = first;
    } catch (_) {}
    if (name == null) {
      final dn = user.displayName?.trim() ?? '';
      if (dn.isNotEmpty) name = dn.split(' ').first;
    }
    if (mounted) setState(() => _firstName = name);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return recommendations;
    return recommendations
        .where((o) =>
            '${o['title'] ?? ''} ${o['description'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) throw Exception("No user logged in");
      
      final position = await _getLocation();
      final weather = await _getWeather(position.latitude, position.longitude);
      if (mounted) setState(() => _weather = weather);

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

  Widget _wordmark({bool light = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: light ? Colors.white : const Color(0xFF121A33),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('N',
                  style: GoogleFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: light ? const Color(0xFF121A33) : Colors.white)),
              Positioned(
                right: 6,
                bottom: 7,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE0A58F), shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'NextGen Cloth Engine',
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: light ? Colors.white : const Color(0xFF0E1220),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    _isWide = wide;
    final list = _visible;
    final n = list.length;
    return Scaffold(
      drawer: wide ? null : _buildDrawer(),
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0E1220),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFE7E4EC)),
              ),
              title: _isSearching ? _buildSearchField() : _wordmark(),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => setState(() => _isSearching = true),
                  icon: const Icon(Icons.search, color: Color(0xFF0E1220)),
                ),
              ],
            ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: wide ? 28 : 20),
                  if (wide) ...[
                    _buildTopBar(),
                    const SizedBox(height: 30),
                  ],
                  Text(
                    _firstName == null
                        ? _greeting()
                        : '${_greeting()}, $_firstName',
                    style: GoogleFonts.sora(
                      fontSize: wide ? 38 : 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.1,
                      color: const Color(0xFF0E1220),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weather == null
                        ? 'Here are your outfit picks for today.'
                        : 'It looks ${_weather!.toLowerCase()} today. Here are your picks.',
                    style: GoogleFonts.manrope(
                        fontSize: 16, color: const Color(0xFF5B6177)),
                  ),
                  const SizedBox(height: 28),
                  _sectionHeader(
                    "Today's picks",
                    count: n,
                    onPrev: wide
                        ? () => setState(() => _page = (_page - 1) % n)
                        : () => _carousel.previousPage(),
                    onNext: wide
                        ? () => setState(() => _page = (_page + 1) % n)
                        : () => _carousel.nextPage(),
                  ),
                  const SizedBox(height: 16),
                  wide ? _buildFeaturedWide() : _buildCarouselSlider(false),
                  const SizedBox(height: 28),
                  HoverTap(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AIOutfitMatcherScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 36 : 18, vertical: wide ? 30 : 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121A33),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF121A33).withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0A58F),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFF0E1220), size: 26),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Can't decide what to wear?",
                                  style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: wide ? 22 : 16,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Compare 3 dresses & let AI pick the best!',
                                  style: GoogleFonts.manrope(
                                      color: const Color(0xFFCBD2E6),
                                      fontSize: wide ? 15 : 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (wide)
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Compare outfits',
                                      style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: const Color(0xFF0E1220))),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 18, color: Color(0xFF0E1220)),
                                ],
                              ),
                            )
                          else
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  _sectionHeader('Outfit suggestions'),
                  const SizedBox(height: 16),
                  _buildRecommendationSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E4EC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Color(0xFF5B6177)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.manrope(
                        fontSize: 15, color: const Color(0xFF0E1220)),
                    decoration: InputDecoration(
                      hintText: 'Search outfits',
                      hintStyle: GoogleFonts.manrope(
                          fontSize: 15, color: const Color(0xFF5B6177)),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  HoverTap(
                    lift: false,
                    onTap: () => _searchController.clear(),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF5B6177)),
                  ),
              ],
            ),
          ),
        ),
        if (_weather != null) ...[
          const SizedBox(width: 14),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E4EC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_sunny_outlined,
                    size: 20, color: Color(0xFFA15A44)),
                const SizedBox(width: 10),
                Text(_weather!,
                    style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0E1220))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyPicks() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E3DD),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: recommendations.isEmpty
            ? const CircularProgressIndicator()
            : Text('No outfits match your search',
                style: GoogleFonts.manrope(
                    color: const Color(0xFF5B6177), fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildFeaturedWide() {
    final list = _visible;
    final n = list.length;
    if (n == 0) return _emptyPicks();
    final p = _page % n;
    final side = <Map<String, dynamic>>[
      if (n > 1) list[(p + 1) % n],
      if (n > 2) list[(p + 2) % n],
    ];
    return SizedBox(
      height: 360,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: KeyedSubtree(
                key: ValueKey('${list[p]['title']}-$p'),
                child: _featuredCard(list[p]),
              ),
            ),
          ),
          if (side.isNotEmpty) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < side.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    Expanded(child: _sideCard(side[i])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featuredCard(Map<String, dynamic> outfit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E4EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TODAY'S PICK",
                      style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: const Color(0xFFA15A44))),
                  const SizedBox(height: 12),
                  Text(
                    outfit['title'] ?? 'Outfit',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.9,
                        color: const Color(0xFF0E1220)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    outfit['description'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.55,
                        color: const Color(0xFF5B6177)),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      HoverTap(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OutfitDetailPage(outfit: outfit),
                          ),
                        ),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF121A33),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('Try this look',
                              style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.white)),
                        ),
                      ),
                      HoverTap(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FullImagePage(imageUrl: outfit['image'] ?? ''),
                          ),
                        ),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFF121A33), width: 1.5),
                          ),
                          child: Text('View photo',
                              style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: const Color(0xFF121A33))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SizedBox.expand(
              child: CachedNetworkImage(
                imageUrl: outfit['image'] ?? '',
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: const Color(0xFFF3E3DD)),
                errorWidget: (c, u, e) => Container(
                    color: const Color(0xFFF3E3DD),
                    child: const Icon(Icons.error_outline)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideCard(Map<String, dynamic> outfit) {
    return HoverTap(
      lift: false,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OutfitDetailPage(outfit: outfit),
        ),
      ),
      child: HoverCard(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE7E4EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: CachedNetworkImage(
                    imageUrl: outfit['image'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: const Color(0xFFF3E3DD)),
                    errorWidget: (c, u, e) => Container(
                        color: const Color(0xFFF3E3DD),
                        child: const Icon(Icons.error_outline)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit['title'] ?? 'Outfit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0E1220)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outfit['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.4,
                          color: const Color(0xFF5B6177)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title,
      {int count = 0, VoidCallback? onPrev, VoidCallback? onNext}) {
    final showControls = count > 1 && onPrev != null && onNext != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: const Color(0xFF0E1220),
            ),
          ),
        ),
        if (showControls) ...[
          for (var i = 0; i < count && i < 6; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.only(right: 5),
              width: i == _page % count ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page % count
                    ? const Color(0xFF121A33)
                    : const Color(0xFFD9D5E0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 10),
          _arrow(Icons.chevron_left, 'Previous', onPrev),
          const SizedBox(width: 8),
          _arrow(Icons.chevron_right, 'Next', onNext),
        ],
      ],
    );
  }

  Widget _arrow(IconData icon, String tip, VoidCallback onTap) {
    return HoverTap(
      onTap: onTap,
      child: Tooltip(
        message: tip,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7E4EC)),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF0E1220)),
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
                colors: [Color(0xFF121A33), Color(0xFF1E2A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(child: _wordmark(light: true)),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Color(0xFF121A33)),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Color(0xFFA15A44)),
            title: const Text('AI 3-Dress Matcher'),
            subtitle: const Text('Let AI pick your best outfit'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIOutfitMatcherScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.checkroom, color: Color(0xFF121A33)),
            title: const Text('Wardrobe'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyWardrobe()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF121A33)),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSlider(bool wide) {
    if (_visible.isEmpty) return _emptyPicks();

    final items = _visible.map((outfit) {
      return HoverTap(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullImagePage(imageUrl: outfit['image'] ?? ''),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: outfit['image'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                      color: const Color(0xFFF3E3DD),
                      child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF3E3DD),
                      child: const Icon(Icons.error_outline)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF0E1220).withOpacity(0.78),
                          const Color(0xFF0E1220).withOpacity(0),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          outfit['title'] ?? 'Outfit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          outfit['description'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                              color: const Color(0xFFDDE2F0), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return CarouselSlider(
      items: items,
      carouselController: _carousel,
      options: CarouselOptions(
        height: wide ? 340 : 260,
        viewportFraction: wide ? 0.34 : 0.82,
        padEnds: false,
        enlargeCenterPage: false,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 6),
        autoPlayAnimationDuration: const Duration(milliseconds: 1200),
        autoPlayCurve: Curves.easeInOutCubic,
        onPageChanged: (index, reason) => setState(() => _page = index),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    if (recommendations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_visible.isEmpty) {
      return Text('No outfits match your search',
          style: GoogleFonts.manrope(
              color: const Color(0xFF5B6177), fontWeight: FontWeight.w700));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        const gap = 18.0;
        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _visible.map((outfit) {
            return SizedBox(
              width: cardW,
              child: HoverTap(
                lift: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OutfitDetailPage(outfit: outfit),
                  ),
                ),
                child: HoverCard(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Color(0xFFE7E4EC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: outfit['image'] ?? '',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: const Color(0xFFF3E3DD)),
                          errorWidget: (c, u, e) => Container(
                              color: const Color(0xFFF3E3DD),
                              child: const Icon(Icons.error_outline)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outfit['title'] ?? 'Untitled',
                              style: GoogleFonts.sora(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: const Color(0xFF0E1220)),
                            ),
                            const SizedBox(height: 4),
                            DefaultTextStyle(
                              style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: const Color(0xFF5B6177)),
                              child: _buildTruncatedDescription(
                                  outfit['description'] ?? '', outfit),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
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
              color: Color(0xFFA15A44),
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
      style: const TextStyle(color: Color(0xFF0E1220)),
      decoration: InputDecoration(
        hintText: "Search...",
        hintStyle: const TextStyle(color: Color(0xFF5B6177)),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0E1220)),
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
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF121A33), Color(0xFF1E2A4F)],
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
