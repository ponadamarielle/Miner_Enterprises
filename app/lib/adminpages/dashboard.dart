import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 50 : 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ 
            Text("OVERVIEW", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),
            SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .snapshots(),
              builder: (context, reqSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('history')
                      .snapshots(),
                  builder: (context, histSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('technicians')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, techSnapshot) {
                        final totalRequests =
                            histSnapshot.hasData ? histSnapshot.data!.docs.length : 0;

                        final pendingRequests = reqSnapshot.hasData
                            ? reqSnapshot.data!.docs
                                .where((d) => (d['status'] ?? '') == 'Pending')
                                .length
                            : 0;

                        final approvedRequests = reqSnapshot.hasData
                            ? reqSnapshot.data!.docs
                                .where((d) => (d['status'] ?? '') == 'Approved')
                                .length
                            : 0;

                        final activeTechnicians =
                            techSnapshot.hasData ? techSnapshot.data!.docs.length : 0;

                        double totalSales = 0;
                        if (histSnapshot.hasData) {
                          for (final doc in histSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if ((data['status'] ?? '') == 'Completed' &&
                                data.containsKey('totalPrice')) {
                              totalSales += (data['totalPrice'] as num).toDouble();
                            }
                          }
                        }

                        if (isDesktop) {
                          return Row(
                            children: [
                              Expanded(child: _StatCard(label: "Total Service Request", value: totalRequests.toString(), icon: Icons.receipt_long_outlined, iconColor: Color(0xFF013B7A))),
                              SizedBox(width: 20),
                              Expanded(child: _StatCard(label: "Pending Service", value: pendingRequests.toString(), icon: Icons.hourglass_top_outlined, iconColor: Colors.orange)),
                              SizedBox(width: 20),
                              Expanded(child: _StatCard(label: "Approved Service", value: approvedRequests.toString(), icon: Icons.check_circle_outline, iconColor: Color(0xFF6A1B9A))),
                              SizedBox(width: 20),
                              Expanded(child: _StatCard(label: "Active Technicians", value: activeTechnicians.toString(), icon: Icons.engineering_outlined, iconColor: Colors.green)),
                              SizedBox(width: 20),
                              Expanded(child: _StatCard(label: "Total Sales", value: "₱${NumberFormat('#,##0').format(totalSales)}", icon: Icons.payments_outlined, iconColor:  Color(0xFF013B7A))),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StatCard(label: "Total Service Request", value: totalRequests.toString(), icon: Icons.receipt_long_outlined, iconColor: Color(0xFF013B7A)),
                              SizedBox(height: 10),
                              _StatCard(label: "Pending Service", value: pendingRequests.toString(), icon: Icons.hourglass_top_outlined, iconColor: Colors.orange),
                              SizedBox(height: 10),
                              _StatCard(label: "Approved Service", value: approvedRequests.toString(), icon: Icons.check_circle_outline, iconColor: Color(0xFF6A1B9A)),
                              SizedBox(height: 10),
                              _StatCard(label: "Active Technicians", value: activeTechnicians.toString(), icon: Icons.engineering_outlined, iconColor: Colors.green),
                              SizedBox(height: 10),
                              _StatCard(label: "Total Sales", value: "₱${NumberFormat('#,##0').format(totalSales)}", icon: Icons.payments_outlined, iconColor:  Color(0xFF013B7A)),
                            ],
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),

            SizedBox(height: 25),

            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SizedBox(height: 450, child: _RecentRequestsCard())),
                      SizedBox(width: 25),
                      Expanded(child: SizedBox(height: 450, child: _MonthlyRevenueCard())),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 450, child: _RecentRequestsCard()),
                      SizedBox(height: 25),
                      SizedBox(height: 450, child: _MonthlyRevenueCard()),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: "Arimo",
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: "Changa One",
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRequestsCard extends StatelessWidget {
  const _RecentRequestsCard();

  Widget _buildRow(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    Color statusColor;
    if (status == 'Completed') {
      statusColor = Colors.green;
    } else if (status == 'Cancelled') {
      statusColor = Colors.red;
    } else if (status == 'Approved') {
      statusColor = const Color(0xFF6A1B9A);
    } else if (status == 'Pending') {
      statusColor = const Color(0xFFE65100);
    } else {
      statusColor = Colors.grey;
    }

    String dateStr = '';
    if (data['date'] is Timestamp) {
      dateStr = DateFormat('MMM d, yyyy')
          .format((data['date'] as Timestamp).toDate());
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  data['name'] ?? '',
                  style: TextStyle(fontFamily: "Arimo", fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  data['serviceType'] ?? '',
                  style: TextStyle(fontFamily: "Arimo", fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                      style: TextStyle(fontFamily: "Arimo", fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  dateStr,
                  style: TextStyle(fontFamily: "Arimo", fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Color(0xFFF0F0F0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Recent Service Requests", style: TextStyle(fontSize: 16, fontFamily: "Changa One")),
          SizedBox(height: 16),
          // Header row
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("Customer",
                      style: TextStyle(
                          fontFamily: "Changa One",
                          fontSize: 13,
                          color: Colors.black54)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("Service",
                      style: TextStyle(
                          fontFamily: "Changa One",
                          fontSize: 13,
                          color: Colors.black54)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("Status",
                      style: TextStyle(
                          fontFamily: "Changa One",
                          fontSize: 13,
                          color: Colors.black54)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("Date",
                      style: TextStyle(
                          fontFamily: "Changa One",
                          fontSize: 13,
                          color: Colors.black54)),
                ),
              ],
            ),
          ),
          Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .snapshots(),
              builder: (context, reqSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('history')
                      .snapshots(),
                  builder: (context, histSnapshot) {
                    if (reqSnapshot.connectionState == ConnectionState.waiting ||
                        histSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final allDocs = [
                      ...reqSnapshot.data?.docs ?? [],
                      ...histSnapshot.data?.docs ?? [],
                    ];

                    if (allDocs.isEmpty) {
                      return Center(
                        child: Text(
                          "No recent requests",
                          style: TextStyle(fontFamily: "Arimo", color: Colors.black45),
                        ),
                      );
                    }

                    allDocs.sort((a, b) {
                      final aDate = (a.data() as Map)['date'];
                      final bDate = (b.data() as Map)['date'];
                      if (aDate is Timestamp && bDate is Timestamp) {
                        return bDate.compareTo(aDate);
                      }
                      return 0;
                    });

                    return ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: allDocs
                              .map((doc) => _buildRow(doc.data() as Map<String, dynamic>))
                              .toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyRevenueCard extends StatelessWidget {
  const _MonthlyRevenueCard();

  Map<String, double> _aggregateByMonth(List<QueryDocumentSnapshot> docs) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final Map<String, double> totals = {for (final m in months) m: 0.0};
    final currentYear = DateTime.now().year;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] is! Timestamp) continue;
      final date = (data['date'] as Timestamp).toDate();
      if (date.year != currentYear) continue;
      final monthKey = months[date.month - 1];
      totals[monthKey] = (totals[monthKey] ?? 0) +
          (data.containsKey('totalPrice') ? (data['totalPrice'] as num).toDouble() : 0);
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Monthly Revenue",
                style: TextStyle(fontSize: 16, fontFamily: "Changa One"),
              ),
              Text(
                DateFormat('yyyy').format(DateTime.now()),
                style: TextStyle(
                    fontFamily: "Arimo", fontSize: 13, color: Colors.black45),
              ),
            ],
          ),
          SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('history')
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.hasData
                  ? snapshot.data!.docs
                  : <QueryDocumentSnapshot>[];
              final monthlyData = _aggregateByMonth(docs);
              final maxValue = monthlyData.values.fold(0.0, (a, b) => a > b ? a : b);

              return SizedBox(
                height: 350,
                child: _BarChart(monthlyData: monthlyData, maxValue: maxValue),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, double> monthlyData;
  final double maxValue;

  const _BarChart({required this.monthlyData, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    const barColor = Color(0xFF013B7A);
    const barColorLight = Color(0xFFCFDFF5);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final currentMonth = DateTime.now().month;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: months.asMap().entries.map((entry) {
                  final monthIndex = entry.key;
                  final month = entry.value;
                  final value = monthlyData[month] ?? 0.0;
                  final barHeightFraction =
                      maxValue > 0 ? value / maxValue : 0.0;
                  final isCurrentMonth = (monthIndex + 1) == currentMonth;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (value > 0)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                "₱${_shortFormat(value)}",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontFamily: "Arimo",
                                  color: isCurrentMonth
                                      ? barColor
                                      : Colors.black45,
                                  fontWeight: isCurrentMonth
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor:
                                  barHeightFraction.clamp(0.0, 1.0).toDouble(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrentMonth ? barColor : barColorLight,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (value == 0)
                            const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 6),
            Divider(height: 1, color: Color(0xFFE0E0E0)),
            SizedBox(height: 6),
            Row(
              children: months.map((month) {
                final isCurrentMonth =
                    (months.indexOf(month) + 1) == DateTime.now().month;
                return Expanded(
                  child: Text(
                    month,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: "Arimo",
                      color: isCurrentMonth ? barColor : Colors.black45,
                      fontWeight: isCurrentMonth
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  String _shortFormat(double value) {
    if (value >= 1000000) return "${(value / 1000000).toStringAsFixed(1)}M";
    if (value >= 1000) return "${(value / 1000).toStringAsFixed(1)}K";
    return value.toStringAsFixed(0);
  }
}