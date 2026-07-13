import 'package:flutter/material.dart';

class LoadPaletteDialog extends StatefulWidget {
  final String initialSeason;
  final ValueChanged<String> onSeasonSelected;
  final Map<String, List<Map<String, String>>> seasonalPalettes;

  const LoadPaletteDialog({
    super.key,
    required this.initialSeason,
    required this.onSeasonSelected,
    required this.seasonalPalettes,
  });

  @override
  State<LoadPaletteDialog> createState() => _LoadPaletteDialogState();
}

class _LoadPaletteDialogState extends State<LoadPaletteDialog> {
  late String _selectedSubSeason;

  static const List<String> _subSeasons = [
    'Clear Winter',
    'Cool Winter',
    'Deep Winter',
    'Soft Summer',
    'Cool Summer',
    'Light Summer',
    'Clear Spring',
    'Warm Spring',
    'Light Spring',
    'Soft Autumn',
    'Warm Autumn',
    'Deep Autumn',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSubSeason = 'Warm ${_selectedMainSeason(widget.initialSeason)}';
    if (!_subSeasons.contains(_selectedSubSeason)) {
      _selectedSubSeason = _subSeasons.firstWhere(
        (s) => s.contains(widget.initialSeason),
        orElse: () => _subSeasons[0],
      );
    }
  }

  String _selectedMainSeason(String sub) {
    if (sub.contains('Winter')) return 'Winter';
    if (sub.contains('Summer')) return 'Summer';
    if (sub.contains('Spring')) return 'Spring';
    return 'Autumn';
  }

  @override
  Widget build(BuildContext context) {
    final main = _selectedMainSeason(_selectedSubSeason);
    final pal = widget.seasonalPalettes[main] ?? [];

    return AlertDialog(
      backgroundColor: const Color(0xFF130D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Load Palette',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a palette to load it into the Self-Analysis Studio.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '12-Season Palettes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SizedBox(
                height: 280,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subSeasons.length,
                  itemBuilder: (context, index) {
                    final sub = _subSeasons[index];
                    final isSel = _selectedSubSeason == sub;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedSubSeason = sub),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSel
                                  ? Colors.deepPurpleAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              sub,
                              style: TextStyle(
                                color:
                                    isSel ? Colors.white : Colors.white70,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              'Palette Preview',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pal.length,
                itemBuilder: (context, index) {
                  final color = Color(
                    int.parse(
                        pal[index]['hex']!.replaceFirst('#', '0xFF')),
                  );
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              widget.onSeasonSelected(main);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
