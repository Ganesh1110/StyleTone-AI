import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';
import 'trip_detail_screen.dart';

class TripModeScreen extends StatefulWidget {
  const TripModeScreen({super.key});

  @override
  State<TripModeScreen> createState() => _TripModeScreenState();
}

class _TripModeScreenState extends State<TripModeScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final trips = await DatabaseHelper.instance.getAllTrips();
    setState(() {
      _trips = trips;
      _isLoading = false;
    });
  }

  void _createTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CreateTripSheet(onCreated: _loadTrips),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Packing', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _trips.isEmpty
              ? _buildEmptyState(theme)
              : _buildTripList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTrip,
        backgroundColor: Colors.deepPurple,
        icon: Icon(Icons.flight_takeoff_rounded, color: Colors.white),
        label: Text('New Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_rounded, size: 80, color: Colors.grey.shade500),
            SizedBox(height: 24),
            Text(
              'Smart Packing Lists',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Plan your trips. We will generate a colour-optimised packing\nlist from your virtual closet.',
              style: TextStyle(color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createTrip,
              icon: Icon(Icons.add_location_alt_rounded),
              label: Text('Plan a Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList() {
    final dateFormat = DateFormat('MMM d');

    return ListView(
      padding: EdgeInsets.all(16),
      children: _trips.map((trip) {
        final isPast = trip.endDate.isBefore(DateTime.now());
        final dateStr = '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}';

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: GlassCard(
            color: Colors.white.withOpacity(0.05),
            padding: EdgeInsets.all(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(trip: trip),
                  ),
                ).then((_) => _loadTrips());
              },
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPast ? Icons.check_circle_outline_rounded : Icons.flight_rounded,
                      color: isPast ? Colors.green : Colors.deepPurple,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.destination,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: Colors.white38),
                            SizedBox(width: 4),
                            Text(
                              '${trip.duration} day${trip.duration > 1 ? 's' : ''}',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            if (trip.activities.isNotEmpty) ...[
                              SizedBox(width: 12),
                              Icon(Icons.interests_rounded, size: 14, color: Colors.white38),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  trip.activities.join(', '),
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    trip.packedItemIds.length > 0
                        ? Icons.checklist_rounded
                        : Icons.chevron_right,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CreateTripSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateTripSheet({required this.onCreated});

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _destinationCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();
  DateTime _startDate = DateTime.now().add(Duration(days: 7));
  DateTime _endDate = DateTime.now().add(Duration(days: 10));

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(Duration(days: 3));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final trip = Trip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: _destinationCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      activities: _activitiesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );

    await DatabaseHelper.instance.insertTrip(trip);
    if (mounted) Navigator.pop(context);
    widget.onCreated();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _activitiesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Plan Your Trip',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _destinationCtrl,
              decoration: _inputDecoration('Destination', 'e.g. Paris, Beach, NYC'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context, true),
                    child: _dateField('Start Date', dateFormat.format(_startDate)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context, false),
                    child: _dateField('End Date', dateFormat.format(_endDate)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _activitiesCtrl,
              decoration: _inputDecoration('Activities', 'e.g. Beach, Museum, Hiking'),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text(
                  'Generate Packing List',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.white54),
      hintStyle: TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _dateField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white38),
              SizedBox(width: 8),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
