import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:intl/intl.dart';

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(hours: 1, minutes: 24));
    final duration = now.difference(startTime);
    const costPerHour = 40.0;
    final totalCost = (duration.inMinutes / 60.0) * costPerHour;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
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
                    Mjpeg(
                      isLive: true,
                      error: (context, error, stack) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text("Live Stream Offline", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      stream: 'http://127.0.0.1:8001/cameras/dummy/stream',
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
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Receipt Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEB3B), // Premium Yellow to match inspiration
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFEB3B).withOpacity(0.2),
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
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Vehicle", style: TextStyle(color: Colors.black54, fontSize: 12)),
                                Text("MP 04 AB 1234", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.directions_car, color: Color(0xFFFFEB3B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildReceiptRow("Location", "DB City Mall, Bhopal"),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildReceiptColumn("Slot", "A - 104"),
                            _buildReceiptColumn("Date", DateFormat('dd MMM, yyyy').format(now)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              _buildCostRow("In Time", DateFormat('hh:mm a').format(startTime)),
                              const SizedBox(height: 8),
                              _buildCostRow("Current Time", DateFormat('hh:mm a').format(now)),
                              const Divider(height: 24),
                              _buildCostRow("Duration", "${duration.inHours}h ${duration.inMinutes % 60}m", isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dotted separator simulation
                  Row(
                    children: List.generate(30, (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 1,
                        color: Colors.black26,
                      ),
                    )),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Amount", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                        Text("₹${totalCost.toStringAsFixed(2)}", style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900)),
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
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Make Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded),
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

  Widget _buildReceiptRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildReceiptColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildCostRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600)),
      ],
    );
  }
}

