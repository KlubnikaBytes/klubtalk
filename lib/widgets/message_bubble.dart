import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/message_model.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isSentByMe;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bubbleColor = isMe
        ? (isDark ? AppTheme.sentMessageDark : AppTheme.sentMessageLight)
        : (isDark ? AppTheme.receivedMessageDark : AppTheme.receivedMessageLight);

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color timeColor = isDark ? Colors.white70 : Colors.black54;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(12),
            ),
          ),
          color: bubbleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Stack(
              children: [
                // Render text with padding for timestamp
                Padding(
                  padding: const EdgeInsets.only(bottom: 16), // Space for time
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Positioned details at bottom right of the stack
                Positioned(
                  bottom: -2,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(message.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: timeColor,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead ? const Color(0xFF53BDEB) : timeColor, // Blue ticks
                        ),
                      ],
                    ],
                  ),
                ),
                // Invisible Copy of Text to ensure container encompasses everything including the absolute positioned time
                // This is a common Flutter trick for "Flow" layout in chat bubbles without complex Row/Column nesting
                Visibility(
                  visible: false, 
                  maintainSize: true, 
                  maintainAnimation: true, 
                  maintainState: true,
                  child: Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: Text(
                      message.text,
                       style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                     ),
                  )
                ),
                 Visibility(
                  visible: false, 
                  maintainSize: true, 
                  maintainAnimation: true, 
                  maintainState: true,
                  child: const Text('      00:00 AM') // Spacer for min width
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
