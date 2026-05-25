import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: EdgeInsets.only(left: 50, top: 30),
            child: Text(
              "OVERVIEW",
              style: TextStyle(fontSize: 20, fontFamily: "Changa One"),
            ),
          ),

          SizedBox(height: 20),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text(
                      "Total Service Request",
                      style: TextStyle(fontSize: 16, fontFamily: "Changa One"),
                    ),
                  ),
                ),

                SizedBox(width: 40),

                Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text(
                      "Pending Service",
                      style: TextStyle(fontSize: 16, fontFamily: "Changa One"),
                    ),
                  ),
                ),

                SizedBox(width: 40),

                Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text(
                      "Active Technicians",
                      style: TextStyle(fontSize: 16, fontFamily: "Changa One"),
                    ),
                  ),
                ),

                SizedBox(width: 40),

                Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text(
                      "Total Sales",
                      style: TextStyle(fontSize: 16, fontFamily: "Changa One"),
                    ),
                  ),
                ),

              ],
            ),
          ),


          Padding(
            padding: EdgeInsets.only(top: 25),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Container(
                  width: 680,
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text("Recent Service Requests", style: TextStyle(fontSize: 16, fontFamily: "Changa One")),
                  ),
                ),

                SizedBox(width: 40),

                Container(
                  width: 680,
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 25, left: 25),
                    child: Text("Monthly Revenue", style: TextStyle(fontSize: 16, fontFamily: "Changa One")),
                  ),
                ),
            ],
          ),
          )
        ],
      ),
    );
  }
}