import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../providers/map_provider.dart';
import '../providers/routing_provider.dart';
import '../../vehicles/providers/vehicles_provider.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  final MapController _mapController = MapController();

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    final newLocation = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _userLocation = newLocation;
    });

    _mapController.move(newLocation, 15);
  }
  @override
  Widget build(BuildContext context) {
    // Listen for vehicle load completion to show bottom sheet if empty
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(vehiclesProvider, (previous, next) {
      if (!next.isLoading && next.hasValue && next.value!.isEmpty) {
        _showNoVehicleBottomSheet();
      }
    });

    final lots = ref.watch(mapProvider);
    final routePoints = ref.watch(routingProvider);

    List<Marker> markers = lots.map((lot) {
      int totalSlots = lot['total_slots'] ?? 0;
      int availableSlots = lot['available_slots'] ?? totalSlots;
      bool isAvailable = availableSlots > 0;
      
      return Marker(
        point: LatLng(lot['latitude'], lot['longitude']),
        width: 80,
        height: 80,
        builder: (ctx) => GestureDetector(
          onTap: () {
            if (_userLocation != null) {
              ref.read(routingProvider.notifier).fetchRoute(
                _userLocation!,
                LatLng(lot['latitude'], lot['longitude']),
              );
            }
            context.push('/lot/${lot['id']}', extra: lot);
          },
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable ? const Color(0xFF00FFD1) : Colors.redAccent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isAvailable ? const Color(0xFF00FFD1) : Colors.redAccent).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.error,
                        color: isAvailable ? const Color(0xFF00FFD1) : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$availableSlots',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomPaint(
                  size: const Size(20, 10),
                  painter: TrianglePainter(
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.local_parking, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SmartPark Bhopal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(23.2599, 77.4126), // Default to Bhopal
              zoom: 13,
              maxZoom: 18,
              minZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartpark.maarg',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF00FFD1),
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      builder: (ctx) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF007AFF).withOpacity(0.2),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFF007AFF), width: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Search/Filter Bar Overlay
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search parking in Bhopal...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.tune, color: Color(0xFF00FFD1)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (routePoints.isNotEmpty)
            FloatingActionButton(
              heroTag: 'clear_route',
              onPressed: () => ref.read(routingProvider.notifier).clearRoute(),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.close, color: Colors.white),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'my_location',
            onPressed: _getCurrentLocation,
            backgroundColor: const Color(0xFF1E1E1E),
            child: const Icon(Icons.my_location, color: Color(0xFF00FFD1)),
          ),
        ],
      ),
    );
  }
  void _showNoVehicleBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car, size: 60, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              "Add a Vehicle",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            const Text(
              "You need to add at least one vehicle to use SmartPark parking features.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/add-vehicle');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text("Add Vehicle Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
