import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Services extends StatefulWidget {
  const Services({super.key});

  @override
 State<Services> createState() => _ServicesState();
}

class _ServicesState extends State<Services> with WidgetsBindingObserver {
  bool isLoading = false;
  bool showInstallationForm = false;
  bool showRepairForm = false;

  String? _pendingChargeId;
  String? _pendingRequestId;
  bool _waitingForPayment = false;

  Set<String> iFullyBookedTimes = {};
  Set<String> rFullyBookedTimes = {};
  int totalTechnicians = 0;

  final _installationFormKey = GlobalKey<FormState>();
  final _repairFormKey = GlobalKey<FormState>();

  // installation
  final iNameController = TextEditingController();
  final iMobileController = TextEditingController();
  final iEmailController = TextEditingController();
  final iDateController = TextEditingController();
  final iAddressController = TextEditingController();

  String? iSelectedType;
  String? iSelectedProduct;
  String? iSelectedTime;
  String? iPaymentMethod;
  double iSelectedPrice = 0.0;
  List<Map<String, dynamic>> iAllProducts = [];

  static const double installationFee = 500.0;
  static const double repairFee = 350.0;

  // repair
  final rNameController = TextEditingController();
  final rMobileController = TextEditingController();
  final rEmailController = TextEditingController();
  final rDateController = TextEditingController();
  final rAddressController = TextEditingController();
  final rDescriptionController = TextEditingController();

  String? rSelectedType;
  String? rSelectedProduct;
  String? rSelectedTime;
  String? rPaymentMethod;
  List<Map<String, dynamic>> rAllProducts = [];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPayment) {
      _waitingForPayment = false;
      if (_pendingChargeId != null && _pendingRequestId != null) {
        verifyXenditPayment(_pendingChargeId!, _pendingRequestId!);
      }
    }
  }

  // customize request id
  Future<String> generateServiceRequestId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('service_requests');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int lastNumber;

      if (!snapshot.exists) {
        lastNumber = 0;
        transaction.set(counterRef, {'lastNumber': 1});
      } else {
        lastNumber = snapshot['lastNumber'];
        transaction.update(counterRef, {
          'lastNumber': lastNumber + 1,
        });
      }

      int newNumber = lastNumber + 1;

      String year = DateTime.now().year.toString();

      return "SR-$year-${newNumber.toString().padLeft(5, '0')}";
    });
  }

  // auto assign
  Future<Map<String, dynamic>?> autoAssignTechnician(DateTime selectedDate, String selectedTime) async {
    final techSnapshot = await firestore
        .collection("technicians")
        .where("isActive", isEqualTo: true)
        .get();

    if (techSnapshot.docs.isEmpty) return null;

    for (var tech in techSnapshot.docs) {
      await resetIfNewDay(tech, selectedDate);
    }

    final dateStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = dateStart.add(Duration(days: 1));

    final bookingsSnapshot = await firestore
        .collection("service_requests")
        .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
        .where("date", isLessThan: Timestamp.fromDate(dateEnd))
        .get();

    final busyTechIds = bookingsSnapshot.docs
        .where((doc) => doc["time"] == selectedTime)
        .map((doc) => doc["technicianId"] as String)
        .toSet();

    final availableTechs = techSnapshot.docs
        .where((tech) => !busyTechIds.contains(tech.id))
        .toList();

    if (availableTechs.isEmpty) return null; 

    availableTechs.sort((a, b) =>
        (a["todayJobCount"] ?? 0).compareTo(b["todayJobCount"] ?? 0));

    final bestTech = availableTechs.first;

    return {
      "technicianId": bestTech.id,
      "technicianName": bestTech["name"],
    };
  }

  Future<void> fetchFullyBookedTimes(DateTime date, {required bool isInstallation}) async {
  final techSnapshot = await firestore
      .collection("technicians")
      .where("isActive", isEqualTo: true)
      .get();

  final techCount = techSnapshot.docs.length;

  final dateStart = DateTime(date.year, date.month, date.day);
  final dateEnd = dateStart.add(Duration(days: 1));

  final bookings = await firestore
      .collection("service_requests")
      .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
      .where("date", isLessThan: Timestamp.fromDate(dateEnd))
      .get();

  Map<String, int> timeCount = {};
  for (var doc in bookings.docs) {
    final t = doc["time"] as String?;
    if (t != null) {
      timeCount[t] = (timeCount[t] ?? 0) + 1;
    }
  }

  final fullyBooked = timeCount.entries
      .where((e) => e.value >= techCount)
      .map((e) => e.key)
      .toSet();

  setState(() {
    if (isInstallation) {
      iFullyBookedTimes = fullyBooked;
    } else {
      rFullyBookedTimes = fullyBooked;
    }
  });
}

  List<String> getAvailableTimes(String? selectedDate, Set<String> fullyBookedTimes) {
  final allTimes = ["8:00 AM", "10:00 AM", "1:00 PM", "3:00 PM", "5:00 PM"];

  if (selectedDate == null || selectedDate.isEmpty) return allTimes;

  final picked = DateFormat("MM/dd/yyyy").parse(selectedDate);
  final now = DateTime.now();
  final isToday = picked.year == now.year &&
                  picked.month == now.month &&
                  picked.day == now.day;

  final timeFormats = {
    "8:00 AM":  DateTime(now.year, now.month, now.day, 8, 0),
    "10:00 AM": DateTime(now.year, now.month, now.day, 10, 0),
    "1:00 PM":  DateTime(now.year, now.month, now.day, 13, 0),
    "3:00 PM":  DateTime(now.year, now.month, now.day, 15, 0),
    "5:00 PM":  DateTime(now.year, now.month, now.day, 17, 0),
  };

  return allTimes.where((t) {
    if (fullyBookedTimes.contains(t)) return false;
    if (isToday && timeFormats[t]!.isBefore(now)) return false;
    return true;
  }).toList();
}

  // reset
  Future<void> resetIfNewDay(DocumentSnapshot techDoc, DateTime today) async {
  final data = techDoc.data() as Map<String, dynamic>;

  String todayStr = today.toString().split(" ")[0];

  if (data["lastAssignedDate"] == null ||
      data["lastAssignedDate"] != todayStr) {

    await firestore.collection("technicians").doc(techDoc.id).update({
      "todayJobCount": 0,
      "lastAssignedDate": todayStr,
    });
  }
}

  // submit installation
  Future<void> submitInstallationRequest() async {

  if (_installationFormKey.currentState!.validate()) {
    setState(() => isLoading = true);

    try {

    String requestId = await generateServiceRequestId();
    final pickedDate = DateFormat("MM/dd/yyyy").parse(iDateController.text);
    final technician = await autoAssignTechnician(pickedDate, iSelectedTime!);

    await firestore.collection("service_requests").add({
      "requestId": requestId,
      "serviceType": "Installation",

      "technicianId": technician?["technicianId"] ?? "UNASSIGNED",
      "technicianName": technician?["technicianName"] ?? "Unassigned",

      "name": iNameController.text.trim(),
      "mobileNumber": iMobileController.text.trim(),
      "email": iEmailController.text.trim(),

      "acType": iSelectedType,
      "productName": iSelectedProduct,
      "productPrice": iSelectedPrice,
      "totalPrice": iSelectedPrice + installationFee,

      "date": Timestamp.fromDate(
        DateFormat("MM/dd/yyyy").parse(iDateController.text),
      ),
      "time": iSelectedTime,

      "address": iAddressController.text.trim(),

      "paymentMethod": iPaymentMethod,
      "paymentStatus": iPaymentMethod == "GCash" ? "Unpaid" : "Cash on Service",
      "status": "Pending",
      "timestamp": FieldValue.serverTimestamp(),
    });

    await fetchInstallationProducts();

    if (technician != null) {
      await firestore.collection("technicians")
        .doc(technician["technicianId"])
        .update({"todayJobCount": FieldValue.increment(1)});
    }

    if (iPaymentMethod == "GCash") {
      await _initiateGcashPayment(
        amount: iSelectedPrice + installationFee,
        name: iNameController.text.trim(),
        email: iEmailController.text.trim(),
        phone: iMobileController.text.trim(),
        requestId: requestId,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Installation request submitted successfully")),
        );
      }
    }

    if (mounted) setState(() => showInstallationForm = false);
    clearInstallationFields();
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }
}

  // submit repair & maintenance form
Future<void> submitRepairRequest() async {

  if (_repairFormKey.currentState!.validate()) {
    setState(() => isLoading = true);

    try {

    String requestId = await generateServiceRequestId();
    final pickedDate = DateFormat("MM/dd/yyyy").parse(rDateController.text);
    final technician = await autoAssignTechnician(pickedDate, rSelectedTime!);

    await firestore.collection("service_requests").add({
      
      "requestId": requestId,
      "serviceType": "Repair & Maintenance",

      "technicianId": technician?["technicianId"] ?? "UNASSIGNED",
      "technicianName": technician?["technicianName"] ?? "Unassigned",

      "name": rNameController.text.trim(),
      "mobileNumber": rMobileController.text.trim(),
      "email": rEmailController.text.trim(),

      "acType": rSelectedType,
      "productName": rSelectedProduct,
      "totalPrice": repairFee,

      "date": Timestamp.fromDate(
        DateFormat("MM/dd/yyyy").parse(rDateController.text),
      ),
      "time": rSelectedTime,

      "address": rAddressController.text.trim(),

      "description": rDescriptionController.text.trim(),

      "paymentMethod": rPaymentMethod,
      "paymentStatus": rPaymentMethod == "GCash" ? "Unpaid" : "Cash on Service",
      "status": "Pending",

      "timestamp": FieldValue.serverTimestamp(),
    });

    if (technician != null) {
      await firestore.collection("technicians")
        .doc(technician["technicianId"])
        .update({"todayJobCount": FieldValue.increment(1)});
    }

    if (rPaymentMethod == "GCash") {
      await _initiateGcashPayment(
        amount: repairFee,
        name: rNameController.text.trim(),
        email: rEmailController.text.trim(),
        phone: rMobileController.text.trim(),
        requestId: requestId,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Repair request submitted successfully")),
        );
      }
    }

    if (mounted) setState(() => showRepairForm = false);
    clearRepairFields();
  }
  catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }
}

void clearInstallationFields() {
  iNameController.clear();
  iMobileController.clear();
  iEmailController.clear();
  iDateController.clear();
  iAddressController.clear();

  iSelectedType = null;
  iSelectedProduct = null;
  iSelectedTime = null;
  iPaymentMethod = null;
  iSelectedPrice = 0.0;
}

Future<void> _initiateGcashPayment({
  required double amount,
  required String name,
  required String email,
  required String phone,
  required String requestId,
}) async {
  try {
    final secret = dotenv.env['XENDIT_SECRET_KEY'] ?? '';
    final encoded = base64Encode(utf8.encode('$secret:'));

    String formattedPhone = phone.trim();

    formattedPhone = formattedPhone.replaceAll(" ", "");

    if (formattedPhone.startsWith("09")) {
      formattedPhone = "+63${formattedPhone.substring(1)}";
    }

    else if (formattedPhone.startsWith("9")) {
      formattedPhone = "+63$formattedPhone";
    }

    final response = await http.post(
      Uri.parse('https://api.xendit.co/ewallets/charges'),
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reference_id': requestId,
        'currency': 'PHP',
        'amount': amount,
        'checkout_method': 'ONE_TIME_PAYMENT',
        'channel_code': 'PH_GCASH',
        'channel_properties': {
          'success_redirect_url': '${Uri.base.origin}/close.html', 
          'failure_redirect_url': '${Uri.base.origin}/close.html', 
        },
        'metadata': {
          'requestId': requestId,
          'name': name,
          'email': email,
          'phone': formattedPhone,
        },
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final chargeId = data['id'];

      final actions = data['actions'];
      final checkoutUrl = actions['desktop_web_checkout_url']
          ?? actions['mobile_web_checkout_url']
          ?? '';

      if (checkoutUrl.isNotEmpty && await canLaunchUrl(Uri.parse(checkoutUrl))) {
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        final snapshot = await firestore
            .collection('service_requests')
            .where('requestId', isEqualTo: requestId)
            .get();

        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update({
            'xenditChargeId': chargeId,
          });
        }

        _pendingChargeId = chargeId;
        _pendingRequestId = requestId;
        _waitingForPayment = true;

      } else {
        throw Exception('Could not open GCash checkout URL.');
      }
    } else {
      throw Exception(jsonDecode(response.body).toString());
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GCash error: $e")),
      );
    }
  }
}

Future<void> verifyXenditPayment(String chargeId, String requestId) async {
  try {
    final secret = dotenv.env['XENDIT_SECRET_KEY'] ?? '';
    final encoded = base64Encode(utf8.encode('$secret:'));

    final res = await http.get(
      Uri.parse('https://api.xendit.co/ewallets/charges/$chargeId'),
      headers: {'Authorization': 'Basic $encoded'},
    );

    final data = jsonDecode(res.body);
    final status = data['status'];

    if (status == 'SUCCEEDED') {
      final snapshot = await firestore
          .collection('service_requests')
          .where('requestId', isEqualTo: requestId)
          .where('paymentMethod', isEqualTo: 'GCash')
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({'paymentStatus': 'Paid'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("GCash payment confirmed!")),
        );
      }
    } else if (status == 'FAILED') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("GCash payment failed. Please try again.")),
        );
      }
    }
  } catch (e) {
    debugPrint('Xendit verify error: $e');
  }
}

List<Map<String, dynamic>> getFilteredProducts() {
  if (iSelectedType == null) return iAllProducts;

  return iAllProducts.where((p) {
    return (p['type'] ?? '').toString().toLowerCase().trim() ==
           iSelectedType!.toLowerCase().trim();
  }).toList();
}

Future<void> fetchInstallationProducts() async {
  final snap = await firestore.collection('products').get();
  setState(() {
    iAllProducts = snap.docs.map((doc) {
      final d = doc.data();
      return {
        'name': d['name'] ?? '',
        'price': (d['price'] as num?)?.toDouble() ?? 0.0,
        'type': d['type'] ?? '',
        'stockQuantity': d['stockQuantity'] ?? 0,
      };
    }).toList();
  });
}

Future<void> fetchRepairProducts() async {
  final snap = await firestore.collection('products').get();
  setState(() {
    rAllProducts = snap.docs.map((doc) {
      final d = doc.data();
      return {
        'name': d['name'] ?? '',
        'price': (d['price'] as num?)?.toDouble() ?? 0.0,
        'type': d['type'] ?? '',
        'stockQuantity': d['stockQuantity'] ?? 0,
      };
    }).toList();
  });
}

List<Map<String, dynamic>> getFilteredRepairProducts() {
  if (rSelectedType == null) return rAllProducts;
  return rAllProducts.where((p) {
    return (p['type'] ?? '').toString().toLowerCase().trim() ==
           rSelectedType!.toLowerCase().trim();
  }).toList();
}

void clearRepairFields() {
  rNameController.clear();
  rMobileController.clear();
  rEmailController.clear();
  rDateController.clear();
  rAddressController.clear();
  rDescriptionController.clear();

  rSelectedType = null;
  rSelectedProduct = null;
  rSelectedTime = null;
  rPaymentMethod = null;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),

      body: SizedBox.expand(
        child: Stack(
          children: [
  
          Align(
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Padding(
              padding: EdgeInsets.only(left: 70, top: 50),
              child: Text("AIR-CONDITIONING  SERVICES", style: TextStyle(fontSize: 25, fontFamily: "Changa One")),
          ),

          SizedBox(height: 70),

          Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //installation card
              GestureDetector(
              onTap: () {
                setState(() {
                  showInstallationForm = true;
                });
                fetchInstallationProducts();
              },

              child: HoverCard(
                child: Container(
                width: 500,
                height: 425,
                decoration: BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(25),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 30),
                    Icon(Icons.ac_unit, size: 50, color: Color(0xFF013B7A)),
                    SizedBox(height: 12),
                    Text("Installation", style: TextStyle(fontSize: 25, fontFamily: "Changa One", color: Color(0xFF013B7A))),
                    SizedBox(height: 40),
                    Text("Professional setup for your new cooling units to ensure", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                    SizedBox(height: 5),
                    Text("maximum efficiency and long-term performance.", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                    SizedBox(height: 50),

                    Padding(
                    padding: EdgeInsets.only(left: 95),
                    child: Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),
                            SizedBox(width: 8),
                            Text("Handles both Small & Big AC types", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),

                      SizedBox(height: 10),

                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),

                            SizedBox(width: 8),
                            Text("Proper unit sizing and placement", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),

                      SizedBox(height: 10),

                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),

                            SizedBox(width: 8),
                            Text("Safe and certified installation", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),

                      SizedBox(height: 10),

                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),

                            SizedBox(width: 8),
                            Text("System testing and performance check", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),
                    ],
                  ),
                    ),
                    ),
                  ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: 100),

              //repair card
              GestureDetector(
              onTap: () {
                setState(() {
                  showRepairForm = true;
                });
                fetchRepairProducts();
              },

              child: HoverCard(
                child: Container(
                  width: 500,
                  height: 425,
                  decoration: BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(25),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 30),
                    Icon(Icons.home_repair_service, size: 50, color: Color(0xFF013B7A)),
                    SizedBox(height: 12),
                    Text("Repair & Maintenance", style: TextStyle(fontSize: 25, fontFamily: "Changa One", color: Color(0xFF013B7A))),
                    SizedBox(height: 40),
                    Text("Fast diagnostics and reliable servicing to restore cooling", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                    SizedBox(height: 5),
                    Text("performance and prevent future issues.", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                    SizedBox(height: 50),

                    Padding(
                    padding: EdgeInsets.only(left: 100),
                    child: Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),
                            SizedBox(width: 8),
                            Text("Cleaning and preventive maintenance", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),

                      SizedBox(height: 10),

                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),

                            SizedBox(width: 8),
                            Text("Repair of faulty components", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),

                      SizedBox(height: 10),

                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Icon(Icons.check),
                            ),

                          SizedBox(width: 8),
                          Text("Performance inspection and testing",style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                          ],
                        ),
                    ],
                ),
                  ),
                ),
                ],
                    ),
                  ),
                ),
              )
              ],
            ),
          ),
        ],
      ),
      ),

      // installation form
      if (showInstallationForm)
      Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),

        child: Center(
          child: Container(
          width: 950,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: EdgeInsets.all(30),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),

          child: Stack(
            children: [

              // close button
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      showInstallationForm = false;
                    });
                    clearInstallationFields();
                  },
                ),
              ),

              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Form(
                          key: _installationFormKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Text("Service Request", style: TextStyle(fontSize: 20, fontFamily: "Changa One"))
                              ),
                              SizedBox(height: 5),
                              Center(
                                child: Text("Installation", style: TextStyle(fontSize: 18, fontFamily: "Arimo", color: Color(0xFF013B7A), fontWeight: FontWeight.bold)),
                              ),
                              SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: iNameController,
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
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: iMobileController,
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
                                  ),
                                ],
                              ),

                              SizedBox(height: 10),

                              TextFormField(
                                controller: iEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: "Email Address",
                                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Email is required";
                                  }
                                  if (!RegExp(r'^[\w\.-]+@gmail\.com$').hasMatch(value.trim())) {
                                    return "Invalid Gmail format";
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField2<String>(
                                      value: iSelectedType,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null) return "AC Type is required";
                                        return null;
                                      },
                                      hint: Text("AC Type", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                      items: ["Split Type", "Window Type", "Portable", "Central Air", "Ductless Mini-splits"]
                                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                          .toList(),
                                      onChanged: (value) {
                                      setState(() {
                                        iSelectedType = value;
                                        iSelectedProduct = null;
                                        iSelectedPrice = 0.0;
                                      });
                                    },
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField2<String>(
                                      value: iSelectedProduct,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null) return "Product Name is required";
                                        return null;
                                      },
                                      hint: Text("Product Name", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                      items: getFilteredProducts().map((p) {
                                        return DropdownMenuItem<String>(
                                          value: p['name'] as String,
                                          child: Text(p['name'] as String, style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                        );
                                      }).toList(),
                                      onChanged: iSelectedType == null
                                      ? null
                                      : (value) {
                                          setState(() {
                                            iSelectedProduct = value;

                                            final matched = iAllProducts.firstWhere(
                                              (p) => p['name'] == value,
                                            );

                                            iSelectedPrice = (matched['price'] as num).toDouble();
                                          });
                                        },
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: iDateController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        labelText: "Preferred Date",
                                        labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.calendar_today),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return "Date is required";
                                        return null;
                                      },
                                      onTap: () async {
                                        DateTime? pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            iDateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                                            iSelectedTime = null;
                                          });
                                          await fetchFullyBookedTimes(pickedDate, isInstallation: true);
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField2<String>(
                                      value: iSelectedTime,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null) return "Time is required";
                                        return null;
                                      },
                                      hint: Text("Preferred Time", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                      items: getAvailableTimes(iDateController.text, iFullyBookedTimes)
                                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          iSelectedTime = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 10),

                              TextFormField(
                                controller: iAddressController,
                                decoration: InputDecoration(
                                  labelText: "Complete Address",
                                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return "Address is required";
                                  return null;
                                },
                              ),

                              SizedBox(height: 10),

                              DropdownButtonFormField2<String>(
                                value: iPaymentMethod,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null) return "Payment method is required";
                                  return null;
                                },
                                hint: Text("Payment Method", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                items: ["Cash on Service", "GCash"]
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    iPaymentMethod = value;
                                  });
                                },
                              ),

                              SizedBox(height: 15),

                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mail, size: 20),
                                    SizedBox(width: 10),
                                    Text("All receipt and technician updates will be sent to your email.", style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
                                  ],
                                ),
                              ),

                              SizedBox(height: 15),

                              Container(
                                width: double.maxFinite,
                                height: 45,
                                child: ElevatedButton(
                                  onPressed: submitInstallationRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF013B7A),
                                    elevation: 8,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text("SUBMIT", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 30),

                    Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Service Summary", style: TextStyle(fontSize: 16, fontFamily: "Changa One", color: Color(0xFF013B7A))),
                            SizedBox(height: 16),
                            Divider(),
                            SizedBox(height: 12),

                            Text("Product", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                            SizedBox(height: 4),
                            Text(
                              iSelectedProduct ?? "—",
                              style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                            ),

                            SizedBox(height: 16),

                            Text("AC Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                            SizedBox(height: 4),
                            Text(
                              iSelectedType ?? "—",
                              style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                            ),

                            SizedBox(height: 16),

                            Text("Payment Method", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                            SizedBox(height: 4),
                            Text(
                              iPaymentMethod ?? "—",
                              style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                            ),

                            SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("AC Price", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                Text(
                                  iSelectedProduct != null ? "₱${iSelectedPrice.toStringAsFixed(0)}" : "₱0",
                                  style: TextStyle(fontSize: 13, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),

                            SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Installation Fee", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                Text(
                                  "₱${installationFee.toStringAsFixed(0)}",
                                  style: TextStyle(fontSize: 13, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),

                            SizedBox(height: 20),
                            Divider(),
                            SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Price", style: TextStyle(fontSize: 15, fontFamily: "Changa One")),
                                Text(
                                  iSelectedProduct != null
                                      ? "₱${(iSelectedPrice + installationFee).toStringAsFixed(0)}"
                                      : "₱${installationFee.toStringAsFixed(0)}",
                                  style: TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFF013B7A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    )
                  ],
                ),
              ),
            ],
          ),
          )
          )
          ),
      ),

      if (showRepairForm)
      Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: Container(
              width: 950,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [

                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          showRepairForm = false;
                        });
                        clearRepairFields();
                      },
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Form(
                              key: _repairFormKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Center(
                                    child: Text("Service Request", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),
                                  ),
                                  SizedBox(height: 5),
                                  Center(
                                    child: Text("Repair & Maintenance", style: TextStyle(fontSize: 18, fontFamily: "Arimo", color: Color(0xFF013B7A), fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(height: 10),
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lightbulb, size: 15, color: Colors.yellow),
                                        SizedBox(width: 8),
                                        Text("Tip: Try our AI Chatbox for instant troubleshooting before requesting service!", style: TextStyle(fontSize: 10, fontFamily: "Arimo")),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: rNameController,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                                          ],
                                          decoration: InputDecoration(
                                            labelText: "Name",
                                            labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) return "Name is required";
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: rMobileController,
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
                                            if (value == null || value.trim().isEmpty) return "Mobile number is required";
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 10),

                                  TextFormField(
                                    controller: rEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: "Email Address",
                                      labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return "Email is required";
                                      if (!RegExp(r'^[\w\.-]+@gmail\.com$').hasMatch(value.trim())) return "Invalid Gmail format";
                                      return null;
                                    },
                                  ),

                                  SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField2<String>(
                                          value: rSelectedType,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value == null) return "AC Type is required";
                                            return null;
                                          },
                                          hint: Text("AC Type", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                          items: ["Split Type", "Window Type", "Portable", "Central Air", "Ductless Mini-splits"]
                                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              rSelectedType = value;
                                              rSelectedProduct = null;
                                            });
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField2<String>(
                                          value: rSelectedProduct,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value == null) return "Product Name is required";
                                            return null;
                                          },
                                          hint: Text("Product Name", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                          items: getFilteredRepairProducts().map((p) {
                                            return DropdownMenuItem<String>(
                                              value: p['name'] as String,
                                              child: Text(p['name'] as String, style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                            );
                                          }).toList(),
                                          onChanged: rSelectedType == null
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    rSelectedProduct = value;
                                                  });
                                                },
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: rDateController,
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            labelText: "Preferred Date",
                                            labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                            border: OutlineInputBorder(),
                                            suffixIcon: Icon(Icons.calendar_today),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) return "Date is required";
                                            return null;
                                          },
                                          onTap: () async {
                                            DateTime? pickedDate = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(2100),
                                            );
                                            if (pickedDate != null) {
                                              setState(() {
                                                rDateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                                                rSelectedTime = null;
                                              });
                                              await fetchFullyBookedTimes(pickedDate, isInstallation: false);
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField2<String>(
                                          value: rSelectedTime,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value == null) return "Time is required";
                                            return null;
                                          },
                                          hint: Text("Preferred Time", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                          items: getAvailableTimes(rDateController.text, rFullyBookedTimes)
                                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              rSelectedTime = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 10),

                                  TextFormField(
                                    controller: rAddressController,
                                    decoration: InputDecoration(
                                      labelText: "Complete Address",
                                      labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return "Address is required";
                                      return null;
                                    },
                                  ),

                                  SizedBox(height: 10),

                                  TextFormField(
                                    controller: rDescriptionController,
                                    decoration: InputDecoration(
                                      labelText: "Description",
                                      labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return "Description is required";
                                      return null;
                                    },
                                  ),

                                  SizedBox(height: 10),

                                  DropdownButtonFormField2<String>(
                                    value: rPaymentMethod,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null) return "Payment method is required";
                                      return null;
                                    },
                                    hint: Text("Payment Method", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                    items: ["Cash on Service", "GCash"]
                                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        rPaymentMethod = value;
                                      });
                                    },
                                  ),

                                  SizedBox(height: 15),

                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.mail, size: 20),
                                        SizedBox(width: 10),
                                        Text("All receipt and technician updates will be sent to your email.", style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 15),

                                  Container(
                                    width: double.maxFinite,
                                    height: 45,
                                    child: ElevatedButton(
                                      onPressed: submitRepairRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF013B7A),
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ),
                                      child: isLoading
                                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                          : Text("SUBMIT", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 30),

                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: EdgeInsets.only(top: 115),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Service Summary", style: TextStyle(fontSize: 16, fontFamily: "Changa One", color: Color(0xFF013B7A))),
                                  SizedBox(height: 16),
                                  Divider(),
                                  SizedBox(height: 12),

                                  Text("Product", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                  SizedBox(height: 4),
                                  Text(
                                    rSelectedProduct ?? "—",
                                    style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                                  ),

                                  SizedBox(height: 16),

                                  Text("AC Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                  SizedBox(height: 4),
                                  Text(
                                    rSelectedType ?? "—",
                                    style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                                  ),

                                  SizedBox(height: 16),

                                  Text("Payment Method", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                  SizedBox(height: 4),
                                  Text(
                                    rPaymentMethod ?? "—",
                                    style: TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold),
                                  ),

                                  SizedBox(height: 16),

                                  SizedBox(height: 20),
                                  Divider(),
                                  SizedBox(height: 12),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Repair/Maintenance Fee", style: TextStyle(fontSize: 15, fontFamily: "Changa One")),
                                      Text(
                                        "₱${repairFee.toStringAsFixed(0)}",
                                        style: TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFF013B7A)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ]
      )
      )
    );
  }
}

//hover
class HoverCard extends StatefulWidget {
  final Widget child;

  const HoverCard({
    super.key,
    required this.child,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          isHovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          isHovering = false;
        });
      },

      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),

        transform: Matrix4.translationValues(
          0,
          isHovering ? -15 : 0,
          0,
        ),

        child: widget.child,
      ),
    );
  }
}