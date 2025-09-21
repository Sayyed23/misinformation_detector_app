import 'package:flutter/material.dart';

class MediaLiteracyLessonsScreen extends StatelessWidget {
  const MediaLiteracyLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Literacy Lessons'),
      ),
      body: const Center(
        child: Text('Short, gamified modules on spotting misinformation.'),
      ),
    );
  }
}
