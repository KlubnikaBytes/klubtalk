import 'package:flutter/material.dart';

class SentMessageBubble extends StatelessWidget {
  final String message;
  final String timestamp;

  const SentMessageBubble({
    super.key,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF25D366), // WhatsApp Green
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.zero,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 0),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white, // Contrast for green bubble
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timestamp,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all,
                      size: 14,
                      color: Colors.white70, // Or blue if read
                    ),
                  ],
                ),
              ),
              // Invisible text to maintain width for the positioned timestamp
              Visibility(
                 visible: false,
                 child: Text(
                   message + "      ", 
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
