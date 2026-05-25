import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

final smtpServer = gmail('minerenterprises2911@gmail.com', 'rqxibjmuidkoeqri');

void main() async {
  final router = Router();

  router.post('/email/approve', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    final String requestId = data['requestId'];
    final String customerName = data['name'];
    final String customerEmail = data['email'];
    final String paymentStatus = data['paymentStatus'];

    final message = Message()
      ..from = Address('minerenterprises2911@gmail.com', 'Miner Enterprises')
      ..recipients.add(customerEmail)
      ..subject = 'Service Approved: $requestId'
      ..html = '''
        <h3>Hello $customerName,</h3>
        <p>Your <b>${data['serviceType']}</b> scheduled for <b>${data['date']}</b> at <b>${data['time']}</b> has been fully approved.</p>
        
        <hr>
        <h4>Payment Summary:</h4>
        <p><b>Total Amount:</b> PHP ${data['totalPrice']}</p>
        <p><b>Method:</b> ${data['paymentMethod']}</p>
        <p><b>Status:</b> $paymentStatus</p>
      ''';

    File? tempFile;
    if (paymentStatus == 'Paid') {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('OFFICIAL RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Customer: $customerName'),
              pw.Text('Service Request ID: $requestId'),
              pw.Text('Transaction Reference: ${data['xenditChargeId'] ?? 'N/A'}'),
              pw.SizedBox(height: 20),
              pw.Text('Service: ${data['serviceType']}'),
              pw.Text('Total Amount Paid: PHP ${data['totalPrice']}'),
              pw.Text('Payment Method: ${data['paymentMethod']}'),
              pw.Text('Status: PAID'),
            ],
          ),
        ),
      );

      final savedPdfBytes = await pdf.save();
      tempFile = File('Receipt_$requestId.pdf');
      await tempFile.writeAsBytes(savedPdfBytes);

      message.attachments.add(FileAttachment(tempFile));
      message.html = '${message.html}<p><i>Please find your official receipt attached to this email.</i></p>';
    }

    try {
      await send(message, smtpServer);
      print('Combined approval email sent to $customerEmail');
    } catch (e) {
      print('Failed to send combined approval email: $e');
    }

    if (tempFile != null && await tempFile.exists()) {
      await tempFile.delete();
    }
    
    return Response.ok('Approval email processed');
  });

  router.post('/email/feedback', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    final message = Message()
      ..from = Address('minerenterprises2911@gmail.com', 'Miner Enterprises')
      ..recipients.add(data['email'])
      ..subject = 'How did we do? - ${data['requestId']}'
      ..html = '<p>Your service is complete! Please leave us feedback <a href="YOUR_FORM_LINK">here</a>.</p>';

    try {
      await send(message, smtpServer);
      print('Feedback email sent to ${data['email']}');
    } catch (e) {
      print('Failed to send feedback email: $e');
    }

    return Response.ok('Feedback email processed');
  });

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  final handler = Pipeline().addMiddleware((innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  }).addHandler(router.call);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Dart Backend running on port ${server.port} with CORS enabled');
}