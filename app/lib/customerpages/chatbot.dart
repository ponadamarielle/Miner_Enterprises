import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatbotSheet extends StatefulWidget {
  const ChatbotSheet({super.key});

  @override
  State<ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends State<ChatbotSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _waitingForFollowUp = false;
  bool _chatEnded = false;

  final String _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  final List<String> _suggestions = [
    'What services do you offer?',
    'How do I book a service?',
    'How much is the service fee?',
    'Troubleshoot my AC',
    'What are your business hours?',
    'What AC brands do you carry?',
    'How do I track my service request?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': 'Hello and welcome to Miner Enterprises! 🌬️ How can I assist you today?',
    });
  }

  Future<void> _sendMessage(String userText) async {
    if (userText.trim().isEmpty) return;

    if (userText.trim().toLowerCase() == 'troubleshoot my ac') {
      setState(() {
        _messages.add({'role': 'user', 'content': userText});
        _messages.add({
          'role': 'assistant',
          'content': 'Sure! What seems to be the problem with your AC? 🔧',
        });
      });
      _controller.clear();
      _scrollToBottom();
      return;
    }

    if (_waitingForFollowUp) {
      final input = userText.trim().toLowerCase();
      final isYes = ['yes', 'yes.', 'yes,', 'oo', 'oo.', 'yep', 'yeah'].contains(input);
      final isNo = ['no', 'no.', 'no,', 'nope', 'wala na', 'none'].contains(input);

      if (isYes) {
        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last['content'] == 'Is there anything else I can help you with?') {
            _messages.removeLast();
          }
          _messages.add({'role': 'user', 'content': userText});
          _waitingForFollowUp = false;
        });
        _controller.clear();
        _scrollToBottom();
        return;
      } else if (isNo) {
        setState(() {
          _messages.add({'role': 'user', 'content': userText});
          _messages.add({
            'role': 'assistant',
            'content': 'Thank you for reaching out to Miner Enterprises! Have a great day! 😊🌬️',
          });
          _waitingForFollowUp = false;
        });
        _controller.clear();
        _scrollToBottom();

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _messages.clear();
              _messages.add({
                'role': 'assistant',
                'content': 'Hello and welcome to Miner Enterprises! 🌬️ How can I assist you today?',
              });
              _chatEnded = false;
            });
            _scrollToBottom();
          }
        });
        return;
      }
    }

    setState(() {
      _messages.add({'role': 'user', 'content': userText});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': '''
                You are a friendly customer service assistant for Miner Enterprises, an AC services business in the Philippines.

                SERVICES OFFERED:
                - AC Installation – starts at ₱500 (varies by unit size and type)
                - AC Repair – starts at ₱300 (final cost depends on parts and labor)
                - AC Maintenance/Cleaning – starts at ₱250 per unit
                - Note: A technician will provide the exact quote after assessing the unit on-site.

                BOOKING:
                - Booking is for customers only — only customers can submit service requests
                - Customers can book through the Services tab on the website
                - Fill out the service request form and the team will confirm the schedule
                - IMPORTANT: Never say "in the app" — always say "on the website" or "on our Services page"

                SERVICE TRACKING:
                - Customers will receive email updates on their service request status
                - For concerns, contact: minerenterprises2911@gmail.com

                BUSINESS HOURS:
                - Tuesday to Friday, 8:00 AM – 6:00 PM
                - For urgent concerns outside business hours, email minerenterprises2911@gmail.com and the team will respond the next business day

                AC BRANDS:
                - A wide selection of trusted AC brands is available
                - Direct customers to the Shop AC's tab to browse units

                INSTALLATION TIME:
                - Standard AC installation takes 2–4 hours depending on unit type and location

                TROUBLESHOOTING GUIDE:
                IMPORTANT: Only address the specific problem the customer mentioned. Do NOT list all possible AC problems. Respond only to what they asked about.

                If a customer says their AC won't turn on:
                → "Please check if the unit is properly plugged in and the circuit breaker hasn't tripped. If the issue persists, please request a repair service through our Services page."

                If a customer says their AC is not cooling properly:
                → "Try cleaning or replacing the air filter — a dirty filter is the most common cause. Also make sure doors and windows are closed. If the problem continues, our technicians can help!"

                If a customer says their AC is making strange noise:
                → "Strange noises may indicate loose parts or debris inside the unit. We recommend turning off the AC and request a repair service to avoid further damage."

                If a customer says their AC is leaking water:
                → "Water leakage is usually caused by a clogged drain line or low refrigerant. Turn off the unit and request a service through our Services page so we can schedule a technician visit."

                If a customer describes another issue not listed above:
                → "We're sorry to hear that! Please leave your name and contact number and our team will get back to you as soon as possible."

                COMMON QUESTIONS AND ANSWERS:
                Q: What services do you offer?
                A: "We offer AC installation, repair, and maintenance services. Visit our Services page to book or learn more!"

                Q: How do I book a service?
                A: "Booking is easy! Just go to the Services tab on our website, fill out the service request form, and our team will confirm your schedule."

                Q: What AC brands do you carry?
                A: "We carry a wide selection of trusted AC brands. Head over to our Shop AC's page to browse available units and find the best fit for your space!"

                Q: How long does installation take?
                A: "Standard AC installation typically takes 2–4 hours depending on the unit type and location."

                Q: What are your business hours?
                A: "We are open Tuesday to Friday, 8:00 AM – 6:00 PM. For urgent concerns outside business hours, you may message us at minerenterprises2911@gmail.com and we'll get back to you the next business day."

                Q: How do I track my service request?
                A: "You will receive email updates regarding the status of your service request, so make sure to check your inbox regularly! If you have any concerns about your request, feel free to contact us at minerenterprises2911@gmail.com."

                Q: How much is the service fee?
                A: "Our service fees are as follows:
                Installation - starts at ₱500 (varies by unit size and type)
                Repair - starts at ₱300 (final cost depends on parts and labor)
                Maintenance/Cleaning - starts at ₱250 per unit
                Note: A technician will provide the exact quote after assessing your unit on-site."

                RULES:
                - Only answer questions related to Miner Enterprises and AC services
                - Always be friendly and professional
                - CRITICAL RULE — EMOJI: You MUST end EVERY single response with exactly 1 emoji. Place it as the very last character of your message, after the period or sentence. Never skip this. Never put the emoji in the middle of the response. Examples: "...book a repair service. 🔧" or "...check your inbox regularly! 📧"
                - If you don't know the answer, say: "For more details, please contact us at minerenterprises2911@gmail.com"
                - Keep responses concise and helpful
                - Support both English and Filipino depending on how the customer messages
                - IMPORTANT: Do NOT ask unnecessary follow-up questions. Just answer what the customer asked and stop. Do not ask things like "Would you like a quote?", "Would you like to book?", "Do you want more details?" unless the customer specifically asks for it.
                - Never prompt the customer to do something they didn't ask about
                ''',
            },
            ..._messages.map((m) => {
              'role': m['role'],
              'content': m['content'],
            }),
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        final bool isQuestion = reply.trimRight().endsWith('?');
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          if (!isQuestion) {
            _messages.add({
              'role': 'assistant',
              'content': 'Is there anything else I can help you with?',
            });
            _waitingForFollowUp = true;
          }
        });
      } else {
        setState(() => _messages.add({
          'role': 'assistant',
          'content': 'Sorry, something went wrong. Please try again.',
        }));
      }
    } catch (e) {
      setState(() => _messages.add({
        'role': 'assistant',
        'content': 'Network error. Please check your connection.',
      }));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: isUser ?  Color(0xFF013B7A) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 14),
          ),
        ),
        child: Text(
          msg['content']!,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested questions:',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestions.map((suggestion) {
            return GestureDetector(
              onTap: () => _sendMessage(suggestion),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF013B7A)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF013B7A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showSuggestions =
        _messages.length == 1 && _messages[0]['role'] == 'assistant' && !_chatEnded;

    return Container(
      width: 390,
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF013B7A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 16,
                  child: Icon(Icons.support_agent, color: Color(0xFF013B7A), size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Miner Assistant',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Changa One',
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Powered by AI',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF013B7A),
                        ),
                      ),
                    ),
                  );
                }
                return _buildBubble(_messages[index]);
              },
            ),
          ),

          if (showSuggestions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSuggestions(),
            ),

          if (!showSuggestions &&
              !_waitingForFollowUp &&
              !_chatEnded &&
              _messages.isNotEmpty &&
              _messages.last['role'] == 'user' &&
              ['yes', 'yes.', 'yes,', 'oo', 'oo.', 'yep', 'yeah']
                  .contains(_messages.last['content']!.trim().toLowerCase()))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSuggestions(),
            ),

          const SizedBox(height: 8),

          // Input row (always visible)
          Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF013B7A),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.send, color: Colors.white, size: 16),
                      onPressed: () => _sendMessage(_controller.text),
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