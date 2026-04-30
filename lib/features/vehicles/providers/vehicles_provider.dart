import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../../core/constants.dart';

final vehiclesProvider = AsyncNotifierProvider<VehiclesNotifier, List<Map<String, dynamic>>>(() {
  return VehiclesNotifier();
});

class VehiclesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchVehicles();
  }

  Future<List<Map<String, dynamic>>> _fetchVehicles() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final response = await Supabase.instance.client
        .from('vehicles')
        .select('*')
        .eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> verifyAndAddVehicle(String plate, String engineLast5, String chassisLast5) async {
    try {
      final dio = Dio();
      final response = await dio.get('${Constants.vehicleApiBase}/vehicle/$plate');
      final data = response.data;

      final apiEngine = data['engine'] as String;
      final apiChassis = data['chassis'] as String;

      final engineMatch = apiEngine.toUpperCase().endsWith(engineLast5.toUpperCase());
      final chassisMatch = apiChassis.toUpperCase().endsWith(chassisLast5.toUpperCase());

      if (!engineMatch || !chassisMatch) {
        return "Engine or Chassis number doesn't match our records.";
      }

      if (data['rcStatus'] != 'ACTIVE') {
        return "RC is not active. Status: ${data['rcStatus']}";
      }

      String vehicleType = 'car';
      final vc = data['vehicleClass']?.toString().toLowerCase() ?? '';
      if (vc.contains('motor cycle') || vc.contains('m-cycle')) vehicleType = 'bike';
      
      final user = Supabase.instance.client.auth.currentUser;
      final currentVehicles = state.value ?? [];
      
      await Supabase.instance.client.from('vehicles').insert({
        'user_id': user!.id,
        'plate_number': plate.toUpperCase(),
        'engine_number': engineLast5.toUpperCase(),
        'chassis_number': chassisLast5.toUpperCase(),
        'maker_model': data['makerModel'], // Keeping this for UI identification
        'vehicle_type': vehicleType,      // Keeping this for functional logic
        'verified': true,
        'is_default': currentVehicles.isEmpty,
      });

      ref.invalidateSelf();
      return "Success";
    } catch (e) {
      return "Verification failed: $e";
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await Supabase.instance.client
          .from('vehicles')
          .delete()
          .eq('id', vehicleId);
      ref.invalidateSelf();
    } catch (e) {
      print('Delete vehicle error: $e');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
