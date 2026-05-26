import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Feedback extends StatefulWidget {
  final String requestId;
  final String technicianId;

  const Feedback({
    super.key,
    required this.requestId,
    required this.technicianId,
  });

  @override
  State<Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<Feedback> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;

  Future<void> _submitFeedback() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a star rating first!")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'requestId': widget.requestId,
        'technicianId': widget.technicianId,
        'rating': _selectedRating,
        'comments': _commentController.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit feedback: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 80),
              SizedBox(height: 20),
              Text("Thank You!", style: TextStyle(fontSize: 28, fontFamily: "Changa One", color: Color(0xFF013B7A))),
              SizedBox(height: 10),
              Text("Your feedback helps us improve our service.", style: TextStyle(fontFamily: "Arimo", fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Service Feedback", style: TextStyle(color: Color(0xFF013B7A), fontFamily: "Changa One")),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF013B7A)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("How did we do?", style: TextStyle(fontSize: 24, fontFamily: "Changa One", color: Color(0xFF013B7A))),
                SizedBox(height: 5),
                Text("Request: ${widget.requestId}", style: TextStyle(fontSize: 14, fontFamily: "Arimo", color: Colors.grey.shade600)),
                SizedBox(height: 30),
                
                // star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        index < _selectedRating ? Icons.star : Icons.star_border,
                        color: index < _selectedRating ? Color(0xFFB85C00) : Colors.grey.shade400,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Additional Comments (Optional)", style: TextStyle(fontFamily: "Arimo", fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Tell us about your experience...",
                    hintStyle: TextStyle(fontFamily: "Arimo", color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF013B7A), width: 1.5),
                    ),
                  ),
                ),
                SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC342C), // Miner Red
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Submit Feedback", style: TextStyle(fontSize: 16, fontFamily: "Arimo", fontWeight: FontWeight.bold, color: Colors.white)),
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