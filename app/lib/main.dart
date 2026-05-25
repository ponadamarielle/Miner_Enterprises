import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:miner_enterprises/customer.dart';
import 'firebase_options.dart';
import 'package:miner_enterprises/login.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RoleSelector(), 
    );
  }
}

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Select Role", style: TextStyle(fontFamily: "Changa One", fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 32),
            SizedBox(
              width: 140,
              height: 45,
              child: ElevatedButton.icon(
                icon: Icon(Icons.admin_panel_settings, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF013B7A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text("Admin", style: TextStyle(fontSize: 16, fontFamily: "Arimo", color: Colors.white)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Login()),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: 140,
              height: 45,
              child: ElevatedButton.icon(
                icon: Icon(Icons.person, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF013B7A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text("Customer", style: TextStyle(fontSize: 16, fontFamily: "Arimo", color: Colors.white),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Customer()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}