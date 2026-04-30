import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/map_provider.dart';
import '../widgets/slot_grid_widget.dart';

class LotDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> lot;

  const LotDetailScreen({super.key, required this.lot});

  @override
  ConsumerState<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends ConsumerState<LotDetailScreen> {
  Map<String, dynamic>? selectedSlot;
  String selectedType = 'All';

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(slotsProvider(widget.lot['id']));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.lot['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: slotsAsync.when(
        data: (slots) {
          final filteredSlots = selectedType == 'All' 
              ? slots 
              : slots.where((s) => s['vehicle_type']?.toString().toLowerCase() == selectedType.toLowerCase()).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lot['address'],
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Select Vehicle Type",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', Icons.apps),
                          _buildFilterChip('Car', Icons.directions_car),
                          _buildFilterChip('Bike', Icons.motorcycle),
                          _buildFilterChip('EV', Icons.ev_station),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: SlotGridWidget(
                    slots: filteredSlots,
                    onSlotSelected: (slot) {
                      setState(() => selectedSlot = slot);
                    },
                  ),
                ),
              ),
              // Bottom Booking Bar
              _buildBookingBar(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFD1))),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => selectedType = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFD1) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedSlot != null ? "Slot ${selectedSlot!['slot_label']}" : "Choose a Slot",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (selectedSlot != null)
                    Text(
                      "₹${selectedSlot!['price_per_hour']}/hr",
                      style: const TextStyle(color: Color(0xFF00FFD1), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              if (selectedSlot != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFD1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "BEST PRICE",
                    style: TextStyle(color: Color(0xFF00FFD1), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: selectedSlot != null 
                ? () => context.push('/active-session')
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFD1),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white.withOpacity(0.1),
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(
              selectedSlot != null ? "Confirm Booking" : "Select a Slot to Continue",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

