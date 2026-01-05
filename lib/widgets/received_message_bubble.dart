import 'package:flutter/material.dart';

class ReceivedMessageBubble extends StatelessWidget {
  final String message;
  final String timestamp;

  const ReceivedMessageBubble({
    super.key,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFEDEDED), // Light Grey
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.zero,
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15, right: 0),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ),
              // Invisible text to maintain width
              Visibility(
                 visible: false,
                 child: Text(
                   message + "     ", 
                   style: const TextStyle(fontSize: 16),
                 ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
