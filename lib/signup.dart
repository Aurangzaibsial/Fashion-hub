import 'dart:ui';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuseapp/login.dart';
import 'package:fitfuseapp/startup.dart';
import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color _primary = Color(0xFF6C3DE8);
  static const Color _secondary = Color(0xFFE040AB);

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75)),
      floatingLabelStyle: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  List<String> generateUsernameSuggestions(String username) {
    List<String> suggestions = [];
    Random random = Random();
    for (int i = 0; i < 3; i++) {
      int num = random.nextInt(90) + 10;
      suggestions.add("$username$num");
    }
    return suggestions;
  }

  Future<void> _checkAndShowUsernameRecommendations(String username) async {
    var usernameQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    if (usernameQuery.docs.isNotEmpty) {
      List<String> suggestions = generateUsernameSuggestions(username);
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Username already exists"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Here are some suggestions:"),
                ...suggestions.map((suggestion) => ListTile(
                      title: Text(suggestion),
                      onTap: () {
                        setState(() {
                          _usernameController.text = suggestion;
                        });
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text.trim() != _confirmController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    setState(() {
      _isLoading = true;
    });
    String username = _usernameController.text.trim();
    try {
      var usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      if (usernameQuery.docs.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        _checkAndShowUsernameRecommendations(username);
        return;
      }
      var phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: _phoneController.text.trim())
          .get();
      if (phoneQuery.docs.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Phone number already registered")));
        return;
      }
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'username': username,
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'profilePicURL': '',
        'role': 'user',
        'isBlocked': false,
        'followers': [],
        'following': [],
        'createdAt': Timestamp.now(),
      });
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Startup()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Sign up failed: $e")));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Startup()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Google Sign-In failed: $e")));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required Widget child,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget iconWidget,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Center(child: iconWidget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.jpg', fit: BoxFit.cover),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.28,
            child: Image.asset('assets/images/room.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.22),
                child: BlurryContainer(
                  blur: 18,
                  height: screenHeight * 0.78,
                  width: screenWidth,
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Create Account',
                            style: GoogleFonts.poppins(
                              fontSize: screenHeight * 0.033,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Join NextGen Cloth Engine today',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: screenWidth * 0.40,
                                child: TextFormField(
                                  controller: _firstNameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: _inputDecoration('First Name'),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter first name"
                                          : null,
                                ),
                              ),
                              SizedBox(
                                width: screenWidth * 0.40,
                                child: TextFormField(
                                  controller: _lastNameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: _inputDecoration('Last Name'),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter last name"
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Username'),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? "Enter username"
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Phone Number'),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? "Enter phone number"
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Email'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter your email";
                              }
                              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: screenWidth * 0.40,
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: _inputDecoration(
                                    'Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible = !_isPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Enter password";
                                    }
                                    if (value.length < 6) {
                                      return "Min 6 characters";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(
                                width: screenWidth * 0.40,
                                child: TextFormField(
                                  controller: _confirmController,
                                  obscureText: !_isConfirmPasswordVisible,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: _inputDecoration(
                                    'Confirm',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () => setState(() =>
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Confirm password";
                                    }
                                    if (value != _passwordController.text.trim()) {
                                      return "Passwords don't match";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildGradientButton(
                            onPressed: _signUp,
                            width: screenWidth * 0.80,
                            height: screenHeight * 0.062,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    "Create Account",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.75),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const LoginPage()),
                                  );
                                },
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "Or continue with",
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                iconWidget: const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 22),
                                onPressed: _signInWithGoogle,
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                iconWidget: const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 22),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
