import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InsightsScreen extends StatefulWidget {
  final int season;

  const InsightsScreen({super.key, required this.season});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _punters = {};
  Map<String, dynamic> _overall = {};
  String? _selectedPunter;

  static const _baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse("$_baseUrl/punterInsights?season=${widget.season}"),
      );

      if (res.statusCode != 200) {
        throw Exception("Server returned ${res.statusCode}");
      }

      final data = jsonDecode(res.body);
      if (data['ok'] != true) {
        throw Exception(data['error'] ?? "Unknown error");
      }

      setState(() {
        _punters = Map<String, dynamic>.from(data['punters'] ?? {});
        _overall = Map<String, dynamic>.from(data['overall'] ?? {});
        _loading = false;

        // Auto-select first punter
        if (_selectedPunter == null && _punters.isNotEmpty) {
          _selectedPunter = _punters.keys.first;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Insights"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: "Punter View"),
            Tab(text: "Overall"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPunterView(),
                    _buildOverallView(),
                  ],
                ),
    );
  }

  // ─── Punter View ──────────────────────────────────────────────

  Widget _buildPunterView() {
    if (_punters.isEmpty) {
      return const Center(child: Text("No punter data available"));
    }

    final sortedNames = _punters.keys.toList()..sort();

    return Column(
      children: [
        // Punter selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: DropdownButtonFormField<String>(
            value: _selectedPunter,
            decoration: InputDecoration(
              labelText: "Select Punter",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: sortedNames
                .map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedPunter = val),
          ),
        ),

        // Stats cards
        Expanded(
          child: _selectedPunter == null
              ? const Center(child: Text("Select a punter"))
              : _buildPunterStats(_selectedPunter!),
        ),
      ],
    );
  }

  Widget _buildPunterStats(String punterName) {
    final data = _punters[punterName] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGameTypeCard(
          "Sunday Pairs",
          data['sunday_pairs'] as Map<String, dynamic>?,
          Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildGameTypeCard(
          "Weekend Quads",
          data['weekend_quads'] as Map<String, dynamic>?,
          Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildGameTypeCard(
      String title, Map<String, dynamic>? data, Color color) {
    if (data == null || (data['rounds'] ?? 0) == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 8),
              Text("No games played",
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final mostSelected = data['mostSelected'] as Map<String, dynamic>?;
    final scores = (data['scores'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s))
            .toList() ??
        [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${data['rounds']} games",
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "${data['wins'] ?? 0} wins",
              style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _statRow("Highest Score", "${data['highScore'] ?? 0}"),
            _statRow("Average Score", "${data['avgScore'] ?? 0}"),
            _statRow(
              "Most Selected Player",
              mostSelected != null
                  ? "${mostSelected['name']} (${mostSelected['count']}x)"
                  : "–",
            ),
            _statRow(
              "Highest Draft Position",
              data['highestDraftPos'] != null
                  ? "#${data['highestDraftPos']}"
                  : "–",
            ),
            _statRow(
              "Average Draft Position",
              data['avgDraftPos'] != null
                  ? "#${data['avgDraftPos']}"
                  : "–",
            ),
            if (scores.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text("Round-by-Round",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              ...scores.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text("Rd ${s['round']}",
                              style: TextStyle(color: Colors.grey[600])),
                        ),
                        Text("${s['score']}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[700])),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  // ─── Overall View ─────────────────────────────────────────────

  Widget _buildOverallView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverallCard(
          "Sunday Pairs",
          _overall['sunday_pairs'] as Map<String, dynamic>?,
          Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildOverallCard(
          "Weekend Quads",
          _overall['weekend_quads'] as Map<String, dynamic>?,
          Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildOverallCard(
      String title, Map<String, dynamic>? data, Color color) {
    if (data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 8),
              Text("No data available",
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final mostSelected = data['mostSelectedPlayer'] as Map<String, dynamic>?;
    final mostWinning = data['mostWinningPlayer'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 16),
            _statRow(
              "Most Selected Player",
              mostSelected != null
                  ? "${mostSelected['name']} (${mostSelected['count']}x)"
                  : "–",
            ),
            _statRow(
              "Most Winning Player",
              mostWinning != null
                  ? "${mostWinning['name']} (${mostWinning['count']} wins)"
                  : "–",
            ),
            _statRow("Highest Score", "${data['highestScore'] ?? 0}"),
            _statRow("Average Score", "${data['avgScore'] ?? 0}"),
            _statRow(
              "Most Winning Draft Position",
              data['mostWinningDraftPos'] != null
                  ? "#${data['mostWinningDraftPos']}"
                  : "–",
            ),
            _statRow(
              "Average Winning Draft Position",
              data['avgWinningDraftPos'] != null
                  ? "#${data['avgWinningDraftPos']}"
                  : "–",
            ),
          ],
        ),
      ),
    );
  }
}
