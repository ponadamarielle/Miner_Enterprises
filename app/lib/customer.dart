import 'package:flutter/material.dart';
import 'package:miner_enterprises/customerpages/homepage.dart';
import 'package:miner_enterprises/customerpages/services.dart';
import 'package:miner_enterprises/customerpages/shop_acs.dart';

class Customer extends StatefulWidget {
  const Customer({super.key});

  @override
  State<Customer> createState() => _CustomerState();
}

class _CustomerState extends State<Customer> {
  int _index = 0;

  Widget getPage() {
    return [
      Homepage(
        onBrowsePressed: () {
          setState(() {
            _index = 1;
          });
        },
      ),
      ShopAcs(),
      Services(),
    ][_index];
  }

  Widget navItem(String text, int pageIndex) {
  bool isActive = _index == pageIndex;

  return TextButton(
    onPressed: () => setState(() => _index = pageIndex),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(color: Colors.black, fontSize: 16, fontFamily: "Changa One"),
        ),

        SizedBox(height: 5),

        Container(
          height: 3,
          width: isActive ? 40 : 0,
          color: Color(0xFF013b7a),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: Padding(
          padding: EdgeInsetsGeometry.only(left: 30),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              SizedBox(width: 15),

              Text.rich(
                TextSpan(
                children: [
                  TextSpan(text: "Miner ", style: TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFF013b7a))),
                  TextSpan(text: "Enterprises", style: TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFFdc342c))),
                ]
                )
              ),
            ]
          )
        ),

        // navbar
        actions: [
        Padding(
        padding: EdgeInsets.symmetric(horizontal: 50),
        
        child: Row(
          children: [
            navItem("HOME", 0),
            SizedBox(width: 10),

            navItem("SHOP AC'S", 1),
            SizedBox(width: 10),

            navItem("SERVICES", 2),
            SizedBox(width: 10),
        ],
      ),
        ),
        ]
      ),
      body: getPage(),
  
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          //chatbox
        },
        backgroundColor: Color(0xFF013B7A),
        child: Icon(Icons.chat_bubble, color: Colors.white),
      ),

      
    );
  }
}