import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../vehicles/providers/vehicles_provider.dart';
import '../../parking/providers/bookings_provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../../core/constants.dart';
import '../../../main.dart';

class MyParksScreen extends ConsumerWidget {
  const MyParksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final bookingsAsync = ref.watch(bookingsProvider);
    final historyAsync = ref.watch(parkingHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: const Color(0xFF799E83),
        onRefresh: () async {
          ref.invalidate(bookingsProvider);
          ref.invalidate(parkingHistoryProvider);
          ref.invalidate(vehiclesProvider);
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, ref),
            _buildBookingsHeader(context, ref),
            _buildBookingsList(bookingsAsync, context, ref),
            _buildVehiclesHeader(context),
            _buildVehiclesList(vehiclesAsync, context, ref),
            _buildHistoryHeader(ref),
            _buildHistoryList(historyAsync, context),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        centerTitle: false,
        title: const Text(
          "My Parks",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF799E83).withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOOKINGS SECTION ────────────────────────────────────────────────

  Widget _buildBookingsHeader(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Current Activity",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              onPressed: () {
                ref.invalidate(bookingsProvider);
                ref.read(bookingsProvider.notifier).cancelExpiredBookings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(
    AsyncValue<List<Map<String, dynamic>>> bookingsAsync,
    BuildContext context,
    WidgetRef ref,
  ) {
    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      color: Colors.white24,
                      size: 40,
                    ),
                    SizedBox(height: 8),
                    const Text(
                      "No active activity",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final booking = bookings[index];
            return _buildBookingItem(booking, context, ref);
          }, childCount: bookings.length),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Color(0xFF799E83)),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingItem(
    Map<String, dynamic> booking,
    BuildContext context,
    WidgetRef ref,
  ) {
    final status = booking['status'] ?? '';
    final lotName = booking['parking_lots']?['name'] ?? 'Unknown Lot';
    final slotData = booking['parking_slots'];
    final isSession = booking['is_session'] == true;
    final plateNumber = isSession 
        ? (booking['plate_detected'] ?? 'Detected Vehicle')
        : (booking['vehicles']?['plate_number'] ?? 'Reserved');
    
    final lotId = booking['lot_id'];
    final slotLabel = slotData?['slot_label'] ?? 'N/A';
    
    final bookedFor = booking['booked_for'] != null
        ? DateFormat(
            'dd MMM, hh:mm a',
          ).format(DateTime.parse(booking['booked_for']).toLocal())
        : 'N/A';

    return GestureDetector(
      onTap: () {
        if (status == 'active') {
          context.push('/live-monitor', extra: booking);
        } else {
          context.push('/active-session', extra: booking);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status == 'active'
                ? const Color(0xFF799E83).withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF799E83).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status == 'active'
                        ? Icons.bookmark_added
                        : Icons.bookmark_border,
                    color: const Color(0xFF799E83),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      lotName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Plate: $plateNumber",
                      style: const TextStyle(
                        color: Color(0xFF799E83),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Slot $slotLabel • $bookedFor",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == 'parked' || status == 'arrived')
                Container(
                  width: 60,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Mjpeg(
                          isLive: true,
                          stream: '${Constants.cameraWorkerUrl}/proxy/$lotId',
                          error: (context, error, stack) => Container(color: Colors.black),
                        ),
                        const Positioned(
                          top: 2,
                          left: 2,
                          child: Text("LIVE", style: TextStyle(color: Colors.redAccent, fontSize: 6, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF799E83).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF799E83),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
            if (status == 'active') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(
                    context,
                    ref,
                    booking['id'],
                    booking['slot_id'],
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text("Cancel Booking"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    String bookingId,
    String slotId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Cancel Booking",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure? A concession fee may apply. The parking slot will be freed.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Keep Booking",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(bookingsProvider.notifier)
                  .cancelBooking(bookingId, slotId);
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    success ? "Booking cancelled." : "Failed to cancel.",
                  ),
                  backgroundColor: success
                      ? const Color(0xFF799E83)
                      : Colors.redAccent,
                ),
              );
              ref.invalidate(parkingHistoryProvider);
            },
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── VEHICLES SECTION ────────────────────────────────────────────────

  Widget _buildVehiclesHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "My Vehicles",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/add-vehicle'),
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF799E83),
                size: 20,
              ),
              label: const Text(
                "Add New",
                style: TextStyle(
                  color: Color(0xFF799E83),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesList(
    AsyncValue<List<Map<String, dynamic>>> vehiclesAsync,
    BuildContext context,
    WidgetRef ref,
  ) {
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    color: Colors.white24,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No vehicles added yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/add-vehicle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF799E83),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Add Vehicle"),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return _buildVehicleCard(vehicle, context, ref);
              },
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Color(0xFF799E83)),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(
    Map<String, dynamic> vehicle,
    BuildContext context,
    WidgetRef ref,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF161B22),
            const Color(0xFF161B22).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF799E83).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vehicle['vehicle_type']?.toUpperCase() ?? 'CAR',
                  style: const TextStyle(
                    color: Color(0xFF799E83),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Delete button
              GestureDetector(
                onTap: () => _showDeleteVehicleDialog(context, ref, vehicle),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            vehicle['plate_number'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicle['maker_model'] ?? "Private Vehicle",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vehicle['verified'] == true)
                const Icon(Icons.verified, color: Color(0xFF799E83), size: 16),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteVehicleDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> vehicle,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Remove Vehicle",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Remove ${vehicle['plate_number']} from your account?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Keep", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(vehiclesProvider.notifier)
                  .deleteVehicle(vehicle['id']);
              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text("Vehicle removed."),
                  backgroundColor: Color(0xFF799E83),
                ),
              );
            },
            child: const Text(
              "Remove",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HISTORY SECTION ─────────────────────────────────────────────────

  Widget _buildHistoryHeader(WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Parking History",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              onPressed: () => ref.invalidate(parkingHistoryProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    AsyncValue<List<Map<String, dynamic>>> historyAsync,
    BuildContext context,
  ) {
    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.history, color: Colors.white24, size: 40),
                    SizedBox(height: 8),
                    Text(
                      "No parking history yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = history[index];
            return _buildHistoryItem(context, item);
          }, childCount: history.length),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Color(0xFF799E83)),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final lotName = item['parking_lots']?['name'] ?? 'Unknown';
    final status = item['status'] ?? '';
    final createdAt = item['created_at'] != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format(DateTime.parse(item['created_at']).toLocal())
        : '';

    // Calculate cost from payment or slot data
    final payments = item['payments'] as List<dynamic>?;
    final amount = payments != null && payments.isNotEmpty
        ? payments.first['amount']
        : null;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF799E83);
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusIcon = Icons.cancel;
        break;
      case 'expired':
        statusColor = Colors.redAccent;
        statusIcon = Icons.timer_off;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.history;
    }

    return GestureDetector(
      onTap: () => context.push('/active-session', extra: item),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lotName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$createdAt • ${status.toUpperCase()}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (amount != null)
            Text(
              "₹${(amount as num).toStringAsFixed(0)}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
        ],
      ),
    ),
    );
  }
}
