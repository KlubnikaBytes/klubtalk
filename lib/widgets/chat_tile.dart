import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/project_models.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:intl/intl.dart';

class ChatTile extends StatelessWidget {
  final Chat chat;

  const ChatTile({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: chat),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            AvatarWidget(
              imageUrl: chat.contact.avatarUrl,
              radius: 26,
              heroTag: chat.contact.id,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.contact.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(chat.lastMessage.timestamp),
                        style: TextStyle(
                          color: Theme.of(context).unselectedWidgetColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Status Icon check if sent by me
                      if (chat.lastMessage.isSentByMe)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Icon(
                            chat.lastMessage.isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: chat.lastMessage.isRead ? Colors.blue : Colors.grey,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          chat.lastMessage.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return DateFormat('h:mm a').format(date);
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    }
    return DateFormat('dd/MM/yy').format(date);
  }
}
