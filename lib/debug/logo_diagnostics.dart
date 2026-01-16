import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class LogoDiagnostics extends StatefulWidget {
  const LogoDiagnostics({super.key});

  @override
  State<LogoDiagnostics> createState() => _LogoDiagnosticsState();
}

class _LogoDiagnosticsState extends State<LogoDiagnostics> {
  final List<String> clubCodes = const [
    "ADE", "BRI", "CAR", "COL", "ESS", "FRE", "GEE", "GWS",
    "GCS", "HAW", "MEL", "NTH", "PTA", "RIC", "STK", "SYD",
    "WCE", "WB"
  ];

  final Map<String, bool> results = {};

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    for (final code in clubCodes) {
      final path = "assets/logos/$code.png";

      try {
        await rootBundle.load(path);
        results[code] = true;
      } catch (_) {
        results[code] = false;
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logo Diagnostics")),
      body: ListView(
        children: clubCodes.map((code) {
          final ok = results[code];

          return ListTile(
            leading: ok == true
                ? Image.asset("assets/logos/$code.png", width: 40)
                : const Icon(Icons.error, color: Colors.red),
            title: Text(code),
            subtitle: Text("assets/logos/$code.png"),
            trailing: ok == true
                ? const Text("OK", style: TextStyle(color: Colors.green))
                : const Text("MISSING", style: TextStyle(color: Colors.red)),
          );
        }).toList(),
      ),
    );
  }
}