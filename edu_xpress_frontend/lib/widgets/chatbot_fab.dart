import 'package:flutter/material.dart';

class ChatBotFAB extends StatelessWidget {
  const ChatBotFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.pushNamed(context, '/chat');
      },
      backgroundColor: const Color(0xFF7B1FA2),
      elevation: 8,
      tooltip: 'Chat with AI Assistant',
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.auto_stories, // Book icon
            size: 30,
            color: Colors.white,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.deepOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
