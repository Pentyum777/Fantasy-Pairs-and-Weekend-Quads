import 'dart:io';

void main() {
  final file = File('tools/afl_players_2026.csv'); // or 'tools/afl_players_2026' if no .csv
  print('Exists: ${file.existsSync()}');

  final lines = file.readAsLinesSync();
  print('Total lines: ${lines.length}');

  final sampleCount = lines.length < 8 ? lines.length : 8;
  for (var i = 0; i < sampleCount; i++) {
    final line = lines[i];
    print('\n--- line $i raw ---');
    print(line);

    final codeUnits = line.codeUnits.take(80).toList();
    print('codeUnits: $codeUnits');

    final parts = line.split('\t');
    print('split("\\t") -> parts.length = ${parts.length}');
    for (var j = 0; j < parts.length; j++) {
      print('  [$j] "${parts[j]}"');
    }
  }
}