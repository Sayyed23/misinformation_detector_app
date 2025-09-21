import 'package:flutter/material.dart';
import 'package:truthlens/screens/community/badges_page.dart';
import 'package:truthlens/screens/community/discussion_forum_screen.dart';
import 'package:truthlens/screens/community/leaderboard_page.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Community',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildCommunityTile(
              context,
              'Discussion Forum',
              'Users share suspicious content and insights.',
              Icons.forum,
              DiscussionForumScreen()),
          _buildCommunityTile(
              context,
              'Badges & Achievements',
              'Rewards for contributions and learning.',
              Icons.badge,
              BadgesPage()),
          _buildCommunityTile(context, 'Leaderboard', 'See who\'s on top!',
              Icons.leaderboard, LeaderboardPage()),
        ],
      ),
    );
  }

  Widget _buildCommunityTile(BuildContext context, String title,
      String subtitle, IconData icon, Widget screen) {
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
