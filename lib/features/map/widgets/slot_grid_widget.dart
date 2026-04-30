import 'package:flutter/material.dart';

class SlotGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final Function(Map<String, dynamic>) onSlotSelected;

  const SlotGridWidget({
    super.key,
    required this.slots,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text("No slots available in this lot.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group slots by row
    final Map<String, List<Map<String, dynamic>>> rows = {};
    for (final slot in slots) {
      final row = slot['slot_row'] as String? ?? 'A';
      if (!rows.containsKey(row)) {
        rows[row] = [];
      }
      rows[row]!.add(slot);
    }

    final sortedRowKeys = rows.keys.toList()..sort();

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Available", const Color(0xFF799E83)),
              const SizedBox(width: 20),
              _buildLegendItem("Occupied", Colors.redAccent),
              const SizedBox(width: 20),
              _buildLegendItem("Selected", Colors.white),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: sortedRowKeys.length,
            itemBuilder: (context, index) {
              final rowKey = sortedRowKeys[index];
              final rowSlots = rows[rowKey]!;
              rowSlots.sort((a, b) => (a['slot_col'] as int? ?? 0).compareTo(b['slot_col'] as int? ?? 0));

              return Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          rowKey,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Wrap(
                        spacing: 16.0,
                        runSpacing: 16.0,
                        children: rowSlots.map((slot) => _buildSlotItem(context, slot)).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildSlotItem(BuildContext context, Map<String, dynamic> slot) {
    final status = slot['status'] as String? ?? 'free';
    final isFree = status == 'free';
    
    Color color;
    switch (status) {
      case 'occupied':
        color = Colors.redAccent;
        break;
      case 'free':
      default:
        color = const Color(0xFF799E83);
        break;
    }

    return GestureDetector(
      onTap: isFree ? () => onSlotSelected(slot) : null,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isFree ? color.withOpacity(0.1) : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFree ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: isFree ? [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              "${slot['slot_row']}${slot['slot_col']}",
              style: TextStyle(
                color: isFree ? Colors.white : Colors.white.withOpacity(0.2),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            if (!isFree)
              const Positioned(
                bottom: 8,
                child: Icon(Icons.lock, size: 12, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }
}

