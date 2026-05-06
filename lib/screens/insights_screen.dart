import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'punter_profile_screen.dart';

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
      if (res.statusCode != 200) throw Exception("Server returned ${res.statusCode}");
      final data = jsonDecode(res.body);
      if (data['ok'] != true) throw Exception(data['error'] ?? "Unknown error");

      setState(() {
        _punters = Map<String, dynamic>.from(data['punters'] ?? {});
        _overall = Map<String, dynamic>.from(data['overall'] ?? {});
        _loading = false;
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Insights", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Overall"),
            Tab(text: "Punters"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverallTab(),
                    _buildPuntersTab(),
                  ],
                ),
    );
  }

  // ─── Overall Tab ──────────────────────────────────────────────

  Widget _buildOverallTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverallCard("Sunday Pairs", _overall['sunday_pairs'], const Color(0xFF3B82F6)),
        const SizedBox(height: 16),
        _buildOverallCard("Weekend Quads", _overall['weekend_quads'], const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _buildOverallCard(String title, dynamic data, Color color) {
    final d = data is Map<String, dynamic> ? data : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 16),
          if (d == null)
            Text("No data available", style: TextStyle(color: Colors.white54))
          else ...[
            _overallStat("Most Selected Player",
                d['mostSelectedPlayer'] != null
                    ? "${d['mostSelectedPlayer']['name']} (${d['mostSelectedPlayer']['count']}x)"
                    : "–"),
            _overallStat("Most Winning Player",
                d['mostWinningPlayer'] != null
                    ? "${d['mostWinningPlayer']['name']} (${d['mostWinningPlayer']['count']} wins)"
                    : "–"),
            _overallStat("Highest Score", "${d['highestScore'] ?? 0}"),
            _overallStat("Average Score", "${d['avgScore'] ?? 0}"),
            _overallStat("Best Winning Draft Pos",
                d['mostWinningDraftPos'] != null ? "#${d['mostWinningDraftPos']}" : "–"),
            _overallStat("Avg Winning Draft Pos",
                d['avgWinningDraftPos'] != null ? "#${d['avgWinningDraftPos']}" : "–"),
          ],
        ],
      ),
    );
  }

  Widget _overallStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  // ─── Punters Tab ──────────────────────────────────────────────

  Widget _buildPuntersTab() {
    if (_punters.isEmpty) {
      return const Center(child: Text("No punters found", style: TextStyle(color: Colors.white54)));
    }

    final names = _punters.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final data = _punters[name] as Map<String, dynamic>? ?? {};

        // Count total rounds and wins across all game types
        int totalRounds = 0;
        int totalWins = 0;
        for (final gt in data.values) {
          if (gt is Map<String, dynamic>) {
            totalRounds += (gt['rounds'] as int? ?? 0);
            totalWins += (gt['wins'] as int? ?? 0);
          }
        }

        final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').replaceAll(RegExp(r'\s+'), '_');
        final picUrl = "$_baseUrl/profile_pics/$safeName.jpg";

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PunterProfileScreen(
                  punterName: name,
                  punterData: data,
                  season: widget.season,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252547),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile pic
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                  backgroundImage: NetworkImage(picUrl),
                  onBackgroundImageError: (_, __) {},
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Quick stats
                Text(
                  "$totalRounds games · $totalWins wins",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }
}