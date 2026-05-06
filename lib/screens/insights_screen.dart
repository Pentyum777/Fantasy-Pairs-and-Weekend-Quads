import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class InsightsScreen extends StatefulWidget {
  final int season;
  const InsightsScreen({super.key, required this.season});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _punters = {};
  Map<String, dynamic> _overall = {};
  String? _selectedPunter;
  String _selectedGameType = 'quads'; // default tab
  bool _uploadingPic = false;
  String? _profilePicUrl;

  static const _baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse("$_baseUrl/punterInsights?season=${widget.season}"));
      if (res.statusCode != 200) throw Exception("Server returned ${res.statusCode}");
      final data = jsonDecode(res.body);
      if (data['ok'] != true) throw Exception(data['error'] ?? "Unknown error");
      setState(() {
        _punters = Map<String, dynamic>.from(data['punters'] ?? {});
        _overall = Map<String, dynamic>.from(data['overall'] ?? {});
        _loading = false;
        // Auto-select first valid punter
        final valid = _validPunterNames();
        if (valid.isNotEmpty && _selectedPunter == null) {
          _selectedPunter = valid.first;
          _updatePicUrl();
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Only punters whose name starts with a capital letter
  List<String> _validPunterNames() {
    return _punters.keys
        .where((n) => n.isNotEmpty && n[0] == n[0].toUpperCase() && n[0] != n[0].toLowerCase())
        .where((n) => !RegExp(r'\d').hasMatch(n))
        .where((n) => !RegExp(r'[*#@!]').hasMatch(n))
        .toList()
      ..sort();
  }

  void _updatePicUrl() {
    if (_selectedPunter == null) return;
    final safeName = _selectedPunter!
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    _profilePicUrl = "$_baseUrl/profile_pics/$safeName.jpg?t=${DateTime.now().millisecondsSinceEpoch}";
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_selectedPunter == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploadingPic = true);
      final bytes = await picked.readAsBytes();
      final res = await http.post(
        Uri.parse("$_baseUrl/uploadProfilePic"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"punterName": _selectedPunter, "imageBase64": base64Encode(bytes)}),
      );
      if (res.statusCode == 200) {
        _updatePicUrl();
      }
      setState(() => _uploadingPic = false);
    } catch (_) {
      setState(() => _uploadingPic = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121225),
      appBar: AppBar(
        title: const Text("Insights", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121225),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadData,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                    child: const Text("Retry")),
                ]))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final names = _validPunterNames();
    if (names.isEmpty) {
      return const Center(child: Text("No punter data", style: TextStyle(color: Colors.white54)));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // ─── Dropdown ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPunter,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E3A),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              items: names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedPunter = val;
                  _updatePicUrl();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_selectedPunter != null) ..._buildProfile(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════

  List<Widget> _buildProfile() {
    final data = _punters[_selectedPunter!] as Map<String, dynamic>? ?? {};
    final pairs = data['pairs'] as Map<String, dynamic>?;
    final quads = data['quads'] as Map<String, dynamic>?;

    int totalGames = 0, totalWins = 0, bestScore = 0;
    for (final gt in data.values) {
      if (gt is Map<String, dynamic>) {
        totalGames += (gt['rounds'] as int? ?? 0);
        totalWins += (gt['wins'] as int? ?? 0);
        final h = gt['highScore'] as int? ?? 0;
        if (h > bestScore) bestScore = h;
      }
    }

    final active = _selectedGameType == 'pairs' ? pairs : quads;

    return [
      // ─── Header card ────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1B69), Color(0xFF1A1A3E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            // Profile pic
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.4),
                  backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                  onBackgroundImageError: (_, __) {},
                  child: _uploadingPic
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_initials(_selectedPunter!),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                Positioned(bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 20),
            // Name + overall stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedPunter!,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _headerStat("$totalGames", "Games"),
                    const SizedBox(width: 20),
                    _headerStat("$totalWins", "Wins"),
                    const SizedBox(width: 20),
                    _headerStat("$bestScore", "Best"),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ─── Pairs / Quads toggle tiles ─────────────────────
      Row(children: [
        Expanded(child: _toggleTile(
          label: "Pairs",
          games: pairs?['rounds'] ?? 0,
          wins: pairs?['wins'] ?? 0,
          selected: _selectedGameType == 'pairs',
          color: const Color(0xFF3B82F6),
          onTap: () => setState(() => _selectedGameType = 'pairs'),
        )),
        const SizedBox(width: 12),
        Expanded(child: _toggleTile(
          label: "Quads",
          games: quads?['rounds'] ?? 0,
          wins: quads?['wins'] ?? 0,
          selected: _selectedGameType == 'quads',
          color: const Color(0xFF8B5CF6),
          onTap: () => setState(() => _selectedGameType = 'quads'),
        )),
      ]),
      const SizedBox(height: 16),

      // ─── Round by Round ─────────────────────────────────
      if (active != null && (active['scores'] as List?)?.isNotEmpty == true)
        _buildRoundByRound(active),

      const SizedBox(height: 16),

      // ─── Bottom stat cards ──────────────────────────────
      if (active != null) _buildBottomStats(active),

      const SizedBox(height: 24),
    ];
  }

  Widget _headerStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  Widget _toggleTile({
    required String label,
    required int games,
    required int wins,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : const Color(0xFF1E1E3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.white10, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
              color: selected ? color : Colors.white54,
              fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("$games games · $wins wins",
                style: TextStyle(color: selected ? Colors.white70 : Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── Round by Round card ────────────────────────────────────

  Widget _buildRoundByRound(Map<String, dynamic> d) {
    final scores = (d['scores'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s))
            .toList() ?? [];
    if (scores.isEmpty) return const SizedBox.shrink();

    final highScore = d['highScore'] as int? ?? 1;
    final avgScore = d['avgScore'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Round by Round",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text("Avg: $avgScore", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 14),
          ...scores.map((s) {
            final score = s['score'] as int? ?? 0;
            final isAbove = score >= avgScore;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 50,
                  child: Text("Rd ${s['round']}", style: const TextStyle(color: Colors.white54, fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: highScore > 0 ? (score / highScore).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(isAbove ? const Color(0xFF4ADE80) : const Color(0xFFEF4444)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 40,
                  child: Text("$score", textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isAbove ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold, fontSize: 15))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ─── Bottom stat cards ──────────────────────────────────────

  Widget _buildBottomStats(Map<String, dynamic> d) {
    final mostSelected = d['mostSelected'] as Map<String, dynamic>?;

    // Build top 3 selected players from playerCounts if available
    List<MapEntry<String, int>> topPlayers = [];
    if (d['playerCounts'] is Map) {
      final counts = Map<String, dynamic>.from(d['playerCounts'] as Map);
      topPlayers = counts.entries
          .map((e) => MapEntry(e.key, (e.value as int?) ?? 0))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topPlayers.length > 3) topPlayers = topPlayers.sublist(0, 3);
    } else if (mostSelected != null) {
      topPlayers = [MapEntry(mostSelected['name'] as String? ?? "–", mostSelected['count'] as int? ?? 0)];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Highest / Avg Score
        Expanded(child: _statCard(
          color: const Color(0xFFEF4444),
          items: [
            _StatLine("Highest", "${d['highScore'] ?? 0}"),
            _StatLine("Average", "${d['avgScore'] ?? 0}"),
          ],
        )),
        const SizedBox(width: 10),
        // Draft position
        Expanded(child: _statCard(
          color: const Color(0xFF3B82F6),
          items: [
            _StatLine("Best Draft", d['highestDraftPos'] != null ? "#${d['highestDraftPos']}" : "–"),
            _StatLine("Avg Draft", d['avgDraftPos'] != null ? "#${d['avgDraftPos']}" : "–"),
          ],
        )),
        const SizedBox(width: 10),
        // Top 3 players
        Expanded(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E3A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Top Players",
                  style: TextStyle(color: const Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (topPlayers.isEmpty)
                const Text("–", style: TextStyle(color: Colors.white54))
              else
                ...topPlayers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Text("${i + 1}. ", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      Expanded(child: Text(p.key,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text("${p.value}x",
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  );
                }),
            ],
          ),
        )),
      ],
    );
  }

  Widget _statCard({required Color color, required List<_StatLine> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(item.value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _StatLine {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);
}
