import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact_model.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';

class ContactListTile extends StatelessWidget {
  final ContactModel contact;
  final bool isSelected;
  final VoidCallback onTap;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Subtle background highlight if selected? Usually standard list tile doesn't change bg color in whatsapp, 
    // but the checkmark appears. However, prompt says "Highlighted row background".
    
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected 
             ? (theme.brightness == Brightness.dark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5)) // Subtle highlight
             : null,
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            AvatarWidget(
              imageUrl: contact.avatarUrl,
              radius: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.about,
                     style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Selection Indicator
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.accentGreen, // or primary
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
