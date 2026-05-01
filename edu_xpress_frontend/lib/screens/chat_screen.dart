import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final String baseUrl = "http://10.46.51.170:5000";

  @override
  void initState() {
    super.initState();
    // Welcome message with delay for a natural feel
    Future.delayed(const Duration(milliseconds: 500), () {
      _addMessage(ChatMessage(
        text: "Hello! I'm your Edu-Xpress Assistant. How can I help you find books today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(_messages.length - 1, duration: const Duration(milliseconds: 500));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text.trim();
    _controller.clear();

    _addMessage(ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": userText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addMessage(ChatMessage(
          text: data["reply"],
          isUser: false,
          timestamp: DateTime.now(),
        ));
      } else {
        _addMessage(ChatMessage(
          text: "I'm having a little trouble connecting. Could you try that again?",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      }
    } catch (e) {
      _addMessage(ChatMessage(
        text: "Connection lost. Please check your internet and try again.",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              "Edu-Xpress Assistant",
              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text("Always here to help", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedList(
              key: _listKey,
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              initialItemCount: _messages.length,
              itemBuilder: (context, index, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(Tween(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic))),
                    child: _buildChatBubble(_messages[index]),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: EnhancedTypingIndicator(),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? const Color(0xFF7B1FA2) 
                  : (message.isError ? Colors.red[50] : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(message.isUser ? 20 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
              border: message.isError ? Border.all(color: Colors.red[200]!) : null,
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : (message.isError ? Colors.red[900] : Colors.black87),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(color: Colors.grey[400], fontSize: 9),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: "Ask about books...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.blueGrey),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF7B1FA2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text, 
    required this.isUser, 
    required this.timestamp,
    this.isError = false,
  });
}

class EnhancedTypingIndicator extends StatefulWidget {
  const EnhancedTypingIndicator({super.key});

  @override
  State<EnhancedTypingIndicator> createState() => _EnhancedTypingIndicatorState();
}

class _EnhancedTypingIndicatorState extends State<EnhancedTypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Edu-Xpress AI is typing",
          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double offset = index * 0.2;
              final double progress = (_controller.value + offset) % 1.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.grey[300],
                    const Color(0xFF7B1FA2),
                    progress,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
