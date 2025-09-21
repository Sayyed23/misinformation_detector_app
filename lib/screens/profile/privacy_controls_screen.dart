import 'package:flutter/material.dart';

class PrivacyControlsScreen extends StatefulWidget {
  const PrivacyControlsScreen({super.key});

  @override
  State<PrivacyControlsScreen> createState() => _PrivacyControlsScreenState();
}

class _PrivacyControlsScreenState extends State<PrivacyControlsScreen> {
  bool _shareData = true;
  bool _receiveNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Controls'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Share Anonymized Data'),
            value: _shareData,
            onChanged: (bool value) {
              setState(() {
                _shareData = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Receive Notifications'),
            value: _receiveNotifications,
            onChanged: (bool value) {
              setState(() {
                _receiveNotifications = value;
              });
            },
          ),
          ListTile(
            title: const Text('Account Settings'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to account settings page
            },
          ),
          // TODO: Add more privacy controls as needed
        ],
      ),
    );
  }
}
