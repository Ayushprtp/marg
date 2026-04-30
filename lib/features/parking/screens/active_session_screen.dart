import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../../core/constants.dart';
import '../../vehicles/providers/vehicles_provider.dart';
import '../providers/bookings_provider.dart';

class ActiveSessionScreen extends ConsumerWidget {
  final Map<String, dynamic>? bookingData;
  const ActiveSessionScreen({super.key, this.bookingData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    
    final bool isSession = bookingData?['is_session'] == true;
    final bool isHistory = bookingData != null && bookingData!.containsKey('parking_lots') && !isSession;
    final bool isBookingOrSessionWithLots = bookingData != null && bookingData!.containsKey('parking_lots');
    final bool isPreBooking = bookingData != null && !isSession && !isHistory;
    
    // Determine start time based on if it's a parking session or a booking
    final startTime = isSession && bookingData!['entered_at'] != null
        ? DateTime.parse(bookingData!['entered_at']).toLocal()
        : (isHistory && bookingData!['created_at'] != null 
            ? DateTime.parse(bookingData!['created_at']).toLocal()
            : (bookingData != null && bookingData!['booked_for'] != null
                ? DateTime.parse(bookingData!['booked_for']).toLocal()
                : now));
    
    final duration = now.difference(startTime);
    
    final slotData = isBookingOrSessionWithLots ? bookingData!['parking_slots'] : (bookingData != null ? bookingData!['slot'] : null);
    final costPerHour = slotData != null ? (slotData['price_per_hour'] as num).toDouble() : 40.0;
    
    final selectedDuration = (!isHistory && !isSession && bookingData != null && bookingData!['duration'] != null) ? (bookingData!['duration'] as int) : 1;
        
    final totalCost = (!isHistory && !isSession)
        ? selectedDuration * costPerHour
        : (duration.inMinutes / 60.0) * costPerHour;

    final lotName = isBookingOrSessionWithLots
        ? (bookingData!['parking_lots']?['name'] ?? 'Unknown Lot')
        : (bookingData != null && bookingData!['lot'] != null ? bookingData!['lot']['name'] : 'Unknown Lot');
        
    final slotLabel = slotData != null 
        ? (slotData['slot_label'] ?? "${slotData['slot_row'] ?? ''}${slotData['slot_col'] ?? ''}") 
        : "N/A";

    final lotId = isBookingOrSessionWithLots 
        ? bookingData!['lot_id'] 
        : (bookingData != null && bookingData!['lot'] != null ? bookingData!['lot']['id'] : '');

    // Get vehicle plate for display — prefer the booking's linked vehicle, then session plate, then user's default
    final bookingPlate = bookingData?['vehicles']?['plate_number'];
    final sessionPlate = bookingData?['plate_detected'];
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final userDefaultPlate = vehiclesAsync.whenOrNull<String>(
      data: (vehicles) {
        // Prefer the default vehicle
        final defaultVehicle = vehicles.firstWhere(
          (v) => v['is_default'] == true, 
          orElse: () => vehicles.isNotEmpty ? vehicles.first : {},
        );
        return defaultVehicle['plate_number'] as String?;
      },
    );
    final vehiclePlate = bookingPlate ?? sessionPlate ?? userDefaultPlate ?? 'Unknown Vehicle';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Parking Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Live Feed Section
            Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    if (isPreBooking && !isHistory)
                      Container(
                        color: const Color(0xFF161B22),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text("Stream starts after parking", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                        if (lotId.isNotEmpty)
                          Mjpeg(
                            isLive: true,
                            error: (context, error, stack) => Container(
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
                            stream: '${Constants.cameraWorkerUrl}/stream/$lotId',
                          )
                        else
                          Container(
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
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Receipt Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Vehicle", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(vehiclePlate, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF799E83).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.directions_car, color: Color(0xFF799E83)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildReceiptRow("Location", lotName),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildReceiptColumn("Slot", slotLabel),
                            _buildReceiptColumn("Date", DateFormat('dd MMM, yyyy').format(now)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            children: [
                              _buildCostRow("In Time", DateFormat('hh:mm a').format(startTime)),
                              const SizedBox(height: 8),
                              if (isPreBooking)
                                _buildCostRow("Duration", "${selectedDuration}h", isBold: true)
                              else ...[
                                _buildCostRow("Current Time", DateFormat('hh:mm a').format(now)),
                                const Divider(height: 24, color: Colors.white12),
                                _buildCostRow("Duration", "${duration.inHours}h ${duration.inMinutes % 60}m", isBold: true),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dotted separator
                  Row(
                    children: List.generate(30, (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 1,
                        color: Colors.white10,
                      ),
                    )),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Amount", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        Text("₹${totalCost.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF799E83), fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Payment Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () => _handlePayment(context, ref, isPreBooking, totalCost, selectedDuration),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF799E83),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isPreBooking ? "Confirm & Pay" : "Make Payment", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment(BuildContext context, WidgetRef ref, bool isPreBooking, double totalCost, int durationHours) async {
    if (!isPreBooking) return;

    final vehicles = ref.read(vehiclesProvider).value ?? [];
    if (vehicles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add a vehicle first"), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF799E83))),
    );

    final success = await ref.read(bookingsProvider.notifier).createBooking(
      slotId: bookingData!['slot']['id'],
      lotId: bookingData!['lot']['id'],
      vehicleId: vehicles.first['id'],
      bookedFor: DateTime.now(),
      amount: totalCost,
      durationHours: durationHours,
    );

    if (context.mounted) Navigator.pop(context); // Dismiss loading

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking Confirmed! 🎉"),
            backgroundColor: Color(0xFF799E83),
          ),
        );
        context.go('/my-parks');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking Failed. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildReceiptRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildReceiptColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildCostRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600)),
      ],
    );
  }
}
