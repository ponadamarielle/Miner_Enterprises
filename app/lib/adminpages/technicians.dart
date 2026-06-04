import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class Technicians extends StatefulWidget {
  const Technicians({super.key});

  @override
  State<Technicians> createState() => _TechniciansState();
}

class _TechniciansState extends State<Technicians> {

  //customize id
Future<String> generateTechId() async {
  final snapshot = await FirebaseFirestore.instance
    .collection('technicians')
    .get();

    int count = snapshot.docs.length + 1;

    return "TECH${count.toString().padLeft(2, '0')}";
}

//save
Future<void> _saveTechnician(String name, String mobile) async {
  String techId = await generateTechId();

  await FirebaseFirestore.instance
      .collection('technicians')
      .doc(techId)
      .set({
    'name': name.trim(),
    'mobileNumber': mobile.trim(),
    'isActive': true,
  });
}

//add technician dialog
void _addTechnicianDialog() {
  TextEditingController nameController = TextEditingController();
  TextEditingController mobileNumController = TextEditingController();
  final formKey = GlobalKey<FormState>(); 

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Add Technician", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),

        content: SizedBox(
          width: 350,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),

                TextFormField(
                  controller: nameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
                  decoration: InputDecoration(
                    labelText: "Name",
                    labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Name is required";
                    }
                    return null;
                  },
                ),

                SizedBox(height: 20),

                TextFormField(
                  controller: mobileNumController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: "Mobile Number",
                    labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Mobile number is required";
                    }
                    return null; 
                  },
                ),
              ],
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontSize: 13,
                fontFamily: "Arimo",
                color: Color(0xFFdc342c),
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              if (formKey.currentState!.validate()) {
                await _saveTechnician(
                  nameController.text,
                  mobileNumController.text,
                );

                nav.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 8),
            child: Text(
              "SAVE",
              style: TextStyle(
                fontSize: 13,
                fontFamily: "Arimo",
                fontWeight: FontWeight.w700,
                color: Color(0xFF013b7a),
              ),
            ),
          ),
        ],
      );
    },
  );
}
  

//load table data
Widget _buildTechnicianTable() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('technicians')
        .where('isActive', isEqualTo: true)
        .snapshots(),
    builder: (context, snapshot) {

      if (snapshot.hasError) {
        return Center(child: Text("Error loading data"));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      var docs = snapshot.data!.docs;

      return DataTable(
        headingTextStyle: TextStyle(
          fontFamily: "Changa One",
          fontSize: 16,
          color: Colors.black,
        ),

        headingRowColor: WidgetStatePropertyAll(Colors.white),

        columns: [
          DataColumn(label: Text("ID")),
          DataColumn(label: Text("Name")),
          DataColumn(label: Text("Mobile Number")),
          DataColumn(label: Text(""))
        ],

        dataRowColor:
            WidgetStateProperty.resolveWith<Color?>((states) {
          return Color(0xFFF8F8F8);
        }),

        rows: docs.map((doc) {
          return DataRow(
            cells: [
              DataCell(Text(doc.id, style: TextStyle(fontSize: 15, fontFamily: "Arimo"))),
              DataCell(Text(doc['name'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"))),
              DataCell(Text(doc['mobileNumber'] ?? '', style: TextStyle(fontSize: 15, fontFamily: "Arimo"))),

              DataCell(
                Row(
                  children: [

                    IconButton(
                      onPressed: () => _editDialog(doc),
                      icon: Icon(Icons.edit, color: Colors.black),
                    ),

                    SizedBox(width: 15),

                    TextButton.icon(
                      onPressed: () => _deactivateDialog(doc.id),
                      icon: Icon(Icons.block, size: 18, color: Colors.white),
                      label: Text("Deactivate"),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        }).toList(),
      );
    },
  );
}

//edit dialog
void _editDialog(QueryDocumentSnapshot doc) {
  showDialog(
    context: context,
    builder: (context) {
      TextEditingController nameController = TextEditingController(text: doc['name']);
      TextEditingController mobileNumController = TextEditingController(text: doc['mobileNumber']);

      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Edit Details", style: TextStyle(fontSize: 20, fontFamily: "Changa One"),
        ),

        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10),

              TextField(
                controller: nameController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                decoration: InputDecoration(
                  labelText: "Name",
                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              TextField(
                controller: mobileNumController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: "Mobile Number",
                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c)),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseFirestore.instance
                  .collection('technicians')
                  .doc(doc.id)
                  .update({
                'name': nameController.text,
                'mobileNumber': mobileNumController.text,
              });

              nav.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 8),
            child: Text(
              "SAVE",
              style: TextStyle(
                fontSize: 13,
                fontFamily: "Arimo",
                fontWeight: FontWeight.w700,
                color: Color(0xFF013b7a),
              ),
            ),
          ),
        ],
      );
    },
  );
}

//deactivate dialog
void _deactivateDialog(String id) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text("Deactivate Technician", style: TextStyle(fontSize: 20, fontFamily: "Changa One"),
      ),

      content: Text("Are you sure you want to deactivate this technician?",
        style: TextStyle(
          fontSize: 13,
          fontFamily: "Arimo",
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("Cancel", style: TextStyle(color: Color(0xFFdc342c)),
          ),
        ),

        TextButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            await FirebaseFirestore.instance
                .collection('technicians')
                .doc(id)
                .update({
              'isActive': false,
            });

            nav.pop();
          },
          child: Text("Yes", style: TextStyle(color: Color(0xFF013b7a), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),

      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // add
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 190,
                  height: 40,
                  child: TextButton(
                    onPressed: _addTechnicianDialog,

                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFF013b7a),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        Image.asset('assets/images/add.png', width: 17, height: 17),

                        SizedBox(width: 10),

                        Text(
                          "Add Technician",
                          style: TextStyle(
                            fontFamily: 'Changa One',
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // table
            DataTableTheme(
              data: DataTableThemeData(
                dividerThickness: 1,
              ),

              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,

                  child: _buildTechnicianTable(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}