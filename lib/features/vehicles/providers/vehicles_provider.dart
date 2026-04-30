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

  Future<String> verifyAndAddVehicle(String plate, String engineLast6, String chassisLast6) async {
    try {
      final dio = Dio();
      final response = await dio.get('${Constants.vehicleApiBase}/vehicle/$plate');
      final data = response.data;

      final apiEngine = data['engine'] as String;
      final apiChassis = data['chassis'] as String;

      final engineMatch = apiEngine.toUpperCase().endsWith(engineLast6.toUpperCase());
      final chassisMatch = apiChassis.toUpperCase().endsWith(chassisLast6.toUpperCase());

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
        'engine_number': apiEngine,
        'chassis_number': apiChassis,
        'owner_name': data['owner'],
        'manufacturer': data['manufacturer'],
        'maker_model': data['makerModel'],
        'vehicle_class': data['vehicleClass'],
        'vehicle_type': vehicleType,
        'fuel_type': data['fuelType'],
        'color': data['vehicleColor'],
        'rc_status': data['rcStatus'],
        'insurance_upto': data['insuranceUpto'],
        'fitness_upto': data['fitnessUpto'],
        'raw_api_response': data,
        'verified': true,
        'is_default': currentVehicles.isEmpty,
      });

      ref.invalidateSelf();
      return "Success";
    } catch (e) {
      return "Verification failed: $e";
    }
  }
}
