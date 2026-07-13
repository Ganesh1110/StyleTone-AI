import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/color_recommendation.dart';

class OutfitSlot {
  final String garmentLabel;
  final IconData icon;
  final String hex;
  final String colorLabel;
  final bool isKeyPiece;

  const OutfitSlot(
    this.garmentLabel,
    this.icon,
    this.hex,
    this.colorLabel,
    this.isKeyPiece,
  );
}

class ReadyToWearBlueprintSheet extends StatefulWidget {
  final String focusHex;
  final String focusLabel;
  final ColorRecommendation rec;
  final String initialOccasion;

  const ReadyToWearBlueprintSheet({
    super.key,
    required this.focusHex,
    required this.focusLabel,
    required this.rec,
    required this.initialOccasion,
  });

  @override
  State<ReadyToWearBlueprintSheet> createState() =>
      _ReadyToWearBlueprintSheetState();
}

class _ReadyToWearBlueprintSheetState
    extends State<ReadyToWearBlueprintSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _occasions = ['office', 'party', 'casual'];
  static const _occLabels = ['Office', 'Party', 'Casual'];

  @override
  void initState() {
    super.initState();
    final idx = _occasions.indexOf(widget.initialOccasion);
    _tabController = TabController(
      length: _occasions.length,
      vsync: this,
      initialIndex: idx >= 0 ? idx : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusColor = _safeColor(widget.focusHex);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF130D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: focusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: focusColor.withOpacity(0.45),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.focusLabel} — ${widget.focusHex.toUpperCase()}',
                        style: TextStyle(
                          color: focusColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Ready-to-Wear Blueprint',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Your complete outfit, every occasion.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                tabs: _occLabels.map((l) => Tab(text: l)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _occasions.map(_buildOutfitStack).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitStack(String occasionKey) {
    final palette =
        widget.rec.palettes[occasionKey] ?? widget.rec.palettes['casual']!;
    final slots = _outfitSlots(occasionKey, palette);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tagline(occasionKey),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          ...slots.asMap().entries.map(
                (e) => _slotRow(e.value)
                    .animate()
                    .fadeIn(delay: (e.key * 70).ms, duration: 280.ms)
                    .slideX(begin: 0.06, end: 0),
              ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Shop the Look — retail partners coming soon!'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined,
                  color: Colors.white, size: 18),
              label: const Text(
                'Shop the Look',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotRow(OutfitSlot slot) {
    final c = _safeColor(slot.hex);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slot.isKeyPiece
            ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: slot.isKeyPiece
              ? Theme.of(context).colorScheme.primary.withOpacity(0.45)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: Colors.white.withOpacity(0.18), width: 1.5),
              boxShadow: slot.isKeyPiece
                  ? [
                      BoxShadow(
                          color: c.withOpacity(0.55),
                          blurRadius: 14,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(slot.icon, color: Colors.white60, size: 14),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        slot.garmentLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(slot.colorLabel,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11.5)),
                Text(
                  slot.hex.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (slot.isKeyPiece)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'KEY',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  List<OutfitSlot> _outfitSlots(String occasionKey, OccasionPalette palette) {
    final primary = palette.primaryColor;
    final secondary = palette.secondaryColor;
    final accent = palette.accentColor;

    final pc = _safeColor(primary);
    final hsl = HSLColor.fromColor(pc);
    final darkNeutral = hsl
        .withSaturation((hsl.saturation * 0.1).clamp(0.0, 1.0))
        .withLightness(0.12)
        .toColor();
    final darkHex = '#'
        '${darkNeutral.red.toRadixString(16).padLeft(2, '0')}'
        '${darkNeutral.green.toRadixString(16).padLeft(2, '0')}'
        '${darkNeutral.blue.toRadixString(16).padLeft(2, '0')}';

    switch (occasionKey) {
      case 'office':
        return [
          OutfitSlot('Blazer / Outerwear', Icons.business_center_rounded,
              primary, 'Primary — Key Piece', true),
          OutfitSlot('Shirt / Blouse', Icons.dry_cleaning_rounded,
              secondary, 'Secondary Color', false),
          OutfitSlot('Trousers / Skirt', Icons.straighten_rounded,
              darkHex, 'Dark Neutral', false),
          OutfitSlot('Shoes / Loafers', Icons.hiking_rounded,
              accent, 'Accent Color', false),
        ];
      case 'party':
        return [
          OutfitSlot('Statement Dress / Top', Icons.celebration_rounded,
              primary, 'Primary — Star Piece', true),
          OutfitSlot('Evening Jacket / Wrap',
              Icons.local_fire_department_rounded, accent, 'Accent Color', false),
          OutfitSlot('Trousers / Bottoms', Icons.straighten_rounded,
              darkHex, 'Dark Neutral', false),
          OutfitSlot('Heels / Dress Shoes', Icons.hiking_rounded,
              secondary, 'Secondary Color', false),
        ];
      default:
        return [
          OutfitSlot('T-Shirt / Casual Top', Icons.dry_cleaning_rounded,
              primary, 'Primary — Hero Piece', true),
          OutfitSlot('Cardigan / Light Jacket', Icons.cloud_rounded,
              secondary, 'Secondary Color', false),
          OutfitSlot('Jeans / Casual Pants', Icons.straighten_rounded,
              darkHex, 'Dark Neutral', false),
          OutfitSlot('Sneakers / Casual Shoes', Icons.hiking_rounded,
              accent, 'Accent Color', false),
        ];
    }
  }

  static Color _safeColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  static String _tagline(String occasion) {
    switch (occasion) {
      case 'office':
        return '"Professional, polished, and effortlessly commanding."';
      case 'party':
        return '"Bold, vibrant, and made to be remembered."';
      default:
        return '"Relaxed, harmonious, and authentically you."';
    }
  }
}
