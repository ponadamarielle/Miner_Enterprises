import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  String searchQuery = "";
  String selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    Widget searchBox = Container(
      width: isDesktop ? 450 : double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: "Search customer...",
          hintStyle: TextStyle(fontSize: 16, fontFamily: "Arimo"),
          prefixIcon: Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );

    Widget filterBox = Container(
      width: isDesktop ? 200 : double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          value: selectedFilter,
          isExpanded: true,
          iconStyleData: IconStyleData(
            icon: Icon(Icons.arrow_drop_down),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 8,
            offset: Offset(0, 5),
          ),
          style: TextStyle(
            fontSize: 16,
            fontFamily: "Arimo",
            color: Colors.black,
          ),
          items: [
            DropdownMenuItem(value: "All", child: Text("All")),
            DropdownMenuItem(value: "Completed", child: Text("Completed")),
            DropdownMenuItem(value: "Cancelled", child: Text("Cancelled")),
          ],
          onChanged: (value) {
            setState(() {
              selectedFilter = value!;
            });
          },
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),

      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 25 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (isDesktop)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  searchBox,
                  filterBox,
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchBox,
                  SizedBox(height: 15),
                  filterBox,
                ],
              ),

            SizedBox(height: 30),

            DataTableTheme(
              data: DataTableThemeData(
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 25,
                headingRowColor: WidgetStatePropertyAll(Colors.white),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  return Color(0xFFF8F8F8);
                }),
              ),

              child: Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical, 
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width,
                      ),

                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('history')
                            .orderBy('date', descending: true)
                            .snapshots(),

                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text("No history found", style: TextStyle(fontSize: 20, fontFamily: "Arimo", fontWeight: FontWeight.w700)));
                          }

                          var docs = snapshot.data!.docs;

                          var filteredDocs = docs.where((doc) {
                            final name = (doc['name'] ?? '').toString().toLowerCase();
                            final status = doc['status'] ?? '';

                            final matchesSearch =
                                name.contains(searchQuery.toLowerCase());

                            final matchesFilter =
                                selectedFilter == "All" ||
                                status == selectedFilter;

                            return matchesSearch && matchesFilter;
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return Center(child: Text("No matching results", style: TextStyle(fontSize: 20, fontFamily: "Arimo", fontWeight: FontWeight.w700)));
                          }

                          return DataTable(
                            headingTextStyle: TextStyle(
                              fontFamily: "Changa One",
                              fontSize: 16,
                              color: Colors.black,
                            ),

                            columns: [
                              DataColumn(label: Text("Customer Name")),
                              DataColumn(label: Text("Email")),
                              DataColumn(label: Text("Service Type")),
                              DataColumn(label: Text("Product")),
                              DataColumn(label: Text("Technician")),
                              DataColumn(label: Text("Status")),
                              DataColumn(label: Text("Payment Method")),
                              DataColumn(label: Text("Total Cost")),
                              DataColumn(label: Text("Date")),
                            ],

                            rows: filteredDocs.map((doc) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: Text(doc['name'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 240,
                                      child: Text(doc['email'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 85,
                                      child: Text(doc['serviceType'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(doc['productName'] ?? 'N/A', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 115,
                                      child: Text(doc['technicianName'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        doc['status'] ?? '',
                                        style: TextStyle(
                                          color: doc['status'] == "Completed"
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 15, fontFamily: "Arimo",
                                        ),
                                        softWrap: true,
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Text(doc['paymentMethod'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"), softWrap: true, maxLines: null, overflow: TextOverflow.visible),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        "₱${NumberFormat('#,##0').format((doc.data() as Map<String, dynamic>).containsKey('totalPrice') ? (doc['totalPrice'] as num) : 0)}",
                                        style: TextStyle(fontSize: 15, fontFamily: "Arimo", fontWeight: FontWeight.bold, color: Color(0xFF013B7A)),
                                        softWrap: true,
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Text(
                                        doc['date'] is Timestamp
                                            ? DateFormat('MMM d, yyyy')
                                                .format((doc['date'] as Timestamp).toDate())
                                            : '',
                                        style: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                        softWrap: true,
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )
            )
          ],
        ),
      ),
    );
  }
}