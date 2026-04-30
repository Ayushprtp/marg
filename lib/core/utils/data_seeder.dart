import 'package:supabase_flutter/supabase_flutter.dart';

class DataSeeder {
  static Future<void> seedBhopalData() async {
    final supabase = Supabase.instance.client;

    // 1. Get or Create an operator profile (for testing, we use the current user if they are operator/root, or a dummy)
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Check if lots already exist
    final existingLots = await supabase.from('parking_lots').select('id').limit(1);
    if (existingLots.isNotEmpty) {
      print("Data already seeded.");
      return;
    }

    print("Seeding Bhopal Parking Data...");

    final lots = [
      {
        'operator_id': user.id,
        'name': 'DB City Mall Parking',
        'address': 'Arera Hills, Bhopal, Madhya Pradesh 462011',
        'latitude': 23.2324,
        'longitude': 77.4245,
        'total_slots': 50,
        'amenities': ['covered', '24x7', 'cctv', 'ev_charging'],
      },
      {
        'operator_id': user.id,
        'name': 'MP Nagar Multi-Level',
        'address': 'Zone-I, Maharana Pratap Nagar, Bhopal',
        'latitude': 23.2355,
        'longitude': 77.4332,
        'total_slots': 120,
        'amenities': ['covered', 'cctv'],
      },
      {
        'operator_id': user.id,
        'name': 'Boat Club Road Parking',
        'address': 'Shyamla Hills, Bhopal',
        'latitude': 23.2494,
        'longitude': 77.3912,
        'total_slots': 30,
        'amenities': ['open', 'lake_view'],
      }
    ];

    for (var lotData in lots) {
      final lotResponse = await supabase.from('parking_lots').insert(lotData).select().single();
      final lotId = lotResponse['id'];

      // Seed Slots for each lot
      List<Map<String, dynamic>> slots = [];
      for (int i = 1; i <= 10; i++) {
        slots.add({
          'lot_id': lotId,
          'slot_label': 'A$i',
          'slot_row': 'A',
          'slot_col': i,
          'vehicle_type': i % 3 == 0 ? 'bike' : 'car',
          'status': i % 4 == 0 ? 'occupied' : 'free',
          'price_per_hour': 40.0,
        });
      }
      await supabase.from('parking_slots').insert(slots);
    }

    print("Seeding complete!");
  }
}
