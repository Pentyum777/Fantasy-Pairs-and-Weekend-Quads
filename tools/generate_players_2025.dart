import 'dart:convert';
import 'dart:io';

void main() {
  final lines = File('tools/afl_players_2025.csv').readAsLinesSync();

  final players = <Map<String, dynamic>>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    // Split by comma — your file is true CSV
    final parts = line.split(',');

    // We only need the first 5 columns
    if (parts.length < 5) continue;

    final name = parts[0].trim();
    final club = parts[1].trim();
    final guernsey = int.tryParse(parts[2].trim()) ?? 0;
    final season = int.tryParse(parts[3].trim()) ?? 2025;
    final cdid = parts[4].trim();

    if (name.isEmpty || cdid.isEmpty) continue;

    players.add({
      "id": cdid,
      "name": name,
      "club": club,
      "guernseyNumber": guernsey,
      "season": season,
    });
  }

  File('assets/data/players_2025.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({"players": players}),
  );

  print("✅ Generated players_2025.json with ${players.length} players");
}