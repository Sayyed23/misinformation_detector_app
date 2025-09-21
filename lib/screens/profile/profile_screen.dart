import 'package:flutter/material.dart';
import 'package:truthlens/screens/profile/verification_history_screen.dart';
import 'package:truthlens/screens/community/badges_page.dart'; // Badges are part of user profile achievements
import 'package:truthlens/screens/profile/privacy_controls_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:google_sign_in/google_sign_in.dart'; // Removed Google Sign-In import

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // final googleSignIn = GoogleSignIn(); // Removed Google Sign-In code
    // if (await googleSignIn.isSignedIn()) {
    //   await googleSignIn.signOut();
    // }
    // Navigate to the login screen or home screen after logout
    // Assuming you have a login/auth screen to navigate to
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/auth', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildProfileTile(
              context,
              'Verification History',
              'Track past checks and saved evidence.',
              Icons.history,
              VerificationHistoryScreen()),
          _buildProfileTile(
              context,
              'Badges & Achievements',
              'Rewards for contributions and learning.',
              Icons.military_tech,
              BadgesPage()),
          _buildProfileTile(
              context,
              'Privacy Controls',
              'Manage data, notifications, and account settings.',
              Icons.privacy_tip,
              PrivacyControlsScreen()),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.logout, size: 40, color: Colors.red),
            title: Text('Logout',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.red)),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, String title, String subtitle,
      IconData icon, Widget screen) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => screen));
        },
      ),
    );
  }
}
