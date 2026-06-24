import 'package:flutter/material.dart';
import 'package:miner_enterprises/customerpages/homepage.dart';
import 'package:miner_enterprises/customerpages/services.dart';
import 'package:miner_enterprises/customerpages/shop_acs.dart';
import 'package:miner_enterprises/customerpages/chatbot.dart';

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
          setState(() => _index = 1);
        },
      ),
      ShopAcs(),
      Services(),
    ][_index];
  }

  final List<String> _navLabels = ["HOME", "SHOP AC'S", "SERVICES"];

  Widget _desktopNavItem(String text, int pageIndex) {
    bool isActive = _index == pageIndex;
    return TextButton(
      onPressed: () => setState(() => _index = pageIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
                color: Colors.black, fontSize: 16, fontFamily: "Changa One"),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

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
          // Desktop nav
          if (!isMobile)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                children: [
                  ..._navLabels.asMap().entries.map((entry) => Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: _desktopNavItem(entry.value, entry.key),
                      )),
                ],
              ),
            ),
        ],
      ),

      body: getPage(),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) {
              return Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 16,
                    right: isMobile ? 16 : 80,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ChatbotSheet(),
                  ),
                ),
              );
            },
          );
        },
        backgroundColor: Color(0xFF013B7A),
        child: Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }
}