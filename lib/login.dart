import 'dart:ui';
import 'package:fitfuseapp/signup.dart';
import 'package:fitfuseapp/startup.dart';
import 'package:flutter/material.dart';
import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const double _blurSigma = 2.0;
  static const double _inputBorderWidth = 0.5;
  static const Color _mainPurple = Color.fromARGB(255, 113, 0, 158);
  static const Color _iconPurple = Color.fromARGB(255, 95, 68, 117);
  static const Color _inputFill = Color.fromARGB(131, 70, 70, 70);
  static const Color _borderColor = Color.fromARGB(255, 184, 121, 180);
  static const Radius _containerRadius = Radius.circular(40);

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Startup()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Startup()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.all(15),
      filled: true,
      fillColor: _inputFill,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
      prefixIcon: Icon(prefixIcon, color: _iconPurple),
      suffixIcon: suffixIcon,
      border: _buildInputBorder(),
      focusedBorder: _buildInputBorder(),
    );
  }

  OutlineInputBorder _buildInputBorder() {
    return OutlineInputBorder(
      borderSide:
          const BorderSide(color: _borderColor, width: _inputBorderWidth),
      borderRadius: BorderRadius.circular(10),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildBackgroundImages(Size screenSize) {
    return Column(
      children: [
        Container(
          height: screenSize.height * 0.35,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/welcome1.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: screenSize.height * 0.65,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/loginbg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(Size screenSize, TextStyle headerStyle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: AbsorbPointer(
        absorbing: _isLoading,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Welcome Back!', style: headerStyle),
              const SizedBox(height: 5),
              const Text(
                'Enhance Your Fashion Sense',
                style: TextStyle(color: Color.fromARGB(255, 187, 185, 179)),
              ),
              SizedBox(height: screenSize.height * 0.05),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'Email or Phone Number',
                  prefixIcon: Icons.person,
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? "Please enter your email or phone number"
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'Password',
                  prefixIcon: Icons.key,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: _iconPurple,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? "Please enter your password"
                    : null,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: screenSize.height * 0.07,
                width: screenSize.width * 0.9,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mainPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  onPressed: _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.height * 0.025,
                            color: Colors.white,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDividerLine(screenSize),
                  const Text("  Or Login With  ",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  _buildDividerLine(screenSize),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _signInWithGoogle,
                    icon: const FaIcon(FontAwesomeIcons.google,
                        color: Colors.orange, size: 30),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {},
                    icon: const FaIcon(FontAwesomeIcons.facebook,
                        color: Colors.blue, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Signup()),
                      );
                    },
                    child: const Text(
                      "Create here",
                      style: TextStyle(
                        color: _mainPurple,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDividerLine(Size screenSize) {
    return Container(
      height: 1,
      width: screenSize.width * 0.2,
      color: Colors.grey,
    );
  }

  Widget _buildBlurredContent(Size screenSize, TextStyle headerStyle) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
      child: Padding(
        padding: EdgeInsets.only(top: screenSize.height * 0.28),
        child: BlurryContainer(
          blur: 10,
          height: screenSize.height * 0.72,
          width: screenSize.width,
          color: Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: _containerRadius,
            topRight: _containerRadius,
          ),
          child: _buildLoginForm(screenSize, headerStyle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final headerStyle = GoogleFonts.poppins(
      fontSize: screenSize.height * 0.035,
      fontWeight: FontWeight.w700,
      letterSpacing: 6,
      color: Colors.white,
    );

    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundImages(screenSize),
          _buildBlurredContent(screenSize, headerStyle),
        ],
      ),
    );
  }
}
