import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';

class LiveMonitorScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const LiveMonitorScreen({super.key, required this.booking});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _slots = [];
  String? _streamUrl;
  Timer? _pollTimer;
  bool _loading = true;

  String get lotId => widget.booking['lot_id'] ?? '';
  String get lotName => widget.booking['parking_lots']?['name'] ?? 'Parking Lot';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch parking sessions for this lot
      final sessions = await _supabase
          .from('parking_sessions')
          .select('*, vehicles(plate_number, maker_model), parking_slots(slot_label)')
          .eq('lot_id', lotId)
          .order('entered_at', ascending: false)
          .limit(20);

      // Fetch camera events for this lot
      final events = await _supabase
          .from('camera_events')
          .select()
          .eq('lot_id', lotId)
          .order('created_at', ascending: false)
          .limit(30);

      // Fetch slot statuses
      final slots = await _supabase
          .from('parking_slots')
          .select()
          .eq('lot_id', lotId)
          .order('slot_label');

      // Fetch camera stream url
      final camera = await _supabase
          .from('cameras')
          .select('stream_url')
          .eq('lot_id', lotId)
          .eq('is_active', true)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(sessions);
          _events = List<Map<String, dynamic>>.from(events);
          _slots = List<Map<String, dynamic>>.from(slots);
          if (camera != null) {
            _streamUrl = '${Constants.cameraWorkerUrl}/stream/$lotId';
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LiveMonitor fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 60,
            pinned: true,
            backgroundColor: const Color(0xFF0F1117),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(lotName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 6),
                    Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),

          // Live Feed Section
          SliverToBoxAdapter(
            child: Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (_streamUrl != null)
                      Mjpeg(
                        isLive: true,
                        error: (ctx, err, stack) => Container(
                          color: const Color(0xFF161B22),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text("Stream Unavailable", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        stream: _streamUrl!,
                      )
                    else
                      Container(
                        color: const Color(0xFF161B22),
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF799E83)),
                        ),
                      ),
                    // LIVE badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Lot name
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(lotName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Slot Status Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Parking Slots", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSlotGrid(),
                ],
              ),
            ),
          ),

          // Active Sessions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Vehicle Sessions (${_sessions.length})",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_loading)
            const SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF799E83)))),
            )
          else if (_sessions.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.directions_car_outlined, color: Colors.white24, size: 40),
                      SizedBox(height: 8),
                      Text("No sessions detected yet", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSessionCard(_sessions[index]),
                childCount: _sessions.length,
              ),
            ),

          // Detection Events Log
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                "Detection Log (${_events.length})",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_events.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No detection events yet", style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEventItem(_events[index]),
                childCount: _events.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    if (_slots.isEmpty) {
      return const Center(child: Text("Loading slots...", style: TextStyle(color: Colors.grey)));
    }
    return Row(
      children: _slots.map((slot) {
        final status = slot['status'] ?? 'free';
        final label = slot['slot_label'] ?? '?';
        Color bg;
        Color border;
        IconData icon;
        switch (status) {
          case 'occupied':
            bg = Colors.redAccent.withOpacity(0.15);
            border = Colors.redAccent.withOpacity(0.5);
            icon = Icons.directions_car;
            break;
          case 'reserved':
            bg = Colors.amber.withOpacity(0.15);
            border = Colors.amber.withOpacity(0.5);
            icon = Icons.bookmark;
            break;
          default:
            bg = const Color(0xFF799E83).withOpacity(0.1);
            border = const Color(0xFF799E83).withOpacity(0.3);
            icon = Icons.check_circle_outline;
        }
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Icon(icon, color: border, size: 24),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(status.toUpperCase(), style: TextStyle(color: border, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final plate = session['plate_detected'] ?? session['vehicles']?['plate_number'] ?? 'Unknown';
    final model = session['vehicles']?['maker_model'] ?? '';
    final slotLabel = session['parking_slots']?['slot_label'] ?? '';
    final enteredAt = session['entered_at'] != null
        ? DateFormat('dd MMM, hh:mm:ss a').format(DateTime.parse(session['entered_at']).toLocal())
        : 'N/A';
    final exitedAt = session['exited_at'] != null
        ? DateFormat('dd MMM, hh:mm:ss a').format(DateTime.parse(session['exited_at']).toLocal())
        : null;
    final duration = session['duration_minutes'];
    final amount = session['amount_due'];
    final isActive = session['exited_at'] == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF799E83).withOpacity(0.4) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF799E83).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.directions_car : Icons.directions_car_outlined,
                  color: isActive ? const Color(0xFF799E83) : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plate, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    if (model.isNotEmpty)
                      Text(model, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF799E83).withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? "PARKED" : "COMPLETED",
                  style: TextStyle(
                    color: isActive ? const Color(0xFF799E83) : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _infoRow(Icons.login, "Entered", enteredAt),
                if (exitedAt != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.logout, "Exited", exitedAt),
                ],
                if (slotLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.grid_view, "Slot", slotLabel),
                ],
                if (duration != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.timer, "Duration", "${duration}m"),
                ],
                if (amount != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.currency_rupee, "Amount Due", "₹${(amount as num).toStringAsFixed(0)}"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final type = event['event_type'] ?? '';
    final plate = event['plate_text'] ?? '';
    final slot = event['slot_label'] ?? '';
    final time = event['created_at'] != null
        ? DateFormat('hh:mm:ss a').format(DateTime.parse(event['created_at']).toLocal())
        : '';
    final isParked = type == 'vehicle_parked';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isParked ? Icons.arrow_downward : Icons.arrow_upward,
            color: isParked ? Colors.redAccent : const Color(0xFF799E83),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${isParked ? '🚗 Parked' : '🚀 Departed'} — $plate @ $slot",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
