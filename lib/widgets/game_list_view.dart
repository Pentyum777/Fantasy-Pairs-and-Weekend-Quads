import 'package:flutter/material.dart';
import '../models/game.dart';

class GameListView extends StatelessWidget {
  final List<Game> games;

  const GameListView({super.key, required this.games});

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Center(
        child: Text(
          "No games available for this category.",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return Card(
          child: ListTile(
            title: Text(game.label),
            subtitle: Text("Players: ${game.players.join(', ')}"),
          ),
        );
      },
    );
  }
}