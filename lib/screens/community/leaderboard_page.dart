import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  final List<Map<String, dynamic>> users = const [
    {'name': 'Alice', 'points': 1200, 'rank': 1},
    {'name': 'Bob', 'points': 1150, 'rank': 2},
    {'name': 'Charlie', 'points': 1100, 'rank': 3},
    {'name': 'David', 'points': 1050, 'rank': 4},
    {'name': 'Eve', 'points': 1000, 'rank': 5},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(user['rank'].toString()),
              ),
              title: Text(user['name']),
              trailing: Text('${user['points']} points'),
            ),
          );
        },
      ),
    );
  }
}
