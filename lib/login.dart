import 'package:fitfuseapp/signup.dart';
import 'package:fitfuseapp/startup.dart';
import 'package:flutter/material.dart';
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

  static const Color _navy = Color(0xFF121A33);
  static const Color _rose = Color(0xFFE0A58F);
  static const Color _roseDark = Color(0xFFA15A44);
  static const Color _ink = Color(0xFF0E1220);
  static const Color _slate = Color(0xFF5B6177);
  static const Color _line = Color(0xFFE7E4EC);
  static const Color _porcelain = Color(0xFFFAF9F7);

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

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderSide: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFF7A7F92)),
      prefixIcon: Icon(prefixIcon, color: _slate, size: 20),
      suffixIcon: suffixIcon,
      border: _border(_line),
      enabledBorder: _border(_line),
      focusedBorder: _border(_navy),
      errorBorder: _border(const Color(0xFFB3261E)),
      focusedErrorBorder: _border(const Color(0xFFB3261E)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _logo({Color textColor = Colors.white}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('N',
                  style: GoogleFonts.sora(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
              Positioned(
                right: 8,
                bottom: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: _rose, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(
            style: GoogleFonts.sora(
                fontSize: 16,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: textColor),
            children: const [
              TextSpan(text: 'NextGen\n'),
              TextSpan(text: 'Cloth Engine', style: TextStyle(color: _rose)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: _rose, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text,
                style: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFFDDE2F0))),
          ),
        ],
      ),
    );
  }

  /// Wardrobe photo with a navy scrim so the logo and text stay readable.
  Widget _imagePanel({required bool wide}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/welcome1.jpeg',
          fit: BoxFit.cover,
          alignment: const Alignment(0.35, -0.1),
        ),
        Container(color: _navy.withOpacity(0.45)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_navy.withOpacity(0.20), _navy.withOpacity(0.88)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(wide ? 48 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _logo(),
              const Spacer(),
              if (wide) ...[
                Text(
                  'Your wardrobe,\nstyled by AI.',
                  style: GoogleFonts.sora(
                    fontSize: 40,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 22),
                _benefit('Compare outfits and let AI pick the best'),
                _benefit('Looks matched to the weather'),
                _benefit('Share and discover with the community'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
      );

  Widget _socialButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: icon,
          label: Text(label,
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _line, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm({required bool wide}) {
    return AbsorbPointer(
      absorbing: _isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: GoogleFonts.sora(
                fontSize: wide ? 36 : 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.1,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log in to continue styling your wardrobe.',
              style: GoogleFonts.manrope(fontSize: 15, color: _slate, height: 1.5),
            ),
            const SizedBox(height: 28),
            _label('Email or phone number'),
            TextFormField(
              controller: _emailController,
              style: GoogleFonts.manrope(fontSize: 15, color: _ink),
              decoration: _inputDecoration(
                hint: 'you@example.com',
                prefixIcon: Icons.person_outline,
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? "Please enter your email or phone number"
                  : null,
            ),
            const SizedBox(height: 18),
            _label('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: GoogleFonts.manrope(fontSize: 15, color: _ink),
              decoration: _inputDecoration(
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _slate,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? "Please enter your password"
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.manrope(
                      color: _navy, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Log in',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: _line, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or continue with',
                      style: GoogleFonts.manrope(
                          color: _slate, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Expanded(child: Divider(color: _line, thickness: 1)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _socialButton(
                  icon: const FaIcon(FontAwesomeIcons.google,
                      color: Color(0xFFDB4437), size: 18),
                  label: 'Google',
                  onTap: _signInWithGoogle,
                ),
                const SizedBox(width: 12),
                _socialButton(
                  icon: const FaIcon(FontAwesomeIcons.facebook,
                      color: Color(0xFF1877F2), size: 18),
                  label: 'Facebook',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: GoogleFonts.manrope(color: _slate, fontSize: 15)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Signup()),
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Create account',
                        style: GoogleFonts.manrope(
                          color: _roseDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        backgroundColor: _porcelain,
        body: Row(
          children: [
            Expanded(flex: 11, child: _imagePanel(wide: true)),
            Expanded(
              flex: 10,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildLoginForm(wide: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _navy,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: _imagePanel(wide: false),
            ),
            Positioned(
              top: 210,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: _porcelain,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: _buildLoginForm(wide: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
