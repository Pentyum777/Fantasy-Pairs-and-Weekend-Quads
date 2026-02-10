import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

void main() async {
  final input = File('afl_players_2026.csv');
  final csv = const CsvToListConverter().convert(await input.readAsString());

  if (csv.isEmpty) {
    print("ERROR: CSV file is empty.");
    return;
  }

  final players = <Map<String, dynamic>>[];

  for (var i = 1; i < csv.length; i++) {
    final row = csv[i];

    final fullName = row[0].toString().trim();
    final clubFull = row[1].toString().trim();        // full name required
    final guernsey = int.tryParse(row[2].toString()) ?? 0;
    final season = int.tryParse(row[3].toString()) ?? 2026;
    final championId = row[4].toString().trim();

    players.add({
      "id": championId,
      "name": fullName,
      "club": clubFull,              // full club name
      "guernseyNumber": guernsey,
      "season": season,
    });
  }

  final wrapped = {"players": players};

  final output = File('assets/data/players_2026.json');
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(wrapped),
  );

  print("Done! Created players_2026.json with ${players.length} players.");
}