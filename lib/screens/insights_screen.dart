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
  bool _showOverall = true;

  static const _baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _loadData();
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
              : Row(
                  children: [
                    // ─── Left panel: punter list ───────────────────
                    _buildLeftPanel(),
                    // ─── Right panel: selected content ─────────────
                    Expanded(child: _buildRightPanel()),
                  ],
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LEFT PANEL — Punter list
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLeftPanel() {
    final names = _punters.keys.toList()..sort();

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Color(0xFF151530),
        border: Border(right: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          // Overall button
          _navItem(
            label: "Overall",
            icon: Icons.bar_chart_rounded,
            selected: _showOverall,
            onTap: () => setState(() {
              _showOverall = true;
              _selectedPunter = null;
            }),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("PUNTERS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
            ),
          ),
          // Punter list
          Expanded(
            child: ListView.builder(
              itemCount: names.length,
              itemBuilder: (context, index) {
                final name = names[index];
                final data = _punters[name] as Map<String, dynamic>? ?? {};
                int totalWins = 0;
                for (final gt in data.values) {
                  if (gt is Map<String, dynamic>) {
                    totalWins += (gt['wins'] as int? ?? 0);
                  }
                }

                return _navItem(
                  label: name,
                  subtitle: "$totalWins wins",
                  selected: !_showOverall && _selectedPunter == name,
                  onTap: () => setState(() {
                    _showOverall = false;
                    _selectedPunter = name;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required String label,
    String? subtitle,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFF8B5CF6) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: selected ? const Color(0xFF8B5CF6) : Colors.white54, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RIGHT PANEL
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRightPanel() {
    if (_showOverall) return _buildOverallPanel();
    if (_selectedPunter == null) {
      return const Center(
        child: Text("Select a punter", style: TextStyle(color: Colors.white38, fontSize: 16)),
      );
    }
    return _PunterProfilePanel(
      punterName: _selectedPunter!,
      punterData: _punters[_selectedPunter!] as Map<String, dynamic>? ?? {},
      baseUrl: _baseUrl,
    );
  }

  // ─── Overall Panel ────────────────────────────────────────────

  Widget _buildOverallPanel() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text("Overall Insights",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
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
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 16),
          if (d == null)
            const Text("No data available", style: TextStyle(color: Colors.white54))
          else ...[
            _statRow("Most Selected Player",
                d['mostSelectedPlayer'] != null
                    ? "${d['mostSelectedPlayer']['name']} (${d['mostSelectedPlayer']['count']}x)"
                    : "–"),
            _statRow("Most Winning Player",
                d['mostWinningPlayer'] != null
                    ? "${d['mostWinningPlayer']['name']} (${d['mostWinningPlayer']['count']} wins)"
                    : "–"),
            _statRow("Highest Score", "${d['highestScore'] ?? 0}"),
            _statRow("Average Score", "${d['avgScore'] ?? 0}"),
            _statRow("Best Winning Draft Pos",
                d['mostWinningDraftPos'] != null ? "#${d['mostWinningDraftPos']}" : "–"),
            _statRow("Avg Winning Draft Pos",
                d['avgWinningDraftPos'] != null ? "#${d['avgWinningDraftPos']}" : "–"),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }
}

// ═══════════════════════════════════════════════════════════════════
// PUNTER PROFILE PANEL (shown on the right when a punter is selected)
// ═══════════════════════════════════════════════════════════════════

class _PunterProfilePanel extends StatefulWidget {
  final String punterName;
  final Map<String, dynamic> punterData;
  final String baseUrl;

  const _PunterProfilePanel({
    required this.punterName,
    required this.punterData,
    required this.baseUrl,
  });

  @override
  State<_PunterProfilePanel> createState() => _PunterProfilePanelState();
}

class _PunterProfilePanelState extends State<_PunterProfilePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _profilePicUrl;
  bool _uploadingPic = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updatePicUrl();
  }

  @override
  void didUpdateWidget(covariant _PunterProfilePanel old) {
    super.didUpdateWidget(old);
    if (old.punterName != widget.punterName) {
      _tabController.index = 0;
      _updatePicUrl();
    }
  }

  void _updatePicUrl() {
    final safeName = widget.punterName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    _profilePicUrl = "${widget.baseUrl}/profile_pics/$safeName.jpg";
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _uploadingPic = true);
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final res = await http.post(
        Uri.parse("${widget.baseUrl}/uploadProfilePic"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "punterName": widget.punterName,
          "imageBase64": base64Image,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _profilePicUrl =
              "${widget.baseUrl}${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";
          _uploadingPic = false;
        });
      } else {
        setState(() => _uploadingPic = false);
      }
    } catch (e) {
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
    // Totals across all game types
    int totalGames = 0, totalWins = 0, bestScore = 0;
    for (final gt in widget.punterData.values) {
      if (gt is Map<String, dynamic>) {
        totalGames += (gt['rounds'] as int? ?? 0);
        totalWins += (gt['wins'] as int? ?? 0);
        final high = gt['highScore'] as int? ?? 0;
        if (high > bestScore) bestScore = high;
      }
    }

    return Column(
      children: [
        // ─── Header ──────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B1F7A), Color(0xFF1A1A2E)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              // Profile pic
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.4),
                      backgroundImage:
                          _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                      onBackgroundImageError: (_, __) {},
                      child: _uploadingPic
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              _initials(widget.punterName),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Name + quick stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.punterName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _quickStat("$totalGames", "Games"),
                        const SizedBox(width: 24),
                        _quickStat("$totalWins", "Wins"),
                        const SizedBox(width: 24),
                        _quickStat("$bestScore", "Best"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── Tabs ────────────────────────────────────────────
        Container(
          color: const Color(0xFF1A1A2E),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF8B5CF6),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Pairs"),
              Tab(text: "Quads"),
              Tab(text: "Overall"),
            ],
          ),
        ),

        // ─── Tab content ─────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGameTypeTab("sunday_pairs", const Color(0xFF3B82F6)),
              _buildGameTypeTab("weekend_quads", const Color(0xFF8B5CF6)),
              _buildCombinedTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  // ─── Game Type Tab ────────────────────────────────────────────

  Widget _buildGameTypeTab(String gameType, Color color) {
    final d = widget.punterData[gameType] as Map<String, dynamic>?;

    if (d == null || (d['rounds'] ?? 0) == 0) {
      return const Center(
          child: Text("No games played", style: TextStyle(color: Colors.white54)));
    }

    final mostSelected = d['mostSelected'] as Map<String, dynamic>?;
    final scores = (d['scores'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s))
            .toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Wins badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: color, size: 18),
              const SizedBox(width: 6),
              Text("${d['wins'] ?? 0} wins from ${d['rounds']} games",
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats grid
        _statsGrid(color, [
          _StatItem("Highest Score", "${d['highScore'] ?? 0}"),
          _StatItem("Average Score", "${d['avgScore'] ?? 0}"),
          _StatItem("Best Draft Pos",
              d['highestDraftPos'] != null ? "#${d['highestDraftPos']}" : "–"),
          _StatItem("Avg Draft Pos",
              d['avgDraftPos'] != null ? "#${d['avgDraftPos']}" : "–"),
        ]),
        const SizedBox(height: 20),

        // Most selected player
        if (mostSelected != null)
          _infoCard(
            icon: Icons.person,
            color: color,
            label: "Most Selected Player",
            value: "${mostSelected['name']}",
            subtitle: "Selected ${mostSelected['count']} times",
          ),
        const SizedBox(height: 20),

        // Round by round
        if (scores.isNotEmpty) ...[
          const Text("Round by Round",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...scores.map((s) {
            final score = s['score'] as int? ?? 0;
            final avgScore = d['avgScore'] as int? ?? 1;
            final isAbove = score >= avgScore;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF252547),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text("Rd ${s['round']}",
                        style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (score / (d['highScore'] as int? ?? 1)).clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(
                          isAbove ? Colors.green.shade400 : Colors.red.shade400,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text("$score",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isAbove ? Colors.green.shade300 : Colors.red.shade300,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ─── Combined / Overall Tab ───────────────────────────────────

  Widget _buildCombinedTab() {
    int totalGames = 0, totalWins = 0, totalScore = 0, bestScore = 0;
    final Map<String, int> allPlayerCounts = {};

    for (final gt in widget.punterData.values) {
      if (gt is! Map<String, dynamic>) continue;
      totalGames += (gt['rounds'] as int? ?? 0);
      totalWins += (gt['wins'] as int? ?? 0);
      totalScore += (gt['totalScore'] as int? ?? 0);
      final high = gt['highScore'] as int? ?? 0;
      if (high > bestScore) bestScore = high;

      if (gt['mostSelected'] is Map<String, dynamic>) {
        final ms = gt['mostSelected'] as Map<String, dynamic>;
        final name = ms['name'] as String? ?? "";
        final count = ms['count'] as int? ?? 0;
        allPlayerCounts[name] = (allPlayerCounts[name] ?? 0) + count;
      }
    }

    final avgScore = totalGames > 0 ? (totalScore / totalGames).round() : 0;
    String topPlayer = "–";
    if (allPlayerCounts.isNotEmpty) {
      final sorted = allPlayerCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topPlayer = "${sorted.first.key} (${sorted.first.value}x)";
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _statsGrid(const Color(0xFF8B5CF6), [
          _StatItem("Total Games", "$totalGames"),
          _StatItem("Total Wins", "$totalWins"),
          _StatItem("Highest Score", "$bestScore"),
          _StatItem("Average Score", "$avgScore"),
        ]),
        const SizedBox(height: 20),
        _infoCard(
          icon: Icons.person,
          color: const Color(0xFF8B5CF6),
          label: "Most Selected Player",
          value: topPlayer,
          subtitle: "Across all game types",
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.percent,
          color: const Color(0xFF3B82F6),
          label: "Win Rate",
          value: totalGames > 0
              ? "${(totalWins / totalGames * 100).toStringAsFixed(0)}%"
              : "–",
          subtitle: "$totalWins wins from $totalGames games",
        ),
      ],
    );
  }

  // ─── Reusable Widgets ─────────────────────────────────────────

  Widget _statsGrid(Color color, List<_StatItem> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: items.map((item) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252547),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(item.label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252547),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}
