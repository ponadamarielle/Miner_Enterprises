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

  final List<String> _navLabels = [
    "Dashboard",
    "Products",
    "Service Request",
    "Technicians",
    "History",
  ];

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Confirm Logout",
            style: TextStyle(fontSize: 20, fontFamily: "Changa One")),
        content: Text("Are you sure you want to logout?",
            style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: "Arimo",
                    color: Color(0xFFdc342c))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Login()),
              );
            },
            child: Text("Yes",
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: "Arimo",
                    color: Color(0xFF013b7a),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _desktopNavItem(String text, int pageIndex) {
    bool isActive = _index == pageIndex;
    return TextButton(
      onPressed: () => setState(() => _index = pageIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: "Changa One")),
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

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF013b7a)),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 40, height: 40),
                SizedBox(width: 12),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: "Miner ",
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: "Changa One",
                            color: Colors.white)),
                    TextSpan(
                        text: "Enterprises",
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: "Changa One",
                            color: Color(0xFFdc342c))),
                  ]),
                ),
              ],
            ),
          ),
          ..._navLabels.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            return ListTile(
              selected: _index == i,
              selectedTileColor: Color(0xFF013b7a).withValues(alpha: 0.1),
              title: Text(label,
                  style: TextStyle(fontFamily: "Changa One", fontSize: 15)),
              onTap: () {
                setState(() => _index = i);
                Navigator.pop(context);
              },
            );
          }),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Logout",
                style: TextStyle(
                    fontFamily: "Arimo",
                    fontWeight: FontWeight.w700,
                    color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      drawer: isMobile ? _buildDrawer() : null,

      appBar: AppBar(
        automaticallyImplyLeading: isMobile,
        backgroundColor: Colors.white,
        title: Padding(
          padding: EdgeInsets.only(left: isMobile ? 0 : 30),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              SizedBox(width: 15),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: "Miner ",
                      style: TextStyle(
                          fontSize: 20,
                          fontFamily: "Changa One",
                          color: Color(0xFF013b7a))),
                  TextSpan(
                      text: "Enterprises",
                      style: TextStyle(
                          fontSize: 20,
                          fontFamily: "Changa One",
                          color: Color(0xFFdc342c))),
                ]),
              ),
            ],
          ),
        ),
        actions: [
          // Desktop: show nav items in app bar
          if (!isMobile)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                children: [
                  ..._navLabels.asMap().entries.map((entry) => Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: _desktopNavItem(entry.value, entry.key),
                      )),
                  SizedBox(width: 30),
                  // Profile/Logout dropdown
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
                                Text("Logout",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: "Arimo",
                                        fontWeight: FontWeight.w700)),
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
                        if (value == "logout") _confirmLogout(context);
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (isMobile)
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () => _confirmLogout(context),
            ),
        ],
      ),

      body: pages[_index],
    );
  }
}