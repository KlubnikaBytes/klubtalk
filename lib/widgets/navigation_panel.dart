import 'package:flutter/material.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class NavigationPanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final int selectedIndex;
  final Function(int) onNavigate;
  final String userName;
  final String userPhone;
  final String userAvatar;

  const NavigationPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.selectedIndex,
    required this.onNavigate,
    required this.userName,
    required this.userPhone,
    required this.userAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.75; // 75% of screen width

    return Stack(
      children: [
        // Background overlay
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: Colors.black.withOpacity(isOpen ? 0.5 : 0.0),
            ),
          ),

        // Side panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: isOpen ? 0 : -panelWidth,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Section
                  _buildProfileHeader(context),
                  
                  const SizedBox(height: 24),
                  
                  // Navigation Menu Items
                  Expanded(
                    child: _buildNavigationMenu(context),
                  ),
                  
                  // Version or footer info (optional)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'KlubTalk v1.0',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC92136).withOpacity(0.3),
            const Color(0xFFC92136).withOpacity(0.4),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Picture
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AvatarWidget(
              imageUrl: userAvatar,
              radius: 35,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Name
          Text(
            userName,
            style: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Phone Number
          Text(
            userPhone,
            style: const TextStyle(
              color: Color(0xFF5C5C5C),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu(BuildContext context) {
    final menuItems = [
      _NavMenuItem(
        icon: Icons.chat_bubble_outline,
        label: 'Chats',
        index: 0,
      ),
      _NavMenuItem(
        icon: Icons.auto_awesome_outlined,
        label: 'Updates',
        index: 1,
      ),
      _NavMenuItem(
        icon: Icons.call_outlined,
        label: 'Calls',
        index: 2,
      ),
      _NavMenuItem(
        icon: Icons.groups_outlined,
        label: 'Communities',
        index: 3,
      ),
      _NavMenuItem(
        icon: Icons.person_outline,
        label: 'Profile',
        index: 4,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final isSelected = selectedIndex == item.index;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                onNavigate(item.index);
                onClose();
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFC92136).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFC92136).withOpacity(0.3)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected
                          ? const Color(0xFFC92136)
                          : Colors.grey[700],
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFC92136)
                            : Colors.grey[800],
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavMenuItem {
  final IconData icon;
  final String label;
  final int index;

  _NavMenuItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
