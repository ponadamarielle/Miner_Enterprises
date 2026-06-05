import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miner_enterprises/admin.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String errorMessage = "";

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty && password.isEmpty) {
      setState(() {
        errorMessage = "Please enter email and password";
      });
      return;
    }

    if (email.isEmpty) {
      setState(() {
        errorMessage = "Please enter email";
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        errorMessage = "Please enter password";
      });
      return;
    }

    try {
      setState(() {
        errorMessage = "";
        isLoading = true;
      });

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint("Login successful");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Admin(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = "Email not found";
          break;
        case 'wrong-password':
          message = "Incorrect password";
          break;
        case 'invalid-email':
          message = "Invalid email format";
          break;
        case 'invalid-credential':
          message = "Incorrect email or password";
          break;
        default:
          message = "Login failed. Please try again";
      }

      setState(() {
        errorMessage = message;
        isLoading = false; 
      });

    } catch (e) {
      setState(() {
        errorMessage = "Unexpected error occurred";
        isLoading = false; 
      });

      debugPrint("UNKNOWN ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),

          Center(
            child: Container(
              width: 450,
              height: 500,
              padding: EdgeInsets.all(60),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [

                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', width: 50, height: 50),
                      SizedBox(width: 15),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "Miner ", style: TextStyle(fontSize: 30, fontFamily: "Changa One", color: Color(0xFF013b7a))),
                            TextSpan(text: "Enterprises", style: TextStyle(fontSize: 30, fontFamily: "Changa One", color: Color(0xFFdc342c)))
                          ]
                        )
                      )
                    ]
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Login to your account",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: "Arimo")
                  ),

                  SizedBox(height: 50),

                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  ),

                  SizedBox(height: 35),

                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  if (errorMessage.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: loginUser,
                    style: ElevatedButton.styleFrom(
                      elevation: 10,
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          "LOGIN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Arimo",
                            color: Color(0xFF013B7A),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}