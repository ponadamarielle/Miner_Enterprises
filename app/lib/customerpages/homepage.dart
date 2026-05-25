import 'package:flutter/material.dart';

class Homepage extends StatelessWidget {
  final VoidCallback onBrowsePressed;

  const Homepage({super.key, required this.onBrowsePressed});

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Welcome to Miner Enterprises, Your\nUltimate Cooling Solution",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 70, fontFamily: "Changa One"),
              ),

              SizedBox(height: 90),

              Text("Providing quality air conditioning services to keep you cool all year round!\nFrom installations to repairs and maintenance, we've got you covered.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontFamily: "Arimo"),
              ),

              SizedBox(height: 70),

              ElevatedButton(
                onPressed: onBrowsePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF013B7A), 
                  elevation: 10, 
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
                child: Text("BROWSE AC UNITS", style: TextStyle(fontSize: 18, fontFamily: "Changa One", color: Colors.white))
              ),
            ],
          )
          ),
        ]
      )
    );
  }
}