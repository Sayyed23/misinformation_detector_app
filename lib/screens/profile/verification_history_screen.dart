import 'package:flutter/material.dart';

class VerificationHistoryScreen extends StatelessWidget {
  const VerificationHistoryScreen({super.key});

  final List<Map<String, String>> verifications = const [
    {
      'id': '1',
      'claim': 'This is a fake news claim.',
      'status': 'Misinformation',
      'date': '2023-10-26'
    },
    {
      'id': '2',
      'claim': 'This is a true fact.',
      'status': 'Fact',
      'date': '2023-10-25'
    },
    {
      'id': '3',
      'claim': 'Another suspicious post.',
      'status': 'Unverified',
      'date': '2023-10-24'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification History'),
      ),
      body: ListView.builder(
        itemCount: verifications.length,
        itemBuilder: (context, index) {
          final verification = verifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ExpansionTile(
              title: Text(verification['claim']!),
              subtitle: Text(verification['date']!),
              trailing: Chip(
                label: Text(verification['status']!),
                backgroundColor: verification['status'] == 'Misinformation'
                    ? Colors.red.shade100
                    : verification['status'] == 'Fact'
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${verification['status']}'),
                      Text('Date: ${verification['date']}'),
                      // TODO: Add more details like evidence, source, etc.
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
