import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  Timer? _paymentPollTimer;
  StreamSubscription<web.Event>? _webVisibilitySubscription;
  ScaffoldMessengerState? _scaffoldMessenger;


  Set<String> iFullyBookedTimes = {};
  Set<String> rFullyBookedTimes = {};
  int totalTechnicians = 0;

  final ScrollController _installationScrollController = ScrollController();
  final ScrollController _repairScrollController = ScrollController();

  final _installationFormKey = GlobalKey<FormState>();
  final _repairFormKey = GlobalKey<FormState>();

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

  double installationFee = 0.0;
  double repairFee = 0.0;

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

    if (kIsWeb) {
      _webVisibilitySubscription =
          web.document.onVisibilityChange.listen((_) {
        final visible = web.document.visibilityState == 'visible';
        if (visible && _waitingForPayment) {
          _onUserReturned();
        }
      });
    }
  }

  @override
  void dispose() {
    _installationScrollController.dispose();
    _repairScrollController.dispose();
    _paymentPollTimer?.cancel();
    _webVisibilitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPayment) {
      _onUserReturned();
    }
  }

  void _onUserReturned() {
    if (_pendingChargeId == null || _pendingRequestId == null) return;

    _paymentPollTimer?.cancel();

    verifyXenditPayment(_pendingChargeId!, _pendingRequestId!).then((_) {
      if (_waitingForPayment) {
        int pollCount = 0;
        const maxPolls = 120;
        _paymentPollTimer =
            Timer.periodic(const Duration(seconds: 1), (timer) async {
          pollCount++;
          if (!_waitingForPayment || pollCount >= maxPolls) {
            timer.cancel();
            return;
          }
          await verifyXenditPayment(_pendingChargeId!, _pendingRequestId!);
        });
      }
    });
  }

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
      "serviceFee": installationFee,
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
      if (mounted) {
        _scaffoldMessenger = ScaffoldMessenger.of(context);
        setState(() => showInstallationForm = false);
        clearInstallationFields();
      }
      await _initiateGcashPayment(
        amount: iSelectedPrice + installationFee,
        name: iNameController.text.trim(),
        email: iEmailController.text.trim(),
        phone: iMobileController.text.trim(),
        requestId: requestId,
      );
    } else {
      if (mounted) {
        setState(() => showInstallationForm = false);
        clearInstallationFields();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Installation request submitted successfully")),
        );
      }
    }
    }
    catch (e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }
}

Future<void> submitRepairRequest() async {

  if (_repairFormKey.currentState!.validate()) {
    setState(() => isLoading = true);

    try {

    String requestId = await generateServiceRequestId();
    final pickedDate = DateFormat("MM/dd/yyyy").parse(rDateController.text);
    final technician = await autoAssignTechnician(pickedDate, rSelectedTime!);

    await firestore.collection("service_requests").add({
      
      "requestId": requestId,
      "serviceType": "Repair",

      "technicianId": technician?["technicianId"] ?? "UNASSIGNED",
      "technicianName": technician?["technicianName"] ?? "Unassigned",

      "name": rNameController.text.trim(),
      "mobileNumber": rMobileController.text.trim(),
      "email": rEmailController.text.trim(),

      "acType": rSelectedType,
      "productName": rSelectedProduct,
      "serviceFee": repairFee,
      "totalPrice": repairFee,

      "date": Timestamp.fromDate(DateFormat("MM/dd/yyyy").parse(rDateController.text)),
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
      if (mounted) {
        _scaffoldMessenger = ScaffoldMessenger.of(context);
        setState(() => showRepairForm = false);
        clearRepairFields();
      }
      await _initiateGcashPayment(
        amount: repairFee,
        name: rNameController.text.trim(),
        email: rEmailController.text.trim(),
        phone: rMobileController.text.trim(),
        requestId: requestId,
      );
    } else {
      if (mounted) {
        setState(() => showRepairForm = false);
        clearRepairFields();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Repair request submitted successfully")),
        );
      }
    }
  }
  catch (e) {
    if(!mounted) return;
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
        launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

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

        _paymentPollTimer?.cancel();
        int pollCount = 0;
        const maxPolls = 120;
        _paymentPollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          pollCount++;
          if (!_waitingForPayment || pollCount >= maxPolls) {
            timer.cancel();
            return;
          }
          await verifyXenditPayment(_pendingChargeId!, _pendingRequestId!);
        });

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
      _paymentPollTimer?.cancel();
      if (!_waitingForPayment) return; 
      _waitingForPayment = false;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF013B7A), size: 28),
                SizedBox(width: 10),
                Text("Payment Confirmed",
                    style: TextStyle(fontFamily: "Changa One", fontSize: 18)),
              ],
            ),
            content: const Text(
              "Your GCash payment was successful!\nA receipt has been sent to your email.",
              style: TextStyle(fontFamily: "Arimo", fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK",
                    style: TextStyle(
                        fontFamily: "Arimo",
                        color: Color(0xFF013B7A),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text("GCash payment confirmed! Receipt sent to your email.")),
        );
      }

      final snapshot = await firestore
          .collection('service_requests')
          .where('requestId', isEqualTo: requestId)
          .where('paymentMethod', isEqualTo: 'GCash')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docRef = snapshot.docs.first.reference;
        final docData = snapshot.docs.first.data();

        await docRef.update({
          'paymentStatus': 'Paid',
          'status': 'Approved',
        });

        if ((docData['serviceType'] ?? '') == 'Installation' &&
            (docData['productName'] ?? '').isNotEmpty) {
          final productQuery = await firestore
              .collection('products')
              .where('name', isEqualTo: docData['productName'])
              .get();

          if (productQuery.docs.isNotEmpty) {
            await productQuery.docs.first.reference.update({
              'stockQuantity': FieldValue.increment(-1),
            });
          }
        }

        final counterRef = firestore.collection('counters').doc('receipts');
        int receiptNumber = 1;
        await firestore.runTransaction((transaction) async {
          final counterSnap = await transaction.get(counterRef);
          if (!counterSnap.exists) {
            transaction.set(counterRef, {'lastNumber': 1});
            receiptNumber = 1;
          } else {
            receiptNumber = (counterSnap['lastNumber'] ?? 0) + 1;
            transaction.update(counterRef, {'lastNumber': receiptNumber});
          }
        });

        const serverUrl = 'http://localhost:8080';
        await http.post(
          Uri.parse('$serverUrl/email/approve'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestId': requestId,
            'name': docData['name'] ?? '',
            'email': docData['email'] ?? '',
            'paymentStatus': 'Paid',
            'paymentMethod': 'GCash',
            'serviceType': docData['serviceType'] ?? '',
            'date': docData['date'] != null
                ? DateFormat('MM/dd/yyyy').format((docData['date'] as Timestamp).toDate())
                : '',
            'time': docData['time'] ?? '',
            'address': docData['address'] ?? '',
            'serviceFee': docData['serviceFee'] ?? 0,
            'totalPrice': docData['totalPrice'] ?? 0,
            'productName': docData['productName'] ?? '',
            'productPrice': docData['productPrice'] ?? 0,
            'description': docData['description'] ?? '',
            'xenditChargeId': chargeId,
            'receiptNumber': receiptNumber,
          }),
        );
      }
    } else if (status == 'FAILED') {
      _waitingForPayment = false;
      _paymentPollTimer?.cancel();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text("Payment Failed",
                    style: TextStyle(fontFamily: "Changa One", fontSize: 18)),
              ],
            ),
            content: const Text(
              "Your GCash payment could not be completed. Please try again.",
              style: TextStyle(fontFamily: "Arimo", fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Close",
                    style: TextStyle(
                        fontFamily: "Arimo",
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text("GCash payment failed. Please try again.")),
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
        'installationFee': (d['installationFee'] as num?)?.toDouble() ?? 0.0,
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
        'repairFee': (d['repairFee'] as num?)?.toDouble() ?? 0.0,
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

  Widget _buildResponsiveRow(bool isDesktop, Widget child1, Widget child2) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child1),
          const SizedBox(width: 10),
          Expanded(child: child2),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child1,
        const SizedBox(height: 10),
        child2,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final cardWidth = isDesktop ? 500.0 : screenWidth * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isDesktop ? 70 : 0, top: 50),
                      child: isDesktop
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text("AIR-CONDITIONING  SERVICES",
                                  style: TextStyle(fontSize: 25, fontFamily: "Changa One")),
                            )
                          : Center(
                              child: Text("AIR-CONDITIONING  SERVICES",
                                  style: TextStyle(fontSize: 25, fontFamily: "Changa One"),
                                  textAlign: TextAlign.center),
                            ),
                    ),
                    SizedBox(height: isDesktop ? 70 : 40),

                    isDesktop
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildInstallationCard(isDesktop, cardWidth),
                              const SizedBox(width: 100),
                              _buildRepairCard(isDesktop, cardWidth),
                            ],
                          )
                        : Column(
                            children: [
                              _buildInstallationCard(isDesktop, cardWidth),
                              const SizedBox(height: 40),
                              _buildRepairCard(isDesktop, cardWidth),
                              const SizedBox(height: 40),
                            ],
                          ),
                  ],
                ),
              ),
            ),

            // FORMS
            if (showInstallationForm) _buildInstallationFormDialog(isDesktop, screenWidth),
            if (showRepairForm) _buildRepairFormDialog(isDesktop, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallationCard(bool isDesktop, double cardWidth) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showInstallationForm = true;
        });
        fetchInstallationProducts();
      },
      child: HoverCard(
        child: Container(
          width: cardWidth,
          height: isDesktop ? 425 : null,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.ac_unit, size: 50, color: Color(0xFF013B7A)),
              const SizedBox(height: 12),
              const Text("Installation",
                  style: TextStyle(fontSize: 25, fontFamily: "Changa One", color: Color(0xFF013B7A))),
              const SizedBox(height: 40),
              const Text("Professional setup for your new cooling units to ensure",
                  style: TextStyle(fontSize: 15, fontFamily: "Arimo"), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              const Text("maximum efficiency and long-term performance.",
                  style: TextStyle(fontSize: 15, fontFamily: "Arimo"), textAlign: TextAlign.center),
              const SizedBox(height: 50),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 95 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCheckItem("Handles both Small & Big AC types"),
                    const SizedBox(height: 10),
                    _buildCheckItem("Proper unit sizing and placement"),
                    const SizedBox(height: 10),
                    _buildCheckItem("Safe and certified installation"),
                    const SizedBox(height: 10),
                    _buildCheckItem("System testing and performance check"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepairCard(bool isDesktop, double cardWidth) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showRepairForm = true;
        });
        fetchRepairProducts();
      },
      child: HoverCard(
        child: Container(
          width: cardWidth,
          height: isDesktop ? 425 : null,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.home_repair_service, size: 50, color: Color(0xFF013B7A)),
              const SizedBox(height: 12),
              const Text("Repair",
                  style: TextStyle(fontSize: 25, fontFamily: "Changa One", color: Color(0xFF013B7A))),
              const SizedBox(height: 40),
              const Text("Fast diagnostics and reliable servicing to restore",
                  style: TextStyle(fontSize: 15, fontFamily: "Arimo"), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              const Text("cooling performance.",
                  style: TextStyle(fontSize: 15, fontFamily: "Arimo"), textAlign: TextAlign.center),
              const SizedBox(height: 50),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 110 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCheckItem("Comprehensive system diagnostics"),
                    const SizedBox(height: 10),
                    _buildCheckItem("Repair of faulty components"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 24, child: Icon(Icons.check)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontFamily: "Arimo"))),
      ],
    );
  }

  Widget _buildInstallationFormDialog(bool isDesktop, double screenWidth) {
    final formContent = Form(
      key: _installationFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: Text("Service Request", style: TextStyle(fontSize: 20, fontFamily: "Changa One"))),
          const SizedBox(height: 5),
          const Center(
            child: Text("Installation",
                style: TextStyle(fontSize: 18, fontFamily: "Arimo", color: Color(0xFF013B7A), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),

          _buildResponsiveRow(
            isDesktop,
            TextFormField(
              controller: iNameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
              decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? "Name is required" : null,
            ),
            TextFormField(
              controller: iMobileController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              decoration: const InputDecoration(labelText: "Mobile Number", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Mobile number is required";
                if (value.length != 11) return "Mobile Number must be 11 digits";
                if (!RegExp(r'^09\d{9}$').hasMatch(value)) return "Enter a valid mobile number";
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: iEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: "Email Address", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Email is required";
              if (!RegExp(r'^[\w\.-]+@gmail\.com$').hasMatch(value.trim())) return "Invalid Gmail format";
              return null;
            },
          ),
          const SizedBox(height: 10),

          _buildResponsiveRow(
            isDesktop,
            DropdownButtonFormField2<String>(
              value: iSelectedType,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "AC Type is required" : null,
              hint: const Text("AC Type", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: ["Split Type", "Window Type", "Portable", "Central Air", "Ductless Mini-splits"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {
                setState(() {
                  iSelectedType = value;
                  iSelectedProduct = null;
                  iSelectedPrice = 0.0;
                });
              },
            ),
            DropdownButtonFormField2<String>(
              value: iSelectedProduct,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "Product Name is required" : null,
              hint: const Text("Product Name", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: getFilteredProducts().map((p) => DropdownMenuItem<String>(value: p['name'] as String, child: Text(p['name'] as String, style: const TextStyle(fontSize: 15, fontFamily: "Arimo")))).toList(),
              onChanged: iSelectedType == null ? null : (value) {
                setState(() {
                  iSelectedProduct = value;
                  final matched = iAllProducts.firstWhere((p) => p['name'] == value);
                  iSelectedPrice = (matched['price'] as num).toDouble();
                  installationFee = (matched['installationFee'] as num?)?.toDouble() ?? 0.0;
                });
              },
            ),
          ),
          const SizedBox(height: 10),

          _buildResponsiveRow(
            isDesktop,
            TextFormField(
              controller: iDateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Preferred Date", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              validator: (value) => (value == null || value.isEmpty) ? "Date is required" : null,
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (pickedDate != null) {
                  setState(() {
                    iDateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                    iSelectedTime = null;
                  });
                  await fetchFullyBookedTimes(pickedDate, isInstallation: true);
                }
              },
            ),
            DropdownButtonFormField2<String>(
              value: iSelectedTime,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "Time is required" : null,
              hint: const Text("Preferred Time", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: getAvailableTimes(iDateController.text, iFullyBookedTimes)
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => iSelectedTime = value),
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: iAddressController,
            decoration: const InputDecoration(labelText: "Complete Address", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) => (value == null || value.trim().isEmpty) ? "Address is required" : null,
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField2<String>(
            value: iPaymentMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) => value == null ? "Payment method is required" : null,
            hint: const Text("Payment Method", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
            items: ["Cash on Service", "GCash"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => iPaymentMethod = value),
          ),
          const SizedBox(height: 15),

          Wrap(
            alignment: WrapAlignment.center,
            children: const [
              Icon(Icons.mail, size: 20),
              SizedBox(width: 10),
              Text("All receipt and technician updates will be sent to your email.", style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
            ],
          ),
          const SizedBox(height: 15),

          SizedBox(
            width: double.maxFinite,
            height: 45,
            child: ElevatedButton(
              onPressed: submitInstallationRequest,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF013B7A), elevation: 8, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("SUBMIT", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    final summaryContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Service Summary", style: TextStyle(fontSize: 16, fontFamily: "Changa One", color: Color(0xFF013B7A))),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text("Product", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(iSelectedProduct ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("AC Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(iSelectedType ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("Payment Method", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(iPaymentMethod ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AC Price", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.grey.shade600)),
              Text(iSelectedProduct != null ? "₱${iSelectedPrice.toStringAsFixed(0)}" : "—", style: const TextStyle(fontSize: 13, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Installation Fee", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.grey.shade600)),
              Text(iSelectedProduct != null ? "₱${installationFee.toStringAsFixed(0)}" : "—", style: const TextStyle(fontSize: 13, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Price", style: TextStyle(fontSize: 15, fontFamily: "Changa One")),
              Text(iSelectedProduct != null ? "₱${(iSelectedPrice + installationFee).toStringAsFixed(0)}" : "—",
                  style: const TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFF013B7A))),
            ],
          ),
        ],
      ),
    );

    return _buildDialogOverlay(isDesktop, screenWidth, formContent, summaryContent, () {
      setState(() => showInstallationForm = false);
      clearInstallationFields();
    }, _installationScrollController);
  }

  Widget _buildRepairFormDialog(bool isDesktop, double screenWidth) {
    final formContent = Form(
      key: _repairFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: Text("Service Request", style: TextStyle(fontSize: 20, fontFamily: "Changa One"))),
          const SizedBox(height: 5),
          const Center(child: Text("Repair", style: TextStyle(fontSize: 18, fontFamily: "Arimo", color: Color(0xFF013B7A), fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            children: const [
              Icon(Icons.lightbulb, size: 15, color: Colors.yellow),
              SizedBox(width: 8),
              Text("Tip: Try our AI Chatbox for instant troubleshooting before requesting service!", style: TextStyle(fontSize: 10, fontFamily: "Arimo")),
            ],
          ),
          const SizedBox(height: 20),

          _buildResponsiveRow(
            isDesktop,
            TextFormField(
              controller: rNameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
              decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? "Name is required" : null,
            ),
            TextFormField(
              controller: rMobileController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              decoration: const InputDecoration(labelText: "Mobile Number", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Mobile number is required";
                if (value.length != 11) return "Mobile Number must be 11 digits";
                if (!RegExp(r'^09\d{9}$').hasMatch(value)) return "Enter a valid mobile number";
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: rEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: "Email Address", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Email is required";
              if (!RegExp(r'^[\w\.-]+@gmail\.com$').hasMatch(value.trim())) return "Invalid Gmail format";
              return null;
            },
          ),
          const SizedBox(height: 10),

          _buildResponsiveRow(
            isDesktop,
            DropdownButtonFormField2<String>(
              value: rSelectedType,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "AC Type is required" : null,
              hint: const Text("AC Type", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: ["Split Type", "Window Type", "Portable", "Central Air", "Ductless Mini-splits"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() { rSelectedType = value; rSelectedProduct = null; }),
            ),
            DropdownButtonFormField2<String>(
              value: rSelectedProduct,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "Product Name is required" : null,
              hint: const Text("Product Name", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: getFilteredRepairProducts().map((p) => DropdownMenuItem<String>(value: p['name'] as String, child: Text(p['name'] as String, style: const TextStyle(fontSize: 15, fontFamily: "Arimo")))).toList(),
              onChanged: rSelectedType == null ? null : (value) {
                setState(() {
                  rSelectedProduct = value;
                  final matched = rAllProducts.firstWhere((p) => p['name'] == value);
                  repairFee = (matched['repairFee'] as num?)?.toDouble() ?? 0.0;
                });
              },
            ),
          ),
          const SizedBox(height: 10),

          _buildResponsiveRow(
            isDesktop,
            TextFormField(
              controller: rDateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Preferred Date", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              validator: (value) => (value == null || value.isEmpty) ? "Date is required" : null,
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (pickedDate != null) {
                  setState(() {
                    rDateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                    rSelectedTime = null;
                  });
                  await fetchFullyBookedTimes(pickedDate, isInstallation: false);
                }
              },
            ),
            DropdownButtonFormField2<String>(
              value: rSelectedTime,
              isExpanded: true,
              decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
              validator: (value) => value == null ? "Time is required" : null,
              hint: const Text("Preferred Time", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
              items: getAvailableTimes(rDateController.text, rFullyBookedTimes)
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => rSelectedTime = value),
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: rAddressController,
            decoration: const InputDecoration(labelText: "Complete Address", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) => (value == null || value.trim().isEmpty) ? "Address is required" : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: rDescriptionController,
            decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) => (value == null || value.trim().isEmpty) ? "Description is required" : null,
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField2<String>(
            value: rPaymentMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"), border: OutlineInputBorder()),
            validator: (value) => value == null ? "Payment method is required" : null,
            hint: const Text("Payment Method", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
            items: ["Cash on Service", "GCash"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => rPaymentMethod = value),
          ),
          const SizedBox(height: 15),

          Wrap(
            alignment: WrapAlignment.center,
            children: const [
              Icon(Icons.mail, size: 20),
              SizedBox(width: 10),
              Text("All receipt and technician updates will be sent to your email.", style: TextStyle(fontSize: 13, fontFamily: "Arimo")),
            ],
          ),
          const SizedBox(height: 15),

          SizedBox(
            width: double.maxFinite,
            height: 45,
            child: ElevatedButton(
              onPressed: submitRepairRequest,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF013B7A), elevation: 8, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("SUBMIT", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    final summaryContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Service Summary", style: TextStyle(fontSize: 16, fontFamily: "Changa One", color: Color(0xFF013B7A))),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text("Product", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(rSelectedProduct ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("AC Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(rSelectedType ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("Payment Method", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(rPaymentMethod ?? "—", style: const TextStyle(fontSize: 14, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Repair Fee", style: TextStyle(fontSize: 15, fontFamily: "Changa One")),
              Text(rSelectedProduct != null ? "₱${repairFee.toStringAsFixed(0)}" : "—",
                  style: const TextStyle(fontSize: 20, fontFamily: "Changa One", color: Color(0xFF013B7A))),
            ],
          ),
        ],
      ),
    );

    return _buildDialogOverlay(isDesktop, screenWidth, formContent, summaryContent, () {
      setState(() => showRepairForm = false);
      clearRepairFields();
    }, _repairScrollController);
  }

  Widget _buildDialogOverlay(bool isDesktop, double screenWidth, Widget formContent, Widget summaryContent, VoidCallback onClose, ScrollController scrollController) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Container(
            width: isDesktop ? 950 : screenWidth * 0.95,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            padding: EdgeInsets.all(isDesktop ? 30 : 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
                ),
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: SingleChildScrollView(controller: scrollController, child: formContent)),
                            const SizedBox(width: 30),
                            Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(top: 80), child: summaryContent)),
                          ],
                        )
                      : SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            children: [
                              formContent,
                              const SizedBox(height: 30),
                              summaryContent,
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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