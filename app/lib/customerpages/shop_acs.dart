import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// product model
class _Product {
  final String id;
  final String name;
  final String type;
  final String description;
  final double price;
  final int stockQuantity;
  final String imageUrl;

  const _Product({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.imageUrl,
  });

  factory _Product.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Product(
      id: doc.id,
      name: d['name'] ?? '',
      type: d['type'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      stockQuantity: (d['stockQuantity'] as num?)?.toInt() ?? 0,
      imageUrl: d['imageUrl'] ?? '',
    );
  }
}

class ShopAcs extends StatefulWidget {
  const ShopAcs({super.key});

  @override
  State<ShopAcs> createState() => _ShopAcsState();
}

class _ShopAcsState extends State<ShopAcs> {
  late final CollectionReference _productsRef;

  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Split Type',
    'Window Type',
    'Portable',
    'Central Air',
    'Ductless Mini-splits'
  ];

  @override
  void initState() {
    super.initState();
    _productsRef = FirebaseFirestore.instance.collection('products');
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data     = doc.data() as Map<String, dynamic>;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final stock    = (data['stockQuantity'] as num?)?.toInt() ?? 0;

      switch (_selectedFilter) {
        case 'Split Type':  return type == 'split type';
        case 'Window Type': return type == 'window type';
        case 'Portable':    return type == 'portable';
        case 'Central Air': return type == 'central air';
        case 'Ductless Mini-splits': return type == 'ductless mini-splits';
        case 'In Stock':    return stock > 0;
        default:            return true;
      }
    }).toList();
  }

  void _showProductDetail(_Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        product: product,
        onInquire: () => _openInstallationForm(product),
      ),
    );
  }

  void _openInstallationForm(_Product product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InstallationFormDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F8F8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("PRODUCTS", style: TextStyle(fontFamily: "Changa One", fontSize: 28, color: Color(0xFFdc342c), letterSpacing: 1.2)),

            SizedBox(height: 50),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Filter:", style: TextStyle(fontFamily: "Changa One", fontSize: 16, color: Colors.black87)),
                SizedBox(width: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                      selectedColor: Color(0xFF013b7a),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Color(0xFF013b7a) : Colors.grey.shade300,
                        ),
                      ),
                  labelStyle: TextStyle(
                    fontFamily: "Arimo",
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                );
              }).toList(),
                ),
              ],
            ),

            SizedBox(height: 40),

            // product grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _productsRef
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: Color(0xFF013b7a)),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: Color(0xFFdc342c), size: 40),
                          SizedBox(height: 10),
                          Text("Something went wrong.\nPlease try again later.", textAlign: TextAlign.center, style: TextStyle(fontFamily: "Arimo", color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }

                  final allDocs  = snapshot.data?.docs ?? [];
                  final filtered = _applyFilter(allDocs);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: Colors.grey.shade400),
                          SizedBox(height: 12),
                          Text("No products found.", style: TextStyle(fontFamily: "Arimo", fontSize: 15, color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.only(bottom: 30),
                    gridDelegate:
                    SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.80,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = _Product.fromDoc(filtered[index]);
                      return _ProductCard(
                        product: product,
                        onViewProduct: () => _showProductDetail(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// product card
class _ProductCard extends StatelessWidget {
  final _Product product;
  final VoidCallback onViewProduct;

  const _ProductCard({
    required this.product,
    required this.onViewProduct,
  });

  @override
  Widget build(BuildContext context) {
    final inStock = product.stockQuantity > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius:
                BorderRadius.vertical(top: Radius.circular(14)),
              
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey.shade100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF013b7a),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),

                  // out ofstock
                  if (!inStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text("OUT OF STOCK", style: TextStyle(fontFamily: "Changa One", fontSize: 11, color: Colors.white, letterSpacing: 0.8)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                  // category
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF013b7a).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(product.type, style: TextStyle(fontFamily: "Arimo", fontSize: 10, color: Color(0xFF013b7a), fontWeight: FontWeight.w600)),
                  ),

                  SizedBox(height: 6),

                  // product name
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: "Arimo", fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.3),
                  ),

                  SizedBox(height: 10),

                  // price + view button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("₱${product.price.toStringAsFixed(0)}", style: TextStyle(fontFamily: "Changa One", fontSize: 14, color: Color(0xFF013b7a))),

                      GestureDetector(
                        onTap: onViewProduct,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF013b7a),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("VIEW\nPRODUCT", textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: "Changa One", fontSize: 9, color: Colors.white, height: 1.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(Icons.ac_unit, size: 40, color: Colors.grey),
        ),
      );
}

// product detail
class _ProductDetailSheet extends StatelessWidget {
  final _Product product;
  final VoidCallback? onInquire;

  const _ProductDetailSheet({required this.product, this.onInquire});

  @override
  Widget build(BuildContext context) {
    final inStock = product.stockQuantity > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.9,
      maxChildSize: 1.0,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 10),

            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [

                  // image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            height: 280,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(color: Color(0xFF013b7a)),
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 220,
                            color: Colors.grey.shade100,
                            child: Center(
                              child: Icon(Icons.ac_unit, size: 60, color: Colors.grey),
                            ),
                          ),
                  ),

                  SizedBox(height: 20),

                  // name
                  Text(product.name, style: TextStyle(fontFamily: "Changa One", fontSize: 22, color: Colors.black87)),

                  SizedBox(height: 6),

                  // category & stock
                  Row(
                    children: [
                      _badge(product.type, Color(0xFF013b7a),
                          Color(0xFF013b7a).withValues(alpha: 0.1)),
                      SizedBox(width: 8),
                      _badge(
                        inStock
                            ? '✓ In Stock (${product.stockQuantity})'
                            : '✗ Out of Stock',
                        inStock ? Colors.green.shade700 : Colors.red.shade700,
                        inStock ? Colors.green.shade50  : Colors.red.shade50,
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // price
                  Text("₱${product.price.toStringAsFixed(0)}", style: const TextStyle(fontFamily: "Changa One", fontSize: 26, color: Color(0xFF013b7a))),

                  Divider(height: 30),

                  // description
                  Text("Description", style: TextStyle(fontFamily: "Changa One", fontSize: 16, color: Colors.black87)),
                  SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 160),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Text(product.description.isNotEmpty ? product.description : "No description available.",
                          style: TextStyle(fontFamily: "Arimo", fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                ],
              ),
            ),

            // inquire button
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: inStock ? () {
                    Navigator.pop(context);
                    if (onInquire != null) onInquire!();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF013b7a),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 4,
                  ),
                  child: Text(inStock ? "INQUIRE NOW" : "UNAVAILABLE",
                    style: TextStyle(fontFamily: "Changa One", fontSize: 15, color: Colors.white, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontFamily: "Arimo", fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
      );
}

class _InstallationFormDialog extends StatefulWidget {
  final _Product product;

  const _InstallationFormDialog({required this.product});

  @override
  State<_InstallationFormDialog> createState() => _InstallationFormDialogState();
}

class _InstallationFormDialogState extends State<_InstallationFormDialog> with WidgetsBindingObserver {
  bool isLoading = false;

  Set<String> iFullyBookedTimes = {};

  String? _pendingChargeId;
  String? _pendingRequestId;
  bool _waitingForPayment = false;

  final _formKey = GlobalKey<FormState>();

  final iNameController = TextEditingController();
  final iMobileController = TextEditingController();
  final iEmailController = TextEditingController();
  final iDateController = TextEditingController();
  final iAddressController = TextEditingController();

  String? iSelectedTime;
  String? iPaymentMethod;

  static const double installationFee = 500.0;

  late String? iSelectedProduct;
  late double iSelectedPrice;

  List<Map<String, dynamic>> _allProducts = [];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    iSelectedProduct = widget.product.name;
    iSelectedPrice = widget.product.price;
    _fetchProducts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPayment) {
      _waitingForPayment = false;
      if (_pendingChargeId != null && _pendingRequestId != null) {
        _verifyXenditPayment(_pendingChargeId!, _pendingRequestId!);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    iNameController.dispose();
    iMobileController.dispose();
    iEmailController.dispose();
    iDateController.dispose();
    iAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final snap = await firestore.collection('products').get();
    setState(() {
      _allProducts = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'name': d['name'] ?? '',
          'price': (d['price'] as num?)?.toDouble() ?? 0.0,
          'type': d['type'] ?? '',
        };
      }).toList();
    });
  }

  Future<String> _generateServiceRequestId() async {
    final counterRef = firestore.collection('counters').doc('service_requests');
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastNumber;
      if (!snapshot.exists) {
        lastNumber = 0;
        transaction.set(counterRef, {'lastNumber': 1});
      } else {
        lastNumber = snapshot['lastNumber'];
        transaction.update(counterRef, {'lastNumber': lastNumber + 1});
      }
      int newNumber = lastNumber + 1;
      String year = DateTime.now().year.toString();
      return "SR-$year-${newNumber.toString().padLeft(5, '0')}";
    });
  }

  Future<Map<String, dynamic>?> _autoAssignTechnician(DateTime selectedDate, String selectedTime) async {
    final techSnapshot = await firestore
        .collection("technicians")
        .where("isActive", isEqualTo: true)
        .get();

    if (techSnapshot.docs.isEmpty) return null;

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

  Future<void> _fetchFullyBookedTimes(DateTime date) async {
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
      if (t != null) timeCount[t] = (timeCount[t] ?? 0) + 1;
    }

    final fullyBooked = timeCount.entries
        .where((e) => e.value >= techCount)
        .map((e) => e.key)
        .toSet();

    setState(() {
      iFullyBookedTimes = fullyBooked;
    });
  }

  List<String> _getAvailableTimes() {
    final allTimes = ["8:00 AM", "10:00 AM", "1:00 PM", "3:00 PM", "5:00 PM"];
    if (iDateController.text.isEmpty) return allTimes;

    final picked = DateFormat("MM/dd/yyyy").parse(iDateController.text);
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
      if (iFullyBookedTimes.contains(t)) return false;
      if (isToday && timeFormats[t]!.isBefore(now)) return false;
      return true;
    }).toList();
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

  Future<void> _verifyXenditPayment(String chargeId, String requestId) async {
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

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        String requestId = await _generateServiceRequestId();
        final pickedDate = DateFormat("MM/dd/yyyy").parse(iDateController.text);
        final technician = await _autoAssignTechnician(pickedDate, iSelectedTime!);

        final selectedProductData = _allProducts.firstWhere(
          (p) => p['name'] == iSelectedProduct,
          orElse: () => {'type': widget.product.type, 'price': widget.product.price},
        );

        await firestore.collection("service_requests").add({
          "requestId": requestId,
          "serviceType": "Installation",
          "technicianId": technician?["technicianId"] ?? "UNASSIGNED",
          "technicianName": technician?["technicianName"] ?? "Unassigned",
          "name": iNameController.text.trim(),
          "mobileNumber": iMobileController.text.trim(),
          "email": iEmailController.text.trim(),
          "acType": selectedProductData['type'],
          "productName": iSelectedProduct,
          "productPrice": iSelectedPrice,
          "serviceFee": installationFee,
          "totalPrice": iSelectedPrice + installationFee,
          "date": Timestamp.fromDate(pickedDate),
          "time": iSelectedTime,
          "address": iAddressController.text.trim(),
          "paymentMethod": iPaymentMethod,
          "paymentStatus": iPaymentMethod == "GCash" ? "Unpaid" : "Cash on Service",
          "status": "Pending",
          "timestamp": FieldValue.serverTimestamp(),
        });

        if (technician != null) {
          await firestore
              .collection("technicians")
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
          if (mounted) Navigator.pop(context);
        } else {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Installation request submitted successfully")),
            );
          }
        }
      } catch (e) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }

      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: Container(
          width: 900,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Stack(
            children: [

              // close button
              Positioned(
                right: 10,
                top: 10,
                child: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Center(child: Text("Service Request", style: TextStyle(fontSize: 20, fontFamily: "Changa One"))),
                              SizedBox(height: 5),
                              Center(child: Text("Installation", style: TextStyle(fontSize: 18, fontFamily: "Arimo", color: Color(0xFF013B7A), fontWeight: FontWeight.bold))),
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
                                        if (value == null || value.trim().isEmpty) return "Name is required";
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
                                        if (value == null || value.trim().isEmpty) return "Mobile number is required";
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
                                  if (value == null || value.trim().isEmpty) return "Email is required";
                                  if (!RegExp(r'^[\w\.-]+@gmail\.com$').hasMatch(value.trim())) return "Invalid Gmail format";
                                  return null;
                                },
                              ),

                              SizedBox(height: 10),

                              DropdownButtonFormField2<String>(
                                value: iSelectedProduct,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null) return "Product is required";
                                  return null;
                                },
                                hint: Text("Product Name", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                items: _allProducts.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p['name'] as String,
                                    child: Text(p['name'] as String, style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    iSelectedProduct = value;
                                    final matched = _allProducts.firstWhere(
                                      (p) => p['name'] == value,
                                      orElse: () => {'price': 0.0},
                                    );
                                    iSelectedPrice = (matched['price'] as num).toDouble();
                                  });
                                },
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
                                          await _fetchFullyBookedTimes(pickedDate);
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
                                      items: _getAvailableTimes().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                                items: ["Cash on Service", "GCash"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

                              SizedBox(
                                width: double.maxFinite,
                                height: 45,
                                child: ElevatedButton(
                                  onPressed: _submit,
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

                            Text("Order Summary", style: TextStyle(fontSize: 16, fontFamily: "Changa One", color: Color(0xFF013B7A))),
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

                            Text("Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo", color: Colors.grey.shade600)),
                            SizedBox(height: 4),
                            Text(
                              () {
                                if (iSelectedProduct == null) return "—";
                                final matched = _allProducts.firstWhere(
                                  (p) => p['name'] == iSelectedProduct,
                                  orElse: () => {'type': widget.product.type},
                                );
                                return matched['type'] as String? ?? "—";
                              }(),
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
                                  "₱${iSelectedPrice.toStringAsFixed(0)}",
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
                                  "₱${(iSelectedPrice + installationFee).toStringAsFixed(0)}",
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
        ),
      ),
    );
  }
}