import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/group_service.dart';
import 'package:whatsapp_clone/models/group_model.dart';

class GroupSettingsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final GroupService _groupService = GroupService();
  late String _editInfoPermission;
  late String _sendMessagePermission;
  late String _addParticipantsPermission;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _editInfoPermission = widget.group.editInfoPermission;
    _sendMessagePermission = widget.group.sendMessagePermission;
    _addParticipantsPermission = widget.group.addParticipantsPermission;
  }

  Future<void> _updatePermissions() async {
    setState(() => _isLoading = true);
    try {
      await _groupService.updatePermissions(
        chatId: widget.group.id,
        editInfoPermission: _editInfoPermission,
        sendMessagePermission: _sendMessagePermission,
        addParticipantsPermission: _addParticipantsPermission,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate changes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating permissions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
        title: const Text('Group Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _updatePermissions,
            ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          
          // Edit Group Info Permission
          _buildPermissionCard(
            title: 'Edit Group Info',
            subtitle: 'Who can edit group name, icon, and description',
            currentValue: _editInfoPermission,
            onChanged: (value) => setState(() => _editInfoPermission = value),
          ),

          const Divider(height: 1),

          // Send Messages Permission
          _buildPermissionCard(
            title: 'Send Messages',
            subtitle: 'Who can send messages in this group',
            currentValue: _sendMessagePermission,
            onChanged: (value) => setState(() => _sendMessagePermission = value),
          ),

          const Divider(height: 1),

          // Add Participants Permission
          _buildPermissionCard(
            title: 'Add Participants',
            subtitle: 'Who can add new members to this group',
            currentValue: _addParticipantsPermission,
            onChanged: (value) => setState(() => _addParticipantsPermission = value),
          ),

          const SizedBox(height: 16),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Note: Only group admins can access these settings',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // Radio Options
            RadioListTile<String>(
              title: const Text('All Participants'),
              value: 'all',
              groupValue: currentValue,
              onChanged: (value) => onChanged(value!),
              activeColor: const Color(0xFFC92136),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: const Text('Only Admins'),
              value: 'admins',
              groupValue: currentValue,
              onChanged: (value) => onChanged(value!),
              activeColor: const Color(0xFFC92136),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
