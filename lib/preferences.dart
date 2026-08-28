import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Preferences',
      home: Preferences(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Preferences extends StatefulWidget {
  const Preferences({super.key});
  @override
  State<Preferences> createState() => _PreferencesState();
}

class _PreferencesState extends State<Preferences> {
  final List<String> clothingStyles = [
    'Casual',
    'Formal',
    'Street Wear',
    'Bohemian',
    'Vintage',
    'Sporty'
  ];
  final List<String> fabrics = ['Cotton', 'Silk', 'Wool', 'Denim', 'Linen'];

  Map<String, bool> selectedStyles = {
    'Casual': false,
    'Formal': false,
    'Street Wear': false,
    'Bohemian': false,
    'Vintage': false,
    'Sporty': false,
  };

  Map<String, bool> selectedFabrics = {
    'Cotton': false,
    'Silk': false,
    'Wool': false,
    'Denim': false,
    'Linen': false,
  };

  String selectedOccasion = 'All';
  String selectedShoppingPref = 'All';

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _chestController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _shoeSizeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _savePreferences() async {
    final user = _auth.currentUser;
    if (user != null) {
      final List<String> clothingSelected = selectedStyles.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      final List<String> fabricsSelected = selectedFabrics.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      final preferencesData = {
        'clothingStyles': clothingSelected,
        'fabrics': fabricsSelected,
        'occasion': selectedOccasion,
        'shoppingPref': selectedShoppingPref,
        'height': _heightController.text,
        'chest': _chestController.text,
        'waist': _waistController.text,
        'shoeSize': _shoeSizeController.text,
      };

      try {
        await _firestore.collection('users').doc(user.uid).update({
          'preferences': preferencesData,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      } catch (e) {
        debugPrint('Error saving preferences: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences')),
        );
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _shoeSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 125, 134, 255),
      appBar: AppBar(
        title: const Text('Style Preferences',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(226, 94, 110, 255),
        foregroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSectionHeader(
              title: 'Personalize Your Experience',
              subtitle: 'Get outfit suggestions tailored to your preferences',
            ),
            _buildSectionCard(
              title: 'Preferred Clothing Styles',
              child: _buildChipGrid(selectedStyles),
            ),
            _buildSectionCard(
              title: 'Preferred Fabrics',
              child: _buildChipGrid(selectedFabrics),
            ),
            isSmallScreen
                ? Column(
                    children: [
                      _buildDropdownSection(
                          'Occasion Preferences',
                          [
                            'All',
                            'Weddings',
                            'Casual',
                            'Work',
                            'Daily Wear',
                            'Parties'
                          ],
                          selectedOccasion, (value) {
                        setState(() => selectedOccasion = value ?? 'All');
                      }),
                      _buildDropdownSection(
                          'Shopping Preference',
                          [
                            'All',
                            'Brands',
                            'Local Stores',
                            'Online',
                            'Thrift Stores'
                          ],
                          selectedShoppingPref, (value) {
                        setState(() => selectedShoppingPref = value ?? 'All');
                      }),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildDropdownSection(
                            'Occasion Preferences',
                            [
                              'All',
                              'Weddings',
                              'Casual',
                              'Work',
                              'Daily Wear',
                              'Parties'
                            ],
                            selectedOccasion,
                            (value) => setState(
                                () => selectedOccasion = value ?? 'All')),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownSection(
                            'Shopping Preference',
                            [
                              'All',
                              'Brands',
                              'Local Stores',
                              'Online',
                              'Thrift Stores'
                            ],
                            selectedShoppingPref,
                            (value) => setState(
                                () => selectedShoppingPref = value ?? 'All')),
                      ),
                    ],
                  ),
            _buildSectionCard(
              title: 'Body Measurements (Optional)',
              child: _buildMeasurementFields(isSmallScreen),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      {required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: const Color.fromARGB(207, 178, 204, 243),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color.fromARGB(255, 94, 143, 218)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildChipGrid(Map<String, bool> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: items.keys.map((item) {
        return FilterChip(
          selected: items[item] ?? false,
          onSelected: (value) => setState(() => items[item] = value),
          label: Text(item),
          selectedColor: Colors.purple.shade50,
          checkmarkColor: Colors.purple,
          labelStyle: TextStyle(
            color: items[item]! ? Colors.purple : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: items[item]! ? Colors.purple : Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownSection(String title, List<String> options,
      String selected, ValueChanged<String?> onChanged) {
    return _buildSectionCard(
      title: title,
      child: DropdownButtonFormField<String>(
        value: selected,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        items: options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMeasurementFields(bool isSmallScreen) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        TextField(
          controller: _heightController,
          decoration: InputDecoration(
            labelText: 'Height',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        TextField(
          controller: _chestController,
          decoration: InputDecoration(
            labelText: 'Chest',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        TextField(
          controller: _waistController,
          decoration: InputDecoration(
            labelText: 'Waist',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        TextField(
          controller: _shoeSizeController,
          decoration: InputDecoration(
            labelText: 'Shoe Size',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _savePreferences,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Preferences',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
