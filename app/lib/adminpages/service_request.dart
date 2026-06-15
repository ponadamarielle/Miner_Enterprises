import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ServiceRequest extends StatefulWidget {
  const ServiceRequest({super.key});

  @override
  State<ServiceRequest> createState() => _ServiceRequestState();
}

class _ServiceRequestState extends State<ServiceRequest> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final ValueNotifier<Map<String, dynamic>?> _selectedEventNotifier =
      ValueNotifier(null);

  Map<String, dynamic>? get _selectedEvent => _selectedEventNotifier.value;
  set _selectedEvent(Map<String, dynamic>? v) => _selectedEventNotifier.value = v;

  Map<DateTime, List<Map<String, dynamic>>> events = {};
  StreamSubscription? _subscription;
  final Set<String> _processingDocIds = {};

  @override
  void initState() {
    super.initState();
    _subscription = listenEvents();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _selectedEventNotifier.dispose();
    super.dispose();
  }

  StreamSubscription listenEvents() {
    return FirebaseFirestore.instance
        .collection('service_requests')
        .snapshots()
        .listen((snapshot) {
      Map<DateTime, List<Map<String, dynamic>>> loaded = {};

      for (var doc in snapshot.docs) {
        if (_processingDocIds.contains(doc.id)) continue;

        final data = doc.data();

        final status = data['status'];
        if (status == 'Cancelled' || status == 'Completed') continue;

        final rawDate = data['date'];

        if (rawDate == null || rawDate is! Timestamp) continue;

        DateTime date = rawDate.toDate();
        DateTime clean = DateTime(date.year, date.month, date.day);

        loaded.putIfAbsent(clean, () => []);
        loaded[clean]!.add({
          ...data,
          'docId': doc.id,
        });
      }

      if (mounted) {
        setState(() {
          events = loaded;
        });
      }
    });
  }

  List<Map<String, dynamic>> getEvents(DateTime day) {
    return events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Color getTextColor(String techId) {
    switch (techId) {
      case "TECH01":
        return Color(0xFFB85C00);
      case "TECH02":
        return Color(0xFF7B1FA2);
      default:
        return Color(0xFF1565C0);
    }
  }

  Color getChipColor(String techId) {
    switch (techId) {
      case "TECH01":
        return Color(0xFFFFE0B2);
      case "TECH02":
        return Color(0xFFE1BEE7);
      default:
        return Color(0xFFDCEAFB);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Pending":
        return Color(0xFFE65100);
      case "Approved":
        return Color(0xFF6A1B9A);
      case "Completed":
        return Color(0xFF2E7D32);
      case "Cancelled":
        return Color(0xFF757575);
      default:
        return Color(0xFFE65100);
    }
  }

  Future<void> _updateStatus(String docId, String newStatus, {Map<String, dynamic>? cachedEvent}) async {
    final firestore = FirebaseFirestore.instance;
    final targetEvent = cachedEvent ?? _selectedEvent;

    final currentStatus = targetEvent?['status'] ?? '';
    final serviceType = targetEvent?['serviceType'] ?? '';
    final productName = targetEvent?['productName'];

    if (mounted && _selectedEvent != null && _selectedEvent!['docId'] == docId) {
      setState(() {
        _selectedEvent = {
          ..._selectedEvent!,
          'status': newStatus,
        };
      });
    }

    await firestore
        .collection('service_requests')
        .doc(docId)
        .update({'status': newStatus});

    if (currentStatus == 'Pending' &&
        newStatus == 'Approved' &&
        serviceType == 'Installation' &&
        productName != null &&
        productName.toString().isNotEmpty) {
      final productQuery = await firestore
          .collection('products')
          .where('name', isEqualTo: productName)
          .limit(1)
          .get();

      if (productQuery.docs.isNotEmpty) {
        await firestore
            .collection('products')
            .doc(productQuery.docs.first.id)
            .update({'stockQuantity': FieldValue.increment(-1)});
      }
    }

    if (newStatus == 'Approved' && targetEvent != null) {
      try {
        final backendUrl = 'http://localhost:8080/email/approve';

        final counterRef = firestore.collection('counters').doc('service_requests');
        int receiptNumber = 1;
        await firestore.runTransaction((transaction) async {
          final snap = await transaction.get(counterRef);
          if (snap.exists) {
            receiptNumber = (snap.data()?['count'] ?? 0) + 1;
          }
          transaction.set(counterRef, {'count': receiptNumber}, SetOptions(merge: true));
        });

        final List<Map<String, dynamic>> serviceItems = [
          {
            'serviceType': targetEvent['serviceType'] ?? '',
            'productName': targetEvent['productName'] ?? '',
            'productPrice': targetEvent['productPrice'] ?? 0,
            'description': targetEvent['description'] ?? '',
          }
        ];

        await http.post(
          Uri.parse(backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestId': targetEvent['requestId'],
            'name': targetEvent['name'],
            'email': targetEvent['email'],
            'address': targetEvent['address'] ?? '',
            'date': DateFormat('MM-dd-yyyy').format((targetEvent['date'] as Timestamp).toDate()),
            'time': targetEvent['time'],
            'technicianName': targetEvent['technicianName'],
            'serviceType': targetEvent['serviceType'] ?? '',
            'productName': targetEvent['productName'] ?? '',
            'productPrice': targetEvent['productPrice'] ?? 0,
            'paymentMethod': targetEvent['paymentMethod'] ?? '',
            'paymentStatus': targetEvent['paymentStatus'] ?? 'Unpaid',
            'xenditChargeId': targetEvent['xenditChargeId'] ?? 'N/A',
            'receiptNumber': receiptNumber,
            'serviceItems': serviceItems
          }),
        );
        debugPrint("Approval email triggered successfully.");
      } catch (e) {
        debugPrint("Failed to trigger approval email: $e");
      }
    }

    if (newStatus == 'Cancelled' && targetEvent != null) {
      try {
        await http.post(
          Uri.parse('http://localhost:8080/email/cancel'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestId': targetEvent['requestId'],
            'name': targetEvent['name'],
            'email': targetEvent['email'],
            'serviceType': targetEvent['serviceType'] ?? '',
            'date': targetEvent['date'] != null
                ? DateFormat('MM-dd-yyyy').format((targetEvent['date'] as Timestamp).toDate())
                : '',
            'time': targetEvent['time'] ?? '',
            'reason': targetEvent['cancelReason'] ?? '',
          }),
        );
        debugPrint('Cancellation email triggered successfully.');
      } catch (e) {
        debugPrint('Failed to trigger cancellation email: \$e');
      }
    }

  }

  Future<void> moveToHistory(String docId, {String status = 'Completed'}) async {
    _processingDocIds.add(docId);

    if (mounted) {
      _selectedEventNotifier.value = null;
      setState(() {
        for (final key in events.keys) {
          events[key]?.removeWhere((e) => e['docId'] == docId);
        }
        events.removeWhere((key, value) => value.isEmpty);
      });
    }

    final doc = await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(docId)
        .get();

    if (!doc.exists) return;

    final eventData = doc.data()!;

    await FirebaseFirestore.instance
        .collection('history')
        .doc(docId)
        .set({
      ...eventData,
      'status': status,
      'completedAt': FieldValue.serverTimestamp(),
    });

  if (status != 'Cancelled') {
      try {
        final List<Map<String, dynamic>> serviceItems = [
          {
            'serviceType': eventData['serviceType'] ?? '',
            'productName': eventData['productName'] ?? '',
            'productPrice': eventData['productPrice'] ?? 0,
            'description': eventData['description'] ?? '',
          }
        ];

        await http.post(
          Uri.parse('http://localhost:8080/email/feedback'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': eventData['email'],
            'requestId': eventData['requestId'],
            'technicianId': eventData['technicianId'],
            'name': eventData['name'],
            'address': eventData['address'] ?? '',
            'date': eventData['date'] != null ? DateFormat('MM-dd-yyyy').format((eventData['date'] as Timestamp).toDate()): '',
            'paymentMethod': eventData['paymentMethod'] ?? '',
            'serviceFee': eventData['serviceFee'] ?? 0,
            'totalPrice': eventData['totalPrice'] ?? 0,
            'serviceItems': serviceItems,
          }),
        );
      } catch (e) {
        debugPrint("Failed to send feedback email: $e");
      }
    }

    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(docId)
        .delete();
    _processingDocIds.remove(docId);
  }

  Future<void> _showReassignDialog(BuildContext context, String docId) async {
    final techSnapshot = await FirebaseFirestore.instance
        .collection('technicians')
        .where('isActive', isEqualTo: true)
        .get();

    if (!context.mounted) return;

    final currentTechId = _selectedEvent?['technicianId'];
    final filteredTechs =
        techSnapshot.docs.where((tech) => tech.id != currentTechId).toList();

    String? selectedTechId;
    String? selectedTechName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Reassign Technician", style: TextStyle(fontFamily: "Changa One")),
          content: SizedBox(
            width: 300,
            child: filteredTechs.isEmpty
                ? Text("No active technicians available.", style: TextStyle(fontFamily: "Arimo"))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: filteredTechs.map((tech) {
                      final data = tech.data();
                      final name = data['name'] ?? tech.id;
                      final isSelected = selectedTechId == tech.id;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedTechId = tech.id;
                            selectedTechName = name;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFFDCEAFB)
                                : Color(0xFFF5F6FA),
                            border: Border.all(
                              color: isSelected
                                  ? Color(0xFF013B7A)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("${tech.id} - $name", style: TextStyle(fontFamily: "Arimo", fontWeight: isSelected ? FontWeight.bold: FontWeight.normal, color: isSelected ? Color(0xFF013B7A): Colors.black)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c))),
            ),
            ElevatedButton(
              onPressed: selectedTechId == null
                  ? null
                  : () async {
                    final nav = Navigator.of(context);
                      await FirebaseFirestore.instance
                          .collection('service_requests')
                          .doc(docId)
                          .update({
                        'technicianId': selectedTechId,
                        'technicianName': selectedTechName,
                      });
                      setState(() {
                        _selectedEvent = {
                          ..._selectedEvent!,
                          'technicianId': selectedTechId,
                          'technicianName': selectedTechName,
                        };
                      });
                      nav.pop();
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, elevation: 8),
              child: Text("SAVE", style: TextStyle(fontSize: 13, fontFamily: "Arimo", fontWeight: FontWeight.w700, color: Color(0xFF013b7a))),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllEventsDialog(
      BuildContext context, DateTime day, List<Map<String, dynamic>> dayEvents) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DateFormat('MMMM d, yyyy').format(day),
          style: TextStyle(fontFamily: "Arimo", fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: dayEvents.length,
            separatorBuilder: (_, _) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = dayEvents[index];
              final techName = e['technicianName'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _selectedEventNotifier.value = e;
                  setState(() {
                    _selectedDay = day;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: getChipColor(e['technicianId'] ?? ''),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("${e['name'] ?? ''} - ${e['time'] ?? ''} $techName", style: TextStyle(color: getTextColor(e['technicianId'] ?? ''), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    List<Map<String, dynamic>> dayEvents,
  ) {
    final bool isOutsideMonth =
        day.month != _focusedDay.month || day.year != _focusedDay.year;

    final Color dateColor =
        isOutsideMonth ? Colors.grey.shade400 : Colors.grey.shade700;

    final Color bgColor = isOutsideMonth ? Color(0xFFF5F5F5) : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Color(0xFFE0E0E0), width: 0.5),
      ),
      padding: EdgeInsets.fromLTRB(5, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${day.day}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dateColor, fontFamily: "Arimo")),
          SizedBox(height: 3),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxChips = 2;
                final safeMaxChips = maxChips < 1 ? 1 : maxChips;

                final visibleEvents = dayEvents.take(safeMaxChips).toList();
                final overflow = dayEvents.length - visibleEvents.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...visibleEvents.map((e) {
                      return GestureDetector(
                        onTap: () {
                          _selectedEventNotifier.value = e;
                          setState(() {
                            _selectedDay = day;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 3),
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: getChipColor(e['technicianId'] ?? ''),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("${e['name'] ?? ''} • ${e['time'] ?? ''}", style: TextStyle(color: getTextColor(e['technicianId'] ?? ''), fontSize: 8, fontWeight: FontWeight.w600, height: 1.3, fontFamily: "Arimo"), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                      );
                    }),
                    if (overflow > 0)
                      GestureDetector(
                        onTap: () =>
                            _showAllEventsDialog(context, day, dayEvents),
                        child: Text("+$overflow more",
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100; 

    Widget listViewPanel = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("List View", style: TextStyle(fontSize: 18, fontFamily: "Arimo", fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Expanded(
              child: ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _selectedEventNotifier,
                builder: (context, selectedEvent, _) {
                  List<Map<String, dynamic>> allEvents = [];
                  for (var dayEvents in events.values) {
                    allEvents.addAll(dayEvents);
                  }

                  allEvents.sort((a, b) {
                    DateTime dateA = (a['date'] as Timestamp).toDate();
                    DateTime dateB = (b['date'] as Timestamp).toDate();
                    return dateA.compareTo(dateB); 
                  });

                  if (allEvents.isEmpty) {
                    return Center(
                      child: Text("No requests found.", style: TextStyle(fontFamily: "Arimo", color: Colors.grey)),
                    );
                  }

                  return ListView.separated(
                    itemCount: allEvents.length,
                    separatorBuilder: (_, _) => Divider(color: Colors.grey.shade200, height: 1),
                    itemBuilder: (context, index) {
                      final e = allEvents[index];
                      final date = (e['date'] as Timestamp).toDate();
                      final isSelected = selectedEvent?['docId'] == e['docId'];
                      
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tileColor: isSelected ? Color(0xFFF5F6FA) : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        title: Text(
                          e['name'] ?? 'Unknown Client',
                          style: TextStyle(
                            fontFamily: "Arimo", 
                            fontWeight: FontWeight.bold, 
                            fontSize: 14, 
                            color: isSelected ? Color(0xFF013B7A) : Colors.black
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${DateFormat('MMM d, yyyy').format(date)} • ${e['time'] ?? ''}", style: TextStyle(fontFamily: "Arimo", fontSize: 12)),
                              Text("${e['serviceType'] ?? ''}", style: TextStyle(fontFamily: "Arimo", fontSize: 11, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getStatusColor(e['status'] ?? 'Pending').withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e['status'] ?? 'Pending',
                            style: TextStyle(
                              color: getStatusColor(e['status'] ?? 'Pending'),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Arimo"
                            ),
                          ),
                        ),
                        onTap: () {
                          _selectedEventNotifier.value = e;
                          setState(() {
                            _selectedDay = date;
                            _focusedDay = date;
                          });
                        },
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

    Widget calendarContainer = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double headerHeight = 0;
          const double daysOfWeekHeight = 28;
          final double availableForRows = constraints.maxHeight - headerHeight - daysOfWeekHeight;
          final double rowHeight = availableForRows / 6;
          return SizedBox(
            height: constraints.maxHeight,
            child: TableCalendar(
              firstDay: DateTime(
                DateTime.now().year,
                DateTime.now().month,
                1,
              ),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              rowHeight: rowHeight,
              daysOfWeekHeight: daysOfWeekHeight,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                final dayEvents = getEvents(selected);
                _selectedEventNotifier.value =
                    dayEvents.isNotEmpty ? dayEvents.first : null;
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
              },
              eventLoader: getEvents,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                titleTextStyle: TextStyle(
                    fontFamily: "Arimo",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                isTodayHighlighted: false,
                markersMaxCount: 0,
                cellMargin: EdgeInsets.zero,
                cellPadding: EdgeInsets.zero,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) =>
                    _buildDayCell(context, day, getEvents(day)),
                todayBuilder: (context, day, _) =>
                    _buildDayCell(context, day, getEvents(day)),
                selectedBuilder: (context, day, _) =>
                    _buildDayCell(context, day, getEvents(day)),
                outsideBuilder: (context, day, _) =>
                    _buildDayCell(context, day, getEvents(day)),
                markerBuilder: (context, day, events) => SizedBox(),
              ),
            ),
          );
        },
      ),
    );

    Widget calendarViewPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Calendar View", style: TextStyle(fontSize: 26, fontFamily: "Changa One")),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("View and manage all service request", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
            isDesktop ? SizedBox(width: 515) : Spacer(),
            Container(
                width: 100,
                height: 40,
                color: Color(0xFF013B7A),
                child: Center(
                  child: Text("Today", style: TextStyle(fontSize: 16, fontFamily: "Arimo", fontWeight: FontWeight.bold, color: Colors.white)))),
          ],
        ),
        SizedBox(height: 10),
        isDesktop 
            ? Expanded(child: calendarContainer)
            : SizedBox(height: 450, child: calendarContainer),
      ],
    );

    Widget detailsViewPanel = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 25, top: 25, right: 5, bottom: 15),
        child: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: _selectedEventNotifier,
          builder: (context, selectedEventVal, _) =>
            selectedEventVal == null
            ? Container(
                alignment: Alignment.center,
                child: Text("Select an event", style: TextStyle(color: Colors.grey, fontSize: 15, fontFamily: "Arimo")),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Service Details", style: TextStyle(fontFamily: "Arimo", fontWeight: FontWeight.bold, fontSize: 22)),
                    Text.rich(TextSpan(
                      children: [
                        TextSpan(text: "Request ID: ", style: TextStyle(fontFamily: "Arimo", fontSize: 15, color: Colors.black)),
                        TextSpan(text: "${_selectedEvent?['requestId']}", style: TextStyle(fontFamily: "Arimo", fontSize: 15, color: Color(0xFF013B7A))),
                      ],
                    )),
                    SizedBox(height: 15),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.account_circle, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text("Client Name", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text("${_selectedEvent?['name']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_android, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Mobile Number",style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text("${_selectedEvent?['mobileNumber']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Email Address", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                                Text("${_selectedEvent?['email']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold),
                                  softWrap: true,
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Complete Address", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                                Text("${_selectedEvent?['address']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold),
                                  softWrap: true,
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Date", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text(
                                _selectedEvent?['date'] != null
                                    ? "${DateFormat('MMMM d, yyyy').format((_selectedEvent!['date'] as Timestamp).toDate())} (${DateFormat('EEEE').format((_selectedEvent!['date'] as Timestamp).toDate())})"
                                    : '',
                                style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Time", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text("${_selectedEvent?['time']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.ac_unit, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Service Type", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text("${_selectedEvent?['serviceType']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.engineering, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Technician", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "${_selectedEvent?['technicianId']} - ${_selectedEvent?['technicianName'] ?? 'Unassigned'}",
                                    style: TextStyle(
                                      fontFamily: "Arimo",
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    softWrap: true,
                                    maxLines: null,
                                    overflow: TextOverflow.visible,
                                  ),
                                  SizedBox(width: 15),
                                  GestureDetector(
                                    onTap: () => _showReassignDialog(
                                        context,
                                        _selectedEvent!['docId']),
                                    child: Icon(Icons.swap_horiz, color: Color(0xFF013B7A), size: 20),
                                  )
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.description, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Description", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                                Text("${_selectedEvent?['description']}", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold),
                                  softWrap: true,
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.payments, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text( _selectedEvent?['serviceType'] == 'Installation' ? "Total Price" : "Repair/Maintenance Fee", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text("₱${NumberFormat('#,##0').format(_selectedEvent?['totalPrice'] ?? 0)}",
                                style: TextStyle(
                                  fontFamily: "Arimo",
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF013B7A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.price_check, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Payment", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text((_selectedEvent?['paymentMethod'] ==
                                        'GCash')
                                    ? "${_selectedEvent?['paymentStatus'] ?? 'Paid'} - GCash"
                                    : "Cash on Service",
                                style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold,
                                color: (_selectedEvent?['paymentMethod'] ==
                                                'GCash' &&
                                            _selectedEvent?['paymentStatus'] ==
                                                'Unpaid')
                                        ? Color(0xFFDC342C)
                                        : Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions, color: Color(0xFF013B7A), size: 35),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Status", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                              Text(_selectedEvent?['status'] ?? "Pending", style: TextStyle(fontFamily: "Arimo", fontSize: 12, fontWeight: FontWeight.bold, color: getStatusColor( _selectedEvent?['status'] ?? "Pending"))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final status = _selectedEvent?['status'] ?? 'Pending';
                              final docId = _selectedEvent!['docId'];

                              if (status == 'Pending') {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _updateStatus(docId, 'Approved'),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 27, vertical: 15),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                        backgroundColor: Color(0xFF6A1B9A),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("Approved", style: TextStyle(fontSize: 15, fontFamily: "Arimo", color: Colors.white)),
                                        SizedBox(width: 15),
                                        Icon(Icons.timelapse, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                );
                              } else if (status == 'Approved') {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await moveToHistory(docId, status: 'Completed');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 27, vertical: 15),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: Color(0xFF228B22),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("Mark as Completed", style: TextStyle(fontSize: 15, fontFamily: "Arimo", color: Colors.white)),
                                        SizedBox(width: 15),
                                        Icon(Icons.check, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      disabledBackgroundColor: Colors.grey.shade300,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("Completed", style: TextStyle(fontSize: 15, fontFamily: "Arimo", color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 15),
                                        Icon(Icons.check_circle, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final status =_selectedEvent?['status'] ?? 'Pending';
                              final docId = _selectedEvent!['docId'];
                              final canCancel = status == 'Pending';
                              return SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: canCancel
                                      ? () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) =>
                                                AlertDialog(
                                              backgroundColor:
                                                  Colors.white,
                                              title: Text("Cancel Request", style: TextStyle(fontFamily: "Changa One")),
                                              content: Text("Are you sure you want to cancel this request? It will be moved to history.",style: TextStyle(fontFamily: "Arimo")),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, false),
                                                  child: Text("No", style: TextStyle(fontFamily: "Arimo", color: Color(0xFF013B7A))),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, true),
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Color(
                                                              0xFFDC342C)),
                                                  child: Text("Yes, Cancel", style: TextStyle(fontFamily: "Arimo", color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            final cancelDocId = docId;
                                            final cachedEvent = Map<String, dynamic>.from(_selectedEvent!);

                                            _processingDocIds.add(cancelDocId);
                                            _selectedEventNotifier.value = null;
                                            setState(() {
                                              for (final key in events.keys) {
                                                events[key]?.removeWhere((e) => e['docId'] == cancelDocId);
                                              }
                                              events.removeWhere((key, value) => value.isEmpty);
                                            });

                                            _updateStatus(cancelDocId, 'Cancelled', cachedEvent: cachedEvent).then((_) {
                                              moveToHistory(cancelDocId, status: 'Cancelled');
                                            });
                                          }
                                        }
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                                    tapTargetSize:MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(color: canCancel ? Color(0xFFDC342C): Colors.grey.shade400, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("Cancel Request",style: TextStyle(fontSize: 15, fontFamily: "Arimo", color: canCancel ? Color(0xFFDC342C) : Colors.grey.shade400)),
                                      SizedBox(width: 15),
                                      Icon(Icons.close, color: canCancel ? Color(0xFFDC342C) : Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 25),
                  ],
                ),
              ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 10, vertical: 15),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 1, child: listViewPanel),
                  SizedBox(width: 20),
                  Expanded(flex: 3, child: calendarViewPanel),
                  SizedBox(width: 20),
                  Expanded(flex: 1, child: detailsViewPanel),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 400, child: listViewPanel),
                    SizedBox(height: 20),
                    calendarViewPanel,
                    SizedBox(height: 20),
                    detailsViewPanel,
                  ],
                ),
              ),
      ),
    );
  }
}