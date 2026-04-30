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
    final response = await Supabase.instance.client
        .from('parking_lots')
        .select('*')
        .eq('is_active', true);
    
    if (response.isEmpty) {
      await DataSeeder.seedBhopalData();
      final retryResponse = await Supabase.instance.client
          .from('parking_lots')
          .select('*')
          .eq('is_active', true);
      state = List<Map<String, dynamic>>.from(retryResponse);
    } else {
      state = List<Map<String, dynamic>>.from(response);
    }
  }
}

final slotsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, lotId) async {
  final response = await Supabase.instance.client
      .from('parking_slots')
      .select('*')
      .eq('lot_id', lotId);
  return List<Map<String, dynamic>>.from(response);
});
