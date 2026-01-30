import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _channel = MethodChannel('com.example.whatsapp_clone/ringtone');

  // Preferences Keys
  static const _keyConversationTones = 'conversation_tones';
  static const _keyReminders = 'reminders';
  static const _keyMsgTone = 'message_tone';
  static const _keyMsgVibrate = 'message_vibrate';
  static const _keyMsgLight = 'message_light';
  static const _keyMsgPriority = 'message_priority';
  static const _keyMsgReaction = 'message_reaction';
  static const _keyCallRingtone = 'call_ringtone';
  static const _keyCallVibrate = 'call_vibrate';
  static const _keyStatusTone = 'status_tone';
  static const _keyStatusVibrate = 'status_vibrate';
  static const _keyStatusPriority = 'status_priority';
  static const _keyStatusReaction = 'status_reaction';
  static const _keyHomeClear = 'home_clear';

  // State Variables
  late SharedPreferences _prefs;
  bool _loading = true;

  bool _conversationTones = true;
  bool _reminders = true;
  
  String _msgTone = 'Default (Meteor)';
  String _msgVibrate = 'Default';
  String _msgLight = 'White';
  bool _msgPriority = false;
  bool _msgReaction = true;

  String _callRingtone = 'Default (Carnival)';
  String _callVibrate = 'Default';

  String _statusTone = 'Default (Meteor)';
  String _statusVibrate = 'Default';
  bool _statusPriority = false;
  bool _statusReaction = true;

  bool _homeClear = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _conversationTones = _prefs.getBool(_keyConversationTones) ?? true;
      _reminders = _prefs.getBool(_keyReminders) ?? true;
      
      _msgTone = _prefs.getString(_keyMsgTone) ?? 'Default (Meteor)';
      _msgVibrate = _prefs.getString(_keyMsgVibrate) ?? 'Default';
      _msgLight = _prefs.getString(_keyMsgLight) ?? 'White';
      _msgPriority = _prefs.getBool(_keyMsgPriority) ?? false;
      _msgReaction = _prefs.getBool(_keyMsgReaction) ?? true;

      _callRingtone = _prefs.getString(_keyCallRingtone) ?? 'Default (Carnival)';
      _callVibrate = _prefs.getString(_keyCallVibrate) ?? 'Default';

      _statusTone = _prefs.getString(_keyStatusTone) ?? 'Default (Meteor)';
      _statusVibrate = _prefs.getString(_keyStatusVibrate) ?? 'Default';
      _statusPriority = _prefs.getBool(_keyStatusPriority) ?? false;
      _statusReaction = _prefs.getBool(_keyStatusReaction) ?? true;

      _homeClear = _prefs.getBool(_keyHomeClear) ?? false;
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    setState(() {
      if (key == _keyConversationTones) _conversationTones = value;
      if (key == _keyReminders) _reminders = value;
      if (key == _keyMsgPriority) _msgPriority = value;
      if (key == _keyMsgReaction) _msgReaction = value;
      if (key == _keyStatusPriority) _statusPriority = value;
      if (key == _keyStatusReaction) _statusReaction = value;
      if (key == _keyHomeClear) _homeClear = value;
    });
  }

  Future<void> _saveString(String key, String value) async {
    await _prefs.setString(key, value);
    setState(() {
       // Updates handled by specific pickers calling this, but ensuring state reflects it
       if (key == _keyMsgVibrate) _msgVibrate = value;
       if (key == _keyCallVibrate) _callVibrate = value;
       if (key == _keyStatusVibrate) _statusVibrate = value;
       if (key == _keyMsgLight) _msgLight = value;
    });
  }

  Future<void> _pickTone(String key, int type) async {
    try {
      final String? uri = await _channel.invokeMethod('pickRingtone', {'type': type});
      if (uri != null) {
        await _prefs.setString(key, uri);
        setState(() {
           if (key == _keyMsgTone) _msgTone = 'Custom Tone Selected'; // Simplified for now
           if (key == _keyCallRingtone) _callRingtone = 'Custom Ringtone Selected';
           if (key == _keyStatusTone) _statusTone = 'Custom Tone Selected';
        });
      }
    } catch (e) {
      print("Error picking ringtone: $e");
    }
  }

  void _showVibratePicker(String key, String currentValue) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Off', 'Default', 'Short', 'Long'].map((option) {
            return ListTile(
              title: Text(option),
              leading: Radio<String>(
                value: option,
                groupValue: currentValue,
                onChanged: (value) {
                  if (value != null) {
                    _saveString(key, value);
                    Navigator.pop(context);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showLightPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Light'),
          children: ['None', 'White', 'Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple'].map((color) {
            return SimpleDialogOption(
              onPressed: () {
                _saveString(_keyMsgLight, color);
                Navigator.pop(context);
              },
              child: Text(color),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          _buildHeader('Conversation tones'),
          SwitchListTile(
            value: _conversationTones,
            title: const Text('Conversation tones'),
            subtitle: const Text('Play sounds for incoming and outgoing messages'),
            onChanged: (val) => _saveBool(_keyConversationTones, val),
          ),
          const Divider(),

          _buildHeader('Messages'),
          _buildListTile(
            'Notification tone',
            _msgTone,
            () => _pickTone(_keyMsgTone, 2), // 2 = TYPE_NOTIFICATION
          ),
          _buildListTile(
            'Vibrate',
            _msgVibrate,
            () => _showVibratePicker(_keyMsgVibrate, _msgVibrate),
          ),
           const ListTile(
            title: Text('Popup Notification', style: TextStyle(color: Colors.grey)),
            subtitle: Text('Not available', style: TextStyle(color: Colors.grey)),
            enabled: false,
          ),
          _buildListTile(
            'Light',
            _msgLight,
            _showLightPicker,
          ),
          SwitchListTile(
            value: _msgPriority,
            title: const Text('Use high priority notifications'),
            subtitle: const Text('Show previews of notifications at the top of the screen'),
            onChanged: (val) => _saveBool(_keyMsgPriority, val),
          ),
          SwitchListTile(
            value: _msgReaction,
            title: const Text('Reaction Notifications'),
            subtitle: const Text('Show notifications for reactions to messages you send'),
            onChanged: (val) => _saveBool(_keyMsgReaction, val),
          ),
          const Divider(),

          _buildHeader('Calls'),
          _buildListTile(
            'Ringtone',
            _callRingtone,
            () => _pickTone(_keyCallRingtone, 1), // 1 = TYPE_RINGTONE
          ),
          _buildListTile(
            'Vibrate',
            _callVibrate,
            () => _showVibratePicker(_keyCallVibrate, _callVibrate),
          ),
          const Divider(),

          _buildHeader('Status'),
           _buildListTile(
            'Notification tone',
            _statusTone,
            () => _pickTone(_keyStatusTone, 2),
          ),
           _buildListTile(
            'Vibrate',
            _statusVibrate,
            () => _showVibratePicker(_keyStatusVibrate, _statusVibrate),
          ),
           SwitchListTile(
            value: _statusPriority,
            title: const Text('Use high priority notifications'),
            subtitle: const Text('Show previews of notifications at the top of the screen'),
             onChanged: (val) => _saveBool(_keyStatusPriority, val),
          ),
           SwitchListTile(
            value: _statusReaction,
            title: const Text('Reaction Notifications'),
            subtitle: const Text('Show notifications for reactions to messages you send'),
             onChanged: (val) => _saveBool(_keyStatusReaction, val),
          ),
          const Divider(),
          
          // Home
           SwitchListTile(
            value: _homeClear,
            title: const Text('Clear Count'),
            subtitle: const Text('Your home screen badge clears completely after every time you open the app'),
             onChanged: (val) => _saveBool(_keyHomeClear, val),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
