import 'package:flutter/material.dart';

class SeasonPalettePanel extends StatelessWidget {
  final String detectedSeason;
  final Map<String, List<Map<String, String>>> seasonalPalettes;
  final Map<String, List<Map<String, String>>> avoidPalettes;
  final Color drapeColor;
  final bool showDrapes;
  final String Function(String) skinToneLabel;
  final Color Function(String) seasonColor;
  final VoidCallback onLoadPaletteTap;
  final VoidCallback onSaveProfile;
  final ValueChanged<Color> onColorSelected;

  const SeasonPalettePanel({
    super.key,
    required this.detectedSeason,
    required this.seasonalPalettes,
    required this.avoidPalettes,
    required this.drapeColor,
    required this.showDrapes,
    required this.skinToneLabel,
    required this.seasonColor,
    required this.onLoadPaletteTap,
    required this.onSaveProfile,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pal = seasonalPalettes[detectedSeason] ?? seasonalPalettes['Autumn']!;
    final avoid = avoidPalettes[detectedSeason] ?? avoidPalettes['Autumn']!;
    final sColor = seasonColor(detectedSeason);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF130D2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onLoadPaletteTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculated Season Profile',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    skinToneLabel(detectedSeason),
                                    style: TextStyle(
                                      color: sColor,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_note_rounded,
                                  color: sColor.withValues(alpha: 0.8),
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onSaveProfile,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Save Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Best Colors',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pal.length,
                itemBuilder: (context, index) {
                  final item = pal[index];
                  final color = Color(
                    int.parse(item['hex']!.replaceFirst('#', '0xFF')),
                  );
                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: drapeColor == color && showDrapes
                                    ? Colors.greenAccent
                                    : Colors.white24,
                                width: drapeColor == color && showDrapes
                                    ? 2.0
                                    : 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Colors to Avoid',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: avoid.length,
                itemBuilder: (context, index) {
                  final item = avoid[index];
                  final color = Color(
                    int.parse(item['hex']!.replaceFirst('#', '0xFF')),
                  );
                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: drapeColor == color && showDrapes
                                    ? Colors.greenAccent
                                    : const Color(0xFFFF5252)
                                        .withValues(alpha: 0.6),
                                width: drapeColor == color && showDrapes
                                    ? 2.0
                                    : 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFFFF5252),
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
