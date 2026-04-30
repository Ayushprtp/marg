import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final routingProvider = StateNotifierProvider<RoutingNotifier, List<LatLng>>((ref) {
  return RoutingNotifier();
});

class RoutingNotifier extends StateNotifier<List<LatLng>> {
  RoutingNotifier() : super([]);

  Future<void> fetchRoute(LatLng start, LatLng end) async {
    final apiKey = dotenv.env['FREE_ROUTE_API_KEY'];
    if (apiKey == null) return;

    // Remove the 'fro_' prefix if it's not part of the actual key for ORS
    final cleanKey = apiKey.startsWith('fro_') ? apiKey.substring(4) : apiKey;

    try {
      final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$cleanKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
        state = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      } else {
        print('Routing Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Routing Exception: $e');
    }
  }

  void clearRoute() {
    state = [];
  }
}
