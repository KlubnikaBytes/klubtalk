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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Render text
                    Padding(
                      padding: const EdgeInsets.only(right: 0, bottom: 4), 
                      child: Text(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Timestamp & Ticks Row (Bottom Right)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
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
                            color: message.isRead ? const Color(0xFF53BDEB) : timeColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
