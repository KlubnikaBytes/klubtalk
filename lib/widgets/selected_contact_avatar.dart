import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact_model.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class SelectedContactAvatar extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onRemove;

  const SelectedContactAvatar({
    super.key,
    required this.contact,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              AvatarWidget(
                imageUrl: contact.avatarUrl,
                radius: 20, // Slightly smaller than list
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 50,
            child: Text(
              contact.name.split(' ').first, // First name only
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
