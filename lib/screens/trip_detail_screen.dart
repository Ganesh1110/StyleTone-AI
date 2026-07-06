import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/closet_item.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip _trip;
  List<ClosetItem> _allClosetItems = [];
  Map<String, List<ClosetItem>> _categorized = {};
  Set<String> _packedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _packedIds = _trip.packedItemIds.toSet();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await DatabaseHelper.instance.getAllClosetItems();

    final categorized = <String, List<ClosetItem>>{
      'top': [], 'bottom': [], 'outer': [], 'shoes': [], 'accessory': [],
    };
    for (final item in items) {
      if (categorized.containsKey(item.category)) {
        categorized[item.category]!.add(item);
      }
    }

    setState(() {
      _allClosetItems = items;
      _categorized = categorized;
      _isLoading = false;
    });
  }

  Future<void> _togglePacked(String itemId) async {
    setState(() {
      if (_packedIds.contains(itemId)) {
        _packedIds.remove(itemId);
      } else {
        _packedIds.add(itemId);
      }
    });

    final updatedTrip = _trip.copyWith(packedItemIds: _packedIds.toList());
    await DatabaseHelper.instance.updateTrip(updatedTrip);
    _trip = updatedTrip;
  }

  Future<void> _addAllSuggested() async {
    final allIds = _allClosetItems.map((i) => i.id).toSet();
    setState(() => _packedIds = allIds);
    final updatedTrip = _trip.copyWith(packedItemIds: allIds.toList());
    await DatabaseHelper.instance.updateTrip(updatedTrip);
    _trip = updatedTrip;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.destination, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_packedIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.checklist_rounded),
              tooltip: '${_packedIds.length} items packed',
              onPressed: null,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : Column(
              children: [
                _buildTripHeader(dateFormat),
                Expanded(child: _buildPackingList()),
              ],
            ),
    );
  }

  Widget _buildTripHeader(DateFormat dateFormat) {
    final packedCount = _packedIds.length;
    final totalCount = _allClosetItems.length;

    return GlassCard(
      color: Colors.white.withOpacity(0.05),
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.flight_rounded, color: Colors.deepPurple.shade300),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dateFormat.format(_trip.startDate)} - ${dateFormat.format(_trip.endDate)}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    if (_trip.activities.isNotEmpty)
                      Text(
                        _trip.activities.join(' · '),
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Packing Progress',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalCount > 0 ? packedCount / totalCount : 0,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Text(
                '$packedCount / $totalCount',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _addAllSuggested,
              icon: Icon(Icons.add_box_rounded, size: 18),
              label: Text('Pack All Items'),
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurple.shade200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingList() {
    if (_allClosetItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade500),
            SizedBox(height: 16),
            Text('Your closet is empty', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('Add garments in My Closet first', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final categoryLabels = {
      'top': 'Tops',
      'bottom': 'Bottoms',
      'outer': 'Outerwear',
      'shoes': 'Shoes',
      'accessory': 'Accessories',
    };

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: _categorized.entries.map((entry) {
        if (entry.value.isEmpty) return SizedBox.shrink();

          final packed = entry.value.where((i) => _packedIds.contains(i.id)).length;

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: GlassCard(
            color: Colors.white.withOpacity(0.05),
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      categoryLabels[entry.key] ?? entry.key,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      '$packed packed',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: entry.value.map((item) {
                      final isPacked = _packedIds.contains(item.id);
                      final itemColor = Color(int.parse(item.hexColor.replaceFirst('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => _togglePacked(item.id),
                        child: Container(
                          width: 72,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPacked ? Colors.green : Colors.white12,
                              width: isPacked ? 2 : 1,
                            ),
                            color: isPacked ? Colors.green.withOpacity(0.1) : null,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(File(item.imagePath), fit: BoxFit.cover),
                                      if (isPacked)
                                        Container(
                                          color: Colors.green.withOpacity(0.2),
                                          child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: itemColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      item.colorName,
                                      style: TextStyle(fontSize: 8, color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
