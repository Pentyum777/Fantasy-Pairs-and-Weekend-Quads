import 'package:flutter/material.dart';

class SeasonSelectionScreen extends StatelessWidget {
  final List<int> seasons;
  final void Function(int season) onSelect;

  const SeasonSelectionScreen({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  Widget buildProTile({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool mobile = isPortraitPhone(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mobile ? 14 : 20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: mobile ? 8 : 12,
            horizontal: mobile ? 6 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 14 : 20),
            color: Colors.grey.shade900.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: mobile ? 4 : 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade300.withValues(alpha: 0.6),
              width: mobile ? 1.1 : 1.4,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 12 : 16,
                color: Colors.grey.shade100,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = isPortraitPhone(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Select Season"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobile ? 3 : 5,
              mainAxisSpacing: mobile ? 10 : 12,
              crossAxisSpacing: mobile ? 10 : 12,
              childAspectRatio: mobile ? 2.4 : 4.2,
            ),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];

              return buildProTile(
                context: context,
                label: "$season",
                onTap: () => onSelect(season),
              );
            },
          ),
        ),
      ),
    );
  }
}