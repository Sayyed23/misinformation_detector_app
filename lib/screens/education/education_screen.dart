import 'package:flutter/material.dart';
import 'package:truthlens/screens/education/media_literacy_lessons_screen.dart';
import 'package:truthlens/screens/education/quizzes_rewards_screen.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Education Hub',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildEducationTile(
              context,
              'Media Literacy Lessons',
              'Short, gamified modules on spotting misinformation.',
              Icons.menu_book,
              MediaLiteracyLessonsScreen()),
          _buildEducationTile(
              context,
              'Quizzes & Rewards',
              'Interactive challenges with badges/points to encourage learning.',
              Icons.quiz,
              QuizzesRewardsScreen()),
          // For Explain Cards, it's a widget, so it will be integrated within other screens or a dedicated screen to list them.
        ],
      ),
    );
  }

  Widget _buildEducationTile(BuildContext context, String title,
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
