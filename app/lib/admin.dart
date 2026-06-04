import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:miner_enterprises/adminpages/dashboard.dart';
import 'package:miner_enterprises/adminpages/history.dart';
import 'package:miner_enterprises/adminpages/products.dart';
import 'package:miner_enterprises/adminpages/service_request.dart';
import 'package:miner_enterprises/adminpages/technicians.dart';
import 'package:miner_enterprises/login.dart';

class Admin extends StatefulWidget {
  const Admin({super.key});
  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  int _index = 0;

  final List<Widget> pages = [
    Dashboard(),
    Products(),
    ServiceRequest(),
    Technicians(),
    History(),
  ];

  Widget navItem(String text, int pageIndex) {
    bool isActive = _index == pageIndex;

    return TextButton(
      onPressed: () => setState(() => _index = pageIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: Colors.black, fontSize: 16, fontFamily: "Changa One")),
          SizedBox(height: 5),
          Container(
            height: 3,
            width: isActive ? 50 : 0,
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
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Row(
              children: [
                navItem("Dashboard", 0),
                SizedBox(width: 10),
                navItem("Products", 1),
                SizedBox(width: 10),
                navItem("Service Request", 2),
                SizedBox(width: 10),
                navItem("Technicians", 3),
                SizedBox(width: 10),
                navItem("History", 4),
                SizedBox(width: 30),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    customButton: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(Icons.person, size: 28),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "logout",
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, size: 20, color: Colors.red),
                              SizedBox(width: 13),
                              Text("Logout", style: TextStyle(fontSize: 16, fontFamily: "Arimo", fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    menuItemStyleData: MenuItemStyleData(
                      height: 60,
                      padding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      width: 150,
                      offset: Offset(-110, 0),
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 8,
                    ),
                    onChanged: (value) {
                      if (value == "logout") {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text("Confirm Logout", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),
                            content: Text("Are you sure you want to logout?", style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c))),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => Login()),
                                  );
                                },
                                child: Text("Yes", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFF013b7a), fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_index],
    );
  }
}