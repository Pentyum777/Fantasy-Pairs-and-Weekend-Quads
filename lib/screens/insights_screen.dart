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
  String _selectedPunter = _kOverall;
  String _selectedGameType = 'quads';
  bool _uploadingPic = false;
  String? _profilePicUrl;

  static const _kOverall = '📊 Overall';
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
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<String> _validPunterNames() {
    return _punters.keys
        .where((n) => n.isNotEmpty && n[0] == n[0].toUpperCase() && n[0] != n[0].toLowerCase())
        .where((n) => !RegExp(r'\d').hasMatch(n))
        .where((n) => !RegExp(r'[*#@!]').hasMatch(n))
        .toList()..sort();
  }

  void _updatePicUrl() {
    if (_selectedPunter == _kOverall) return;
    final safeName = _selectedPunter
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    _profilePicUrl = "$_baseUrl/profile_pics/$safeName.jpg?t=${DateTime.now().millisecondsSinceEpoch}";
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_selectedPunter == _kOverall) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (picked == null) return;
      setState(() => _uploadingPic = true);
      final bytes = await picked.readAsBytes();
      final res = await http.post(
        Uri.parse("$_baseUrl/uploadProfilePic"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"punterName": _selectedPunter, "imageBase64": base64Encode(bytes)}),
      );
      if (res.statusCode == 200) _updatePicUrl();
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

  // ═══════════════════════════════════════════════════════════════
  // LAYOUT HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Returns true for screens wider than 600px (tablet+)
  bool _isWide(BuildContext context) => MediaQuery.of(context).size.width > 600;

  /// Responsive horizontal padding
  double _hPad(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 1200) return (w - 900) / 2; // desktop: cap content at 900
    if (w > 800) return 40;
    if (w > 600) return 24;
    return 14;
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
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final names = _validPunterNames();
    final dropdownItems = [_kOverall, ...names];
    final pad = _hPad(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
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
              items: dropdownItems.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedPunter = val;
                  if (val != _kOverall) _updatePicUrl();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_selectedPunter == _kOverall)
          ..._buildOverallView(context)
        else
          ..._buildProfile(context),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OVERALL VIEW
  // ═══════════════════════════════════════════════════════════════

  List<Widget> _buildOverallView(BuildContext context) {
    final pairsOv = _overall['pairs'] as Map<String, dynamic>?;
    final quadsOv = _overall['quads'] as Map<String, dynamic>?;
    final active = _selectedGameType == 'pairs' ? pairsOv : quadsOv;
    final wide = _isWide(context);

    int totalPunters = _validPunterNames().length;
    int totalGames = 0;
    for (final pData in _punters.values) {
      if (pData is Map<String, dynamic>) {
        for (final gt in pData.values) {
          if (gt is Map<String, dynamic>) totalGames += (gt['rounds'] as int? ?? 0);
        }
      }
    }

    return [
      // Header
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1B3A6B), Color(0xFF1A1A3E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.all(wide ? 24 : 18),
        child: Row(children: [
          Container(
            width: wide ? 84 : 60, height: wide ? 84 : 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: wide ? 40 : 28),
          ),
          SizedBox(width: wide ? 20 : 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Overall Insights", style: TextStyle(
                color: Colors.white, fontSize: wide ? 22 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 20, runSpacing: 6, children: [
                _headerStat("$totalPunters", "Punters"),
                _headerStat("$totalGames", "Total Games"),
              ]),
            ],
          )),
        ]),
      ),
      const SizedBox(height: 12),

      // Toggle tiles
      Row(children: [
        Expanded(child: _toggleTile(
          label: "Pairs", selected: _selectedGameType == 'pairs',
          color: const Color(0xFF3B82F6),
          onTap: () => setState(() => _selectedGameType = 'pairs'),
          subtitle: pairsOv != null ? "Avg: ${pairsOv['avgScore'] ?? 0}" : "No data",
        )),
        const SizedBox(width: 10),
        Expanded(child: _toggleTile(
          label: "Quads", selected: _selectedGameType == 'quads',
          color: const Color(0xFF8B5CF6),
          onTap: () => setState(() => _selectedGameType = 'quads'),
          subtitle: quadsOv != null ? "Avg: ${quadsOv['avgScore'] ?? 0}" : "No data",
        )),
      ]),
      const SizedBox(height: 12),

      // Stats
      if (active != null) ...[
        _responsiveRow(context, [
          _infoCard(icon: Icons.person, color: const Color(0xFF8B5CF6),
            label: "Most Selected Player",
            value: active['mostSelectedPlayer'] != null ? "${active['mostSelectedPlayer']['name']}" : "–",
            subtitle: active['mostSelectedPlayer'] != null ? "${active['mostSelectedPlayer']['count']}x selected" : null),
          _infoCard(icon: Icons.emoji_events, color: const Color(0xFF4ADE80),
            label: "Most Winning Player",
            value: active['mostWinningPlayer'] != null ? "${active['mostWinningPlayer']['name']}" : "–",
            subtitle: active['mostWinningPlayer'] != null ? "${active['mostWinningPlayer']['count']} wins" : null),
        ]),
        const SizedBox(height: 10),
        _responsiveRow(context, [
          _statCard(color: const Color(0xFFEF4444), items: [
            _StatLine("Highest Score", "${active['highestScore'] ?? 0}"),
            _StatLine("Average Score", "${active['avgScore'] ?? 0}"),
          ]),
          _statCard(color: const Color(0xFF3B82F6), items: [
            _StatLine("Best Win Draft", active['mostWinningDraftPos'] != null ? "#${active['mostWinningDraftPos']}" : "–"),
            _StatLine("Avg Win Draft", active['avgWinningDraftPos'] != null ? "#${active['avgWinningDraftPos']}" : "–"),
          ]),
        ]),
      ] else
        _emptyCard("No data for this game type"),

      const SizedBox(height: 20),
    ];
  }

  // ═══════════════════════════════════════════════════════════════
  // PUNTER PROFILE
  // ═══════════════════════════════════════════════════════════════

  List<Widget> _buildProfile(BuildContext context) {
    final data = _punters[_selectedPunter] as Map<String, dynamic>? ?? {};
    final pairs = data['pairs'] as Map<String, dynamic>?;
    final quads = data['quads'] as Map<String, dynamic>?;
    final wide = _isWide(context);

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
      // Header
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF2D1B69), Color(0xFF1A1A3E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.all(wide ? 24 : 18),
        child: Row(children: [
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Stack(children: [
              CircleAvatar(
                radius: wide ? 42 : 32,
                backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.4),
                backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                onBackgroundImageError: (_, __) {},
                child: _uploadingPic
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_initials(_selectedPunter),
                        style: TextStyle(color: Colors.white, fontSize: wide ? 28 : 20, fontWeight: FontWeight.bold)),
              ),
              Positioned(bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                ),
              ),
            ]),
          ),
          SizedBox(width: wide ? 20 : 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedPunter, style: TextStyle(
                color: Colors.white, fontSize: wide ? 22 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 6, children: [
                _headerStat("$totalGames", "Games"),
                _headerStat("$totalWins", "Wins"),
                _headerStat("$bestScore", "Best"),
              ]),
            ],
          )),
        ]),
      ),
      const SizedBox(height: 12),

      // Toggle tiles
      Row(children: [
        Expanded(child: _toggleTile(
          label: "Pairs",
          selected: _selectedGameType == 'pairs',
          color: const Color(0xFF3B82F6),
          onTap: () => setState(() => _selectedGameType = 'pairs'),
          subtitle: "${pairs?['rounds'] ?? 0} games · ${pairs?['wins'] ?? 0} wins",
        )),
        const SizedBox(width: 10),
        Expanded(child: _toggleTile(
          label: "Quads",
          selected: _selectedGameType == 'quads',
          color: const Color(0xFF8B5CF6),
          onTap: () => setState(() => _selectedGameType = 'quads'),
          subtitle: "${quads?['rounds'] ?? 0} games · ${quads?['wins'] ?? 0} wins",
        )),
      ]),
      const SizedBox(height: 12),

      if (active == null || (active['rounds'] ?? 0) == 0)
        _emptyCard("No games played")
      else ...[
        // Round by Round
        if ((active['scores'] as List?)?.isNotEmpty == true)
          _buildRoundByRound(active),
        const SizedBox(height: 12),

        // Bottom stats — responsive
        _responsiveRow(context, [
          _statCard(color: const Color(0xFFEF4444), items: [
            _StatLine("Highest", "${active['highScore'] ?? 0}"),
            _StatLine("Average", "${active['avgScore'] ?? 0}"),
          ]),
          _statCard(color: const Color(0xFF3B82F6), items: [
            _StatLine("Best Draft", active['highestDraftPos'] != null ? "#${active['highestDraftPos']}" : "–"),
            _StatLine("Avg Draft", active['avgDraftPos'] != null ? "#${active['avgDraftPos']}" : "–"),
          ]),
          _buildTopPlayers(active),
        ]),
      ],

      const SizedBox(height: 20),
    ];
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════

  /// On wide screens: Row. On narrow screens: Column.
  Widget _responsiveRow(BuildContext context, List<Widget> children) {
    if (_isWide(context)) {
      final List<Widget> rowChildren = [];
      for (int i = 0; i < children.length; i++) {
        if (i > 0) rowChildren.add(const SizedBox(width: 10));
        rowChildren.add(Expanded(child: children[i]));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      );
    }
    return Column(
      children: children.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  Widget _toggleTile({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : const Color(0xFF1E1E3A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.white10, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
              color: selected ? color : Colors.white54, fontSize: 15, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(
                color: selected ? Colors.white70 : Colors.white38, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoundByRound(Map<String, dynamic> d) {
    final scores = (d['scores'] as List?)
        ?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
    if (scores.isEmpty) return const SizedBox.shrink();
    final highScore = d['highScore'] as int? ?? 1;
    final avgScore = d['avgScore'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Round by Round",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text("Avg: $avgScore", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          ...scores.map((s) {
            final score = s['score'] as int? ?? 0;
            final isAbove = score >= avgScore;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 46, child: Text("Rd ${s['round']}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: highScore > 0 ? (score / highScore).clamp(0.0, 1.0) : 0,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      isAbove ? const Color(0xFF4ADE80) : const Color(0xFFEF4444)),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 36, child: Text("$score", textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isAbove ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold, fontSize: 14))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopPlayers(Map<String, dynamic> d) {
    List<MapEntry<String, int>> topPlayers = [];
    if (d['playerCounts'] is Map) {
      final counts = Map<String, dynamic>.from(d['playerCounts'] as Map);
      topPlayers = counts.entries
          .map((e) => MapEntry(e.key, (e.value as int?) ?? 0))
          .toList()..sort((a, b) => b.value.compareTo(a.value));
      if (topPlayers.length > 3) topPlayers = topPlayers.sublist(0, 3);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Players",
              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
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
                  Text("${p.value}x", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
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
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(item.value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.white54))),
    );
  }
}

class _StatLine {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);
}
