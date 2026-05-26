import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:http/http.dart' as http;

final smtpServer = gmail('minerenterprises2911@gmail.com', 'rqxibjmuidkoeqri');
const String _firestoreProject = 'miner-enterprises';
const String _serviceAccountKeyPath = 'service_account.json';

const PdfColor kRed      = PdfColor.fromInt(0xFFE53935);
const PdfColor kBlue     = PdfColor.fromInt(0xFF1565C0);
const PdfColor kHeaderBg = PdfColor.fromInt(0xFFDDE8F8);
const PdfColor kFeeBg    = PdfColor.fromInt(0xFFE8EEF8);
const PdfColor kBorder   = PdfColor.fromInt(0xFFCCCCCC);
const PdfColor kTextDark = PdfColor.fromInt(0xFF212121);
const PdfColor kTextGray = PdfColor.fromInt(0xFF555555);

String php(num amount) => 'PHP ${amount.toStringAsFixed(2)}';

pw.BoxDecoration cellBorder() => pw.BoxDecoration(
  border: pw.Border.all(color: kBorder, width: 0.5),
);

pw.Widget buildHeader(String docTitle, pw.MemoryImage? logoImg) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Row(
        children: [
          logoImg != null
            ? pw.Image(logoImg, width: 40, height: 40)
            : pw.Container(
                width: 36, height: 36,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: kRed, width: 2),
                ),
                child: pw.Center(
                  child: pw.Text('ME', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kRed)),
                ),
              ),
          pw.SizedBox(width: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Miner ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: kBlue)),
                pw.TextSpan(text: 'Enterprises', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: kRed)),
              ])),
              pw.Text('Your Ultimate Cooling Solution!', style: pw.TextStyle(fontSize: 7, color: kTextGray)),
            ],
          ),
        ],
      ),
      pw.Text(docTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: kBlue)),
    ],
  );
}

pw.Widget buildInfoSection({required String billedToLabel, required String custName, required String customerAddress, required String docNumberLabel, required String docNumber, required String docDate}) {
  final String dateLabel = docNumberLabel.contains('Receipt') ? 'Receipt date' : 'Invoice date';
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(billedToLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kBlue)),
            pw.SizedBox(height: 4),
            pw.Text(custName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kTextDark)),
            pw.Text(customerAddress, style: pw.TextStyle(fontSize: 9, color: kTextGray)),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(children: [
            pw.Text('$docNumberLabel  ', style: pw.TextStyle(fontSize: 9, color: kTextGray)),
            pw.Text(docNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('$dateLabel  ', style: pw.TextStyle(fontSize: 9, color: kTextGray)),
            pw.Text(docDate, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)),
          ]),
        ],
      ),
    ],
  );
}

List<pw.TableRow> buildInstallationRows(List<dynamic> items) {
  return items.map((item) {
    final num itemPrice = (item['productPrice'] as num?) ?? 0;
    return pw.TableRow(
      decoration: cellBorder(),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text(item['serviceType']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, color: kTextDark))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text(item['productName']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, color: kTextDark))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text('1', style: pw.TextStyle(fontSize: 9, color: kTextDark))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text(php(itemPrice), style: pw.TextStyle(fontSize: 9, color: kTextDark))),
      ],
    );
  }).toList();
}

List<pw.TableRow> buildRepairRows(List<dynamic> items) {
  return items.map((item) {
    return pw.TableRow(
      decoration: cellBorder(),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text(item['serviceType']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, color: kTextDark))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: pw.Text(item['description']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, color: kTextDark))),
      ],
    );
  }).toList();
}

pw.Table buildInstallationTable(List<dynamic> items, num serviceFee, num totalPrice) {
  return pw.Table(
    columnWidths: { 0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1.5) },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: kHeaderBg),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Service Request', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Product', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Qty.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Price', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
        ],
      ),
      ...buildInstallationRows(items),
      pw.TableRow(
        decoration: pw.BoxDecoration(color: kFeeBg),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Service Fee:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text(php(serviceFee), style: pw.TextStyle(fontSize: 9, color: kTextDark))),
        ],
      ),
      pw.TableRow(
        decoration: cellBorder(),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Total:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text(php(totalPrice), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
        ],
      ),
    ],
  );
}

pw.Table buildRepairTable(List<dynamic> items, num serviceFee) {
  return pw.Table(
    columnWidths: { 0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(3) },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: kHeaderBg),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Service Request', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kBlue))),
        ],
      ),
      ...buildRepairRows(items),
      pw.TableRow(
        decoration: pw.BoxDecoration(color: kFeeBg),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('')),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Service Fee:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)),
                pw.Text(php(serviceFee), style: pw.TextStyle(fontSize: 9, color: kTextDark)),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Future<String?> _getAccessToken() async {
  try {
    final keyFile = File(_serviceAccountKeyPath);
    if (!await keyFile.exists()) return null;
    final keyJson = jsonDecode(await keyFile.readAsString());

    final String clientEmail = keyJson['client_email'];
    final String privateKeyPem = keyJson['private_key'];

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header  = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})));
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'iss': clientEmail,
      'scope': 'https://www.googleapis.com/auth/datastore',
      'aud': 'https://oauth2.googleapis.com/token',
      'exp': now + 3600,
      'iat': now,
    })));

    final unsigned = '$header.$payload';
    final tmpKey  = File('_tmp_key.pem');
    final tmpData = File('_tmp_data.txt');
    await tmpKey.writeAsString(privateKeyPem);
    await tmpData.writeAsBytes(utf8.encode(unsigned));

    final result = await Process.run('openssl', ['dgst', '-sha256', '-sign', '_tmp_key.pem', '-binary', '_tmp_data.txt'], stdoutEncoding: null);
    await tmpKey.delete();
    await tmpData.delete();

    if (result.exitCode != 0) return null;

    final sig = base64Url.encode(result.stdout as List<int>);
    final jwt = '$unsigned.$sig';

    final tokenRes = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$jwt',
    );
    if (tokenRes.statusCode == 200) return jsonDecode(tokenRes.body)['access_token'] as String?;
  } catch (e) { print('Token Error: $e'); }
  return null;
}

Future<Map<String, dynamic>> _fetchDocumentFromFirestore(String requestId) async {
  final empty = <String, dynamic>{};
  try {
    final token = await _getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/$_firestoreProject/databases/(default)/documents:runQuery');
    final body = jsonEncode({
      'structuredQuery': {
        'from': [{'collectionId': 'service_requests'}],
        'where': { 'fieldFilter': { 'field': {'fieldPath': 'requestId'}, 'op': 'EQUAL', 'value': {'stringValue': requestId} } },
        'limit': 1,
      },
    });

    final res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      final List results = jsonDecode(res.body);
      if (results.isNotEmpty && results[0]['document'] != null) {
        final fields = results[0]['document']['fields'] as Map<String, dynamic>;
        dynamic parseAny(String key) {
          final f = fields[key];
          if (f == null) return null;
          if (f['integerValue'] != null) return num.parse(f['integerValue'].toString());
          if (f['doubleValue']  != null) return (f['doubleValue'] as num);
          if (f['stringValue']  != null) return f['stringValue'] as String;
          if (f['booleanValue'] != null) return f['booleanValue'] as bool;
          return null;
        }
        return {
          'serviceFee':    parseAny('serviceFee')   ?? 0,
          'totalPrice':    parseAny('totalPrice')   ?? 0,
          'productName':   parseAny('productName')  ?? '',
          'productPrice':  parseAny('productPrice') ?? 0,
          'serviceType':   parseAny('serviceType')  ?? '',
          'description':   parseAny('description')  ?? '',
        };
      }
    }
  } catch (e) {}
  return empty;
}

void main() async {
  final router = Router();

  // sends invoices & receipts)
  router.post('/email/approve', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    final String requestId     = data['requestId'];
    final String customerName  = data['name'];
    final String customerEmail = data['email'];
    final String paymentStatus = data['paymentStatus'];
    final int receiptNumber    = data['receiptNumber'] ?? 1;

    num serviceFee = (data['serviceFee'] as num?) ?? 0;
    num totalPrice = (data['totalPrice'] as num?) ?? 0;

    final fsDoc = await _fetchDocumentFromFirestore(requestId);
    if (fsDoc.isNotEmpty) {
      if (fsDoc['serviceFee'] != null && fsDoc['serviceFee'] != 0) serviceFee = fsDoc['serviceFee'] as num;
      if (fsDoc['totalPrice'] != null && fsDoc['totalPrice'] != 0) totalPrice = fsDoc['totalPrice'] as num;
    }

    final String fsServiceType = (fsDoc.containsKey('serviceType') && fsDoc['serviceType'] != null && fsDoc['serviceType'].toString().isNotEmpty) ? fsDoc['serviceType'] as String : (data['serviceType'] ?? '');
    final String fsProductName = (fsDoc.containsKey('productName') && fsDoc['productName'] != null && fsDoc['productName'].toString().isNotEmpty) ? fsDoc['productName'] as String : (data['productName'] ?? '');
    final num fsProductPrice = (fsDoc.containsKey('productPrice') && fsDoc['productPrice'] != null) ? (fsDoc['productPrice'] as num) : ((data['productPrice'] as num?) ?? 0);
    final String fsDescription = (fsDoc.containsKey('description') && fsDoc['description'] != null && fsDoc['description'].toString().isNotEmpty) ? fsDoc['description'] as String : (data['description'] ?? '');

    final now = DateTime.now();
    final String currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final List<dynamic> serviceItems = data['serviceItems'] != null
        ? (data['serviceItems'] as List).map((item) => {
            'serviceType':  item['serviceType']  ?? fsServiceType,
            'productName':  item['productName']  ?? fsProductName,
            'productPrice': item['productPrice'] ?? fsProductPrice,
            'description':  item['description']  ?? fsDescription,
          }).toList()
        : [{ 'serviceType': fsServiceType, 'productName': fsProductName, 'productPrice': fsProductPrice, 'description': fsDescription }];

    final String primaryServiceType = (serviceItems.isNotEmpty ? serviceItems[0]['serviceType']?.toString() ?? '' : '').toLowerCase();
    final bool isInstallation = primaryServiceType.contains('install');

    pw.MemoryImage? logoImage;
    try {
      final logoFile = File('assets/logo.png');
      if (await logoFile.exists()) logoImage = pw.MemoryImage(await logoFile.readAsBytes());
    } catch (_) {}

    final bool isCashOnService = data['paymentMethod'] == 'Cash on Service';
    final bool isGCashPaid = data['paymentMethod'] == 'GCash' && paymentStatus == 'Paid';

    final String attachmentNote = isCashOnService ? '<p><i>Please find your invoice attached to this email. Payment is due on the day of service.</i></p>' : isGCashPaid ? '<p><i>Please find your official receipt attached to this email.</i></p>' : '';

    final message = Message()
      ..from = Address('minerenterprises2911@gmail.com', 'Miner Enterprises')
      ..recipients.add(customerEmail)
      ..subject = 'Service Approved: $requestId'
      ..html = '<h3>Hello $customerName,</h3><p>Your ${data['serviceType']} scheduled for <b>${data['date']}</b> at <b>${data['time']}</b> has been fully approved.</p>$attachmentNote';

    File? tempFile;

    if (isCashOnService) {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5.landscape, margin: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20), build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader(requestId, logoImage),
          pw.SizedBox(height: 20),
          buildInfoSection(billedToLabel: 'Bill To', custName: customerName, customerAddress: data['address'] ?? '—', docNumberLabel: 'Invoice #', docNumber: receiptNumber.toString().padLeft(7, '0'), docDate: currentDate),
          pw.SizedBox(height: 20),
          isInstallation ? buildInstallationTable(serviceItems, serviceFee, totalPrice) : buildRepairTable(serviceItems, serviceFee),
          pw.SizedBox(height: 16),
          pw.Row(children: [ pw.Text('Payment Method:  ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)), pw.Text('Cash on Service', style: pw.TextStyle(fontSize: 9, color: kTextDark)) ]),
          pw.SizedBox(height: 20),
          pw.Text('Notes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kBlue)),
          pw.SizedBox(height: 4),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Thank you for choosing ', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
            pw.TextSpan(text: 'Miner ', style: pw.TextStyle(fontSize: 8, color: kBlue)),
            pw.TextSpan(text: 'Enterprises', style: pw.TextStyle(fontSize: 8, color: kRed)),
            pw.TextSpan(text: '!', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
          ])),
        ],
      )));
      tempFile = File('Invoice_$requestId.pdf');
      await tempFile.writeAsBytes(await pdf.save());
      message.attachments.add(FileAttachment(tempFile));

    } else if (isGCashPaid) {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5.landscape, margin: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20), build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader(requestId, logoImage),
          pw.SizedBox(height: 20),
          buildInfoSection(billedToLabel: 'Billed To', custName: customerName, customerAddress: data['address'] ?? '—', docNumberLabel: 'Receipt #', docNumber: receiptNumber.toString().padLeft(7, '0'), docDate: currentDate),
          pw.SizedBox(height: 20),
          isInstallation ? buildInstallationTable(serviceItems, serviceFee, totalPrice) : buildRepairTable(serviceItems, serviceFee),
          pw.SizedBox(height: 16),
          pw.Row(children: [ pw.Text('Payment Method:  ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)), pw.Text('GCash', style: pw.TextStyle(fontSize: 9, color: kTextDark)) ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [ pw.Text('Transaction Reference:  ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)), pw.Text(data['xenditChargeId'] ?? 'N/A', style: pw.TextStyle(fontSize: 9, color: kTextDark)) ]),
          pw.SizedBox(height: 20),
          pw.Text('Notes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kBlue)),
          pw.SizedBox(height: 4),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Thank you for choosing ', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
            pw.TextSpan(text: 'Miner ', style: pw.TextStyle(fontSize: 8, color: kBlue)),
            pw.TextSpan(text: 'Enterprises', style: pw.TextStyle(fontSize: 8, color: kRed)),
            pw.TextSpan(text: '! Please retain this receipt for warranty or exchange purposes.\nFor questions or support, contact us at minerenterprises2911@gmail.com', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
          ])),
        ],
      )));
      tempFile = File('Receipt_$requestId.pdf');
      await tempFile.writeAsBytes(await pdf.save());
      message.attachments.add(FileAttachment(tempFile));
    }

    try { await send(message, smtpServer); print('Approval email sent'); } catch (e) { print('Email fail: $e'); }
    if (tempFile != null && await tempFile.exists()) await tempFile.delete();
    return Response.ok('Approval email processed');
  });


  // feedback
  router.post('/email/feedback', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    final String reqId = data['requestId'] ?? 'Unknown';
    final String techId = data['technicianId'] ?? 'Unassigned';
    final String customerEmail = data['email'];
    final String customerName = data['name'] ?? 'Customer';
    final String paymentMethod = data['paymentMethod'] ?? '';
    final now = DateTime.now();
    final String currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final String formUrl = 'http://localhost:62208/#/feedback?reqId=$reqId&techId=$techId';

    final message = Message()
      ..from = Address('minerenterprises2911@gmail.com', 'Miner Enterprises')
      ..recipients.add(customerEmail)
      ..subject = "Service Completed! - $reqId";

    File? tempFile;

    if (paymentMethod == 'Cash on Service') {
      pw.MemoryImage? logoImage;
      try {
        final logoFile = File('assets/logo.png');
        if (await logoFile.exists()) logoImage = pw.MemoryImage(await logoFile.readAsBytes());
      } catch (_) {}

      final num serviceFee = (data['serviceFee'] as num?) ?? 0;
      final num totalPrice = (data['totalPrice'] as num?) ?? 0;
      final List<dynamic> serviceItems = data['serviceItems'] ?? [];
      
      final String primaryServiceType = (serviceItems.isNotEmpty ? serviceItems[0]['serviceType']?.toString() ?? '' : '').toLowerCase();
      final bool isInstallation = primaryServiceType.contains('install');

      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5.landscape, margin: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20), build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader(reqId, logoImage),
          pw.SizedBox(height: 20),
          buildInfoSection(billedToLabel: 'Billed To', custName: customerName, customerAddress: data['address'] ?? '—', docNumberLabel: 'Receipt #', docNumber: reqId, docDate: currentDate),
          pw.SizedBox(height: 20),
          isInstallation ? buildInstallationTable(serviceItems, serviceFee, totalPrice) : buildRepairTable(serviceItems, serviceFee),
          pw.SizedBox(height: 16),
          pw.Row(children: [ pw.Text('Payment Method:  ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kTextDark)), pw.Text('Cash (Paid on Completion)', style: pw.TextStyle(fontSize: 9, color: kTextDark)) ]),
          pw.SizedBox(height: 20),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Thank you for choosing ', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
            pw.TextSpan(text: 'Miner ', style: pw.TextStyle(fontSize: 8, color: kBlue)),
            pw.TextSpan(text: 'Enterprises', style: pw.TextStyle(fontSize: 8, color: kRed)),
            pw.TextSpan(text: '! Please retain this receipt for warranty or exchange purposes.\nFor questions or support, contact us at minerenterprises2911@gmail.com', style: pw.TextStyle(fontSize: 8, color: kTextGray)),
          ])),
        ],
      )));

      tempFile = File('FinalReceipt_$reqId.pdf');
      await tempFile.writeAsBytes(await pdf.save());
      message.attachments.add(FileAttachment(tempFile));

      message.html = '''
        <h3>Thank you!</h3>
        <p>Your service is complete and payment has been received in full.</p>
        <p>Please find your <b>Official Receipt</b> attached to this email.</p>
        <br/>
        <p>We'd love to hear about your experience. Please leave us feedback <a href="$formUrl">here</a>.</p>
      ''';
    } else {
      message.html = '''
        <h3>Thank you!</h3>
        <p>Your service is complete!</p>
        <p>We'd love to hear about your experience. Please leave us feedback <a href="$formUrl">here</a>.</p>
      ''';
    }

    try {
      await send(message, smtpServer);
      print("Feedback email sent to $customerEmail");
    } catch (e) { print('Failed to send feedback email: $e'); }

    if (tempFile != null && await tempFile.exists()) await tempFile.delete();
    return Response.ok('Feedback email processed');
  });

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  final handler = Pipeline().addMiddleware((innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') return Response.ok('', headers: corsHeaders);
      try {
        final response = await innerHandler(request);
        return response.change(headers: corsHeaders);
      } catch (e, stacktrace) {
        print('CRITICAL SERVER ERROR: $e\n$stacktrace');
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {...corsHeaders, 'Content-Type': 'application/json'});
      }
    };
  }).addHandler(router.call);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Dart Backend running on port ${server.port} with CORS enabled');
}