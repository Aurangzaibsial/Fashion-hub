import 'package:fitfuseapp/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReels extends StatefulWidget {
  const MyReels({super.key});

  @override
  State<MyReels> createState() => _MyReelsState();
}

class _MyReelsState extends State<MyReels> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final TextStyle headerStyle = GoogleFonts.lemon(
      fontSize: screenWidth * 0.14,
      fontWeight: FontWeight.bold,
      color: const Color.fromARGB(255, 68, 0, 145),
    );

    final TextStyle subtitleStyle = GoogleFonts.lemon(
      fontSize: screenWidth * 0.05,
      color: const Color.fromARGB(255, 72, 4, 150),
    );

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/bg.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: screenWidth,
                height: screenHeight * 0.46,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/welcome.jpeg"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Center(
                child: Text(
                  "Fabric Fusion",
                  style: headerStyle,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Container(
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Text(
                  "Your Personal AI Stylist For Every Occasion",
                  style: subtitleStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Center(
                child: SizedBox(
                  height: screenHeight * 0.06,
                  width: screenWidth * 0.7,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        const Color.fromARGB(255, 255, 0, 200),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      elevation: WidgetStateProperty.all(5),
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()));
                    },
                    child: Text(
                      "Get Started",
                      style: GoogleFonts.lemon(
                        fontSize: screenWidth * 0.05,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
