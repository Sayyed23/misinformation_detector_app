import 'package:flutter/material.dart';

class QuizzesRewardsScreen extends StatelessWidget {
  const QuizzesRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes & Rewards'),
      ),
      body: const Center(
        child: Text(
            'Interactive challenges with badges/points to encourage learning.'),
      ),
    );
  }
}
