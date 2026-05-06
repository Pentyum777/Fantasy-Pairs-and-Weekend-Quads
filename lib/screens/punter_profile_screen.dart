import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PunterProfileScreen extends StatefulWidget {
  final String punterName;
  final Map<String, dynamic> punterData;
  final int season;

  const PunterProfileScreen({
    super.key,
    required this.punterName,
    required this.punterData,
    required this.season,
  });

  @override
  State<PunterProfileScreen> createState() => _PunterProfileScreenState();
}

class _PunterProfileScreenState extends State<PunterProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _uploadingPic = false;
  String? _profilePicUrl;

  static const _baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final safeName = widget.punterName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    _profilePicUrl = "$_baseUrl/profile_pics/$safeName.jpg";
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
        Uri.parse("$_baseUrl/uploadProfilePic"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "punterName": widget.punterName,
          "imageBase64": base64Image,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _profilePicUrl = "$_baseUrl${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";
          _uploadingPic = false;
        });
      } else {
        setState(() => _uploadingPic = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload photo")),
          );
        }
      }
    } catch (e) {
      setState(() => _uploadingPic = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ─── Tab Bar ─────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
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
          ),

          // ─── Tab Content ─────────────────────────────────────
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGameTypeTab("sunday_pairs", const Color(0xFF3B82F6)),
                _buildGameTypeTab("weekend_quads", const Color(0xFF8B5CF6)),
                _buildOverallTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _buildHeader() {
    // Count totals
    int totalGames = 0;
    int totalWins = 0;
    int bestScore = 0;
    for (final gt in widget.punterData.values) {
      if (gt is Map<String, dynamic>) {
        totalGames += (gt['rounds'] as int? ?? 0);
        totalWins += (gt['wins'] as int? ?? 0);
        final high = gt['highScore'] as int? ?? 0;
        if (high > bestScore) bestScore = high;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B1F7A), Color(0xFF1A1A2E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Profile pic
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.4),
                    backgroundImage:
                        _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                    onBackgroundImageError: (_, __) {},
                    child: _uploadingPic
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text(
                            _initials(widget.punterName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              widget.punterName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _headerStat("$totalGames", "Games"),
                _headerStat("$totalWins", "Wins"),
                _headerStat("$bestScore", "Best"),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
      ],
    );
  }

  // ─── Game Type Tab ────────────────────────────────────────────

  Widget _buildGameTypeTab(String gameType, Color color) {
    final d = widget.punterData[gameType] as Map<String, dynamic>?;

    if (d == null || (d['rounds'] ?? 0) == 0) {
      return Center(
        child: Text("No games played",
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    final mostSelected = d['mostSelected'] as Map<String, dynamic>?;
    final scores = (d['scores'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s))
            .toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(16),
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

        // Round-by-round
        if (scores.isNotEmpty) ...[
          const Text("Round by Round",
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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

  // ─── Overall Tab ──────────────────────────────────────────────

  Widget _buildOverallTab() {
    // Combine stats across all game types
    int totalGames = 0;
    int totalWins = 0;
    int totalScore = 0;
    int bestScore = 0;
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
      padding: const EdgeInsets.all(16),
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
      childAspectRatio: 2.0,
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
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }
}

// ─── Helper ───────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}

// ─── Pinned Tab Bar Delegate ──────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}