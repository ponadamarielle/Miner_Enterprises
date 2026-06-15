import 'package:flutter/material.dart';

class Homepage extends StatelessWidget {
  final VoidCallback onBrowsePressed;

  const Homepage({super.key, required this.onBrowsePressed});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final titleFontSize = isMobile ? 32.0 : isTablet ? 50.0 : 70.0;
    final subtitleFontSize = isMobile ? 14.0 : isTablet ? 17.0 : 20.0;
    final buttonFontSize = isMobile ? 14.0 : 18.0;
    final titleSpacing = isMobile ? 40.0 : isTablet ? 60.0 : 90.0;
    final subtitleSpacing = isMobile ? 40.0 : isTablet ? 50.0 : 70.0;
    final buttonPaddingH = isMobile ? 24.0 : 40.0;
    final buttonPaddingV = isMobile ? 14.0 : 20.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 24.0 : 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Welcome to Miner Enterprises, Your\nUltimate Cooling Solution",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontFamily: "Changa One",
                    ),
                  ),

                  SizedBox(height: titleSpacing),

                  Text(
                    "Providing quality air conditioning services to keep you cool all year round!\nFrom installations to repairs and maintenance, we've got you covered.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      fontFamily: "Arimo",
                    ),
                  ),

                  SizedBox(height: subtitleSpacing),

                  ElevatedButton(
                    onPressed: onBrowsePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF013B7A),
                      elevation: 10,
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonPaddingH,
                        vertical: buttonPaddingV,
                      ),
                    ),
                    child: Text(
                      "BROWSE AC UNITS",
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontFamily: "Changa One",
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}