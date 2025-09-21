import 'package:flutter/material.dart';

class ExplainCard extends StatelessWidget {
  final String title;
  final String content;

  const ExplainCard({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8.0),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            // TODO: Add share functionality
          ],
        ),
      ),
    );
  }
}
