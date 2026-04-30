import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_seeder.dart';

final mapProvider = StateNotifierProvider<MapNotifier, List<Map<String, dynamic>>>((ref) {
  return MapNotifier();
});

class MapNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  MapNotifier() : super([]) {
    fetchLots();
  }

  Future<void> fetchLots() async {
    final lotsResponse = await Supabase.instance.client
        .from('parking_lots')
        .select('*')
        .eq('is_active', true);
    
    if (lotsResponse.isEmpty) {
      await DataSeeder.seedBhopalData();
      return fetchLots(); // Recursive call after seeding
    }

    final List<Map<String, dynamic>> enrichedLots = [];
    
    for (var lot in lotsResponse) {
      final allSlots = await Supabase.instance.client
          .from('parking_slots')
          .select('id')
          .eq('lot_id', lot['id']);

      final availableSlots = await Supabase.instance.client
          .from('parking_slots')
          .select('id')
          .eq('lot_id', lot['id'])
          .eq('status', 'free');

      enrichedLots.add({
        ...lot,
        'total_slots': (allSlots as List).length,
        'available_slots': (availableSlots as List).length,
      });
    }
    
    state = enrichedLots;
  }
}

final slotsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, lotId) async {
  final response = await Supabase.instance.client
      .from('parking_slots')
      .select('*')
      .eq('lot_id', lotId);
  return List<Map<String, dynamic>>.from(response);
});
