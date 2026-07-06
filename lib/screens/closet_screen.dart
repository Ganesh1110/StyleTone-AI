import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/closet_item.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/skeleton_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'closet_synergy_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'key': 'top', 'label': 'Tops'},
    {'key': 'bottom', 'label': 'Bottoms'},
    {'key': 'outer', 'label': 'Outerwear'},
    {'key': 'shoes', 'label': 'Shoes'},
    {'key': 'accessory', 'label': 'Accessories'},
  ];

  Map<String, List<ClosetItem>> _closetData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadClosetItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClosetItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allItems = await DatabaseHelper.instance.getAllClosetItems();
      final Map<String, List<ClosetItem>> classified = {
        'top': [],
        'bottom': [],
        'outer': [],
        'shoes': [],
        'accessory': [],
      };

      for (var item in allItems) {
        if (classified.containsKey(item.category)) {
          classified[item.category]!.add(item);
        }
      }

      setState(() {
        _closetData = classified;
      });
    } catch (e) {
      debugPrint('Error loading closet: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addGarment() async {
    // Show photo picker bottom sheet
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.deepPurple,
              ),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Colors.deepPurple,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final File imageFile = File(pickedFile.path);

    // Compress and save locally to persistent app directories
    final appDir = await getApplicationDocumentsDirectory();
    final String uniqueFileName = 'closet_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String localSavedPath = p.join(appDir.path, uniqueFileName);
    
    // Scale down to a max width/height of 800px and compress to JPEG format in background thread
    final File savedFile = await ApiService.compressAndSaveImage(imageFile, localSavedPath, 800);

    if (!mounted) return;

    // Show analysis progress loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: GlassCard(
          padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonCard(height: 60, width: 60),
              SizedBox(height: 16),
              Text(
                'Analyzing clothing color...',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final analysis = await _apiService.analyzeClothingColor(
        imageFile: savedFile,
      );

      // Close analysis loader dialog
      if (mounted) Navigator.pop(context);

      final String hexColor = analysis['hex_color'] ?? '#FFFFFF';
      final String colorName = analysis['color_name'] ?? 'Unknown Color';

      // Show dialog to choose category and verify color classification
      if (mounted) {
        final added = await _showSaveGarmentDialog(savedFile, localSavedPath, hexColor, colorName);
        if (added != true) {
          try {
            final f = File(localSavedPath);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (e) {
            debugPrint('Failed to delete cancelled closet file: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loader
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Color analysis failed: $e')));
      }
    }
  }

  Future<bool?> _showSaveGarmentDialog(
    File file,
    String localPath,
    String hexColor,
    String colorName,
  ) {
    String selectedCategory = 'top';
    String cleanHex = hexColor.replaceFirst('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    final parsedColor = Color(int.parse(cleanHex, radix: 16));

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save New Garment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          file,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detected Color:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: parsedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        colorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        hexColor.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Category:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    children: _categories.map((cat) {
                      final isSelected = selectedCategory == cat['key'];
                      return ChoiceChip(
                        label: Text(cat['label']!),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (bool selected) {
                          if (selected) {
                            setModalState(() {
                              selectedCategory = cat['key']!;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newItem = ClosetItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          category: selectedCategory,
                          imagePath: localPath,
                          hexColor: hexColor,
                          colorName: colorName,
                        );

                        await DatabaseHelper.instance.insertClosetItem(newItem);
                        if (!context.mounted) return;
                         Navigator.pop(
                          context,
                          true,
                        ); // Close save dialog bottom sheet
                        _loadClosetItems(); // Refresh items list

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Successfully added $colorName garment to closet!',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Add to Closet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGarment(ClosetItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Garment'),
        content: const Text(
          'Are you sure you want to remove this garment from your closet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteClosetItem(item.id);

      // Delete local file to save storage
      final file = File(item.imagePath);
      if (await file.exists()) {
        await file.delete();
      }

      _loadClosetItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Closet'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Tooltip(
            message: 'Smart Shop — Check a New Item',
            child: IconButton(
              icon: const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClosetSynergyScreen(),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal),
          tabs: _categories.map((cat) => Tab(text: cat['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => const SkeletonGridItem(),
            )
          : TabBarView(
              controller: _tabController,
              children: _categories.map((cat) {
                final list = _closetData[cat['key']] ?? [];
                return _buildCategoryGrid(list, cat['label']!);
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGarment,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Garment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<ClosetItem> items, String categoryLabel) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items in $categoryLabel yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Garment" to build your closet.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final file = File(item.imagePath);
        final color = Color(int.parse(item.hexColor.replaceFirst('#', '0xFF')));

        return GlassCard(
          color: Colors.white.withOpacity(0.05),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _deleteGarment(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.colorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.hexColor.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
      },
    );
  }
}
