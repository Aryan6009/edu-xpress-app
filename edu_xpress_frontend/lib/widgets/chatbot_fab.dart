import 'package:flutter/material.dart';
import 'package:edu_xpress_frontend/widgets/book_bot.dart';

class ChatBotFAB extends StatefulWidget {
  const ChatBotFAB({super.key});

  @override
  State<ChatBotFAB> createState() => _ChatBotFABState();
}

class _ChatBotFABState extends State<ChatBotFAB> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🤖 Mascot Character (BookBot)
        Positioned(
          top: -70,
          left: -5,
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 8 * _hoverController.value),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/chat'),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))
                      ],
                      border: Border.all(color: Colors.deepOrange.withOpacity(0.2), width: 1),
                    ),
                    child: const Text(
                      "Chat with me!",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const BookBot(size: 55),
                ],
              ),
            ),
          ),
        ),

        // FAB
        FloatingActionButton(
          heroTag: "chatbot_fab",
          onPressed: () {
            Navigator.pushNamed(context, '/chat');
          },
          backgroundColor: Colors.deepOrange,
          elevation: 8,
          tooltip: 'Chat with AI Assistant',
          child: const Icon(
            Icons.chat_bubble_outline,
            size: 28,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
