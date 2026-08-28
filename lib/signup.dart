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

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14),
      floatingLabelStyle:
          const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.pink, width: 0.5),
      ),
      suffixIcon: suffixIcon,
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerStyle = GoogleFonts.poppins(
      fontSize: screenHeight * 0.04,
      fontWeight: FontWeight.w600,
      letterSpacing: 4,
      color: Colors.black,
    );

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
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.28),
                child: BlurryContainer(
                  blur: 10,
                  height: screenHeight * 0.72,
                  width: screenWidth,
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Center(
                              child: Text('Get Started', style: headerStyle)),
                          SizedBox(height: screenHeight * 0.05),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                height: screenWidth * 0.10,
                                width: screenWidth * 0.43,
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: _inputDecoration('First Name'),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter first name"
                                          : null,
                                ),
                              ),
                              SizedBox(
                                height: screenWidth * 0.10,
                                width: screenWidth * 0.43,
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: _inputDecoration('Last Name'),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter last name"
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          // Dedicated Username Field.
                          SizedBox(
                            height: screenWidth * 0.10,
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: _inputDecoration('Username'),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter username"
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: screenWidth * 0.10,
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: _inputDecoration('Phone Number'),
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter phone number"
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: screenWidth * 0.10,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                'Email',
                                suffixIcon: const FaIcon(FontAwesomeIcons.user,
                                    size: 15),
                              ),
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
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                height: screenWidth * 0.10,
                                width: screenWidth * 0.43,
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: _inputDecoration(
                                    'Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 15,
                                      ),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible =
                                              !_isPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Enter password";
                                    }
                                    if (value.length < 6) {
                                      return "Password must be at least 6 characters";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(
                                height: screenWidth * 0.10,
                                width: screenWidth * 0.43,
                                child: TextFormField(
                                  controller: _confirmController,
                                  obscureText: !_isConfirmPasswordVisible,
                                  decoration: _inputDecoration(
                                    'Confirm Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 15,
                                      ),
                                      onPressed: () => setState(() =>
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Confirm your password";
                                    }
                                    if (value !=
                                        _passwordController.text.trim()) {
                                      return "Passwords do not match";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: screenHeight * 0.06,
                            width: screenWidth * 0.8,
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(
                                    const Color.fromARGB(255, 255, 0, 200)),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16.0)),
                                ),
                                elevation: MaterialStateProperty.all(5),
                              ),
                              onPressed: _signUp,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    )
                                  : Text(
                                      "SignUp",
                                      style: GoogleFonts.poppins(
                                        fontSize: screenHeight * 0.025,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account?",
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginPage()),
                                  );
                                },
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: screenWidth * 0.04,
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  height: 1,
                                  width: screenWidth * 0.15,
                                  color: Colors.grey),
                              const Text(
                                "  Or Continue With  ",
                                style: TextStyle(
                                    color: Color.fromARGB(255, 156, 156, 156),
                                    fontSize: 14),
                              ),
                              Container(
                                  height: 1,
                                  width: screenWidth * 0.15,
                                  color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _signInWithGoogle,
                                icon: const FaIcon(FontAwesomeIcons.google,
                                    color: Colors.red, size: 30),
                              ),
                              const SizedBox(width: 30),
                              IconButton(
                                onPressed: () {},
                                icon: const FaIcon(FontAwesomeIcons.facebook,
                                    color: Color.fromARGB(255, 60, 43, 212),
                                    size: 30),
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
