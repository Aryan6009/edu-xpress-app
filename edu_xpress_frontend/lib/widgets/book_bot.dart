import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BookBotState { idle, running, fallen, riding, loaded, waving, cycling }

class BookBot extends StatefulWidget {
  final double size;
  final bool isTalking;
  final BookBotState state;

  const BookBot({
    super.key, 
    this.size = 60, 
    this.isTalking = false,
    this.state = BookBotState.idle,
  });

  @override
  State<BookBot> createState() => _BookBotState();
}

class _BookBotState extends State<BookBot> {
  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🛡️ Body
            Positioned(
              bottom: size * 0.2,
              child: _buildBody(size),
            ),
            // 📚 Head
            Positioned(
              top: size * 0.2,
              child: _buildHead(size, widget.state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHead(double size, BookBotState state) {
    return Container(
      width: size * 0.7,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: Colors.deepOrange,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEye(size),
            _buildEye(size),
          ],
        ),
      ),
    );
  }

  Widget _buildEye(double size) {
    return Container(
      width: size * 0.2,
      height: size * 0.2,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: size * 0.08,
          height: size * 0.08,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double size) {
    return Container(
      width: size * 0.6,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(size * 0.15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Container(
          width: size * 0.15,
          height: size * 0.15,
          decoration: const BoxDecoration(
            color: Colors.cyanAccent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
