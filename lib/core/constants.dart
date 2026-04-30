import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get vehicleApiBase => dotenv.env['VEHICLE_API_BASE'] ?? 'https://abs-weblogs-gas-dude.trycloudflare.com';
  static String get cameraWorkerUrl => dotenv.env['CAMERA_WORKER_URL'] ?? 'https://surge-thermal-carmen-thrown.trycloudflare.com';
  static String get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';
}
