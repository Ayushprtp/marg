import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final bookingsProvider = StateNotifierProvider<BookingsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return BookingsNotifier();
});

/// Fetches completed/expired parking sessions (history)
final parkingHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('bookings')
      .select('*, parking_lots(name, address), parking_slots(slot_label, slot_row, slot_col, price_per_hour), payments(amount, status, method)')
      .eq('user_id', userId)
      .inFilter('status', ['cancelled', 'expired', 'arrived'])
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class BookingsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  BookingsNotifier() : super(const AsyncValue.loading()) {
    fetchBookings();
  }

  final _supabase = Supabase.instance.client;

  /// Fetch all active/current bookings for the user
  Future<void> fetchBookings() async {
    state = const AsyncValue.loading();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final response = await _supabase
          .from('bookings')
          .select('*, parking_lots(name, address), parking_slots(slot_label, slot_row, slot_col, price_per_hour)')
          .eq('user_id', userId)
          .inFilter('status', ['active', 'arrived'])
          .order('created_at', ascending: false);

      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Create a pre-booking: reserves a slot, creates booking & payment records
  Future<bool> createBooking({
    required String slotId,
    required String lotId,
    required String vehicleId,
    required DateTime bookedFor,
    required double amount,
    required int durationHours,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // 1. Create the booking record
      final bookingResponse = await _supabase.from('bookings').insert({
        'user_id': userId,
        'slot_id': slotId,
        'lot_id': lotId,
        'vehicle_id': vehicleId,
        'booked_for': bookedFor.toIso8601String(),
        'grace_until': bookedFor.add(const Duration(minutes: 15)).toIso8601String(),
        'status': 'active',
      }).select().single();

      final bookingId = bookingResponse['id'];

      // 2. Create the payment record (simulated as completed)
      // session_id is now nullable — for pre-bookings we link via booking_id
      await _supabase.from('payments').insert({
        'user_id': userId,
        'booking_id': bookingId,
        'amount': amount,
        'status': 'paid',
        'method': 'UPI',
      });

      // 3. Update slot status to 'reserved'
      await _supabase.from('parking_slots').update({
        'status': 'reserved',
      }).eq('id', slotId);

      await fetchBookings();
      return true;
    } catch (e) {
      print('Booking Error: $e');
      return false;
    }
  }

  /// Cancel an active booking and free the slot
  Future<bool> cancelBooking(String bookingId, String slotId) async {
    try {
      // Update booking status
      await _supabase.from('bookings').update({
        'status': 'cancelled',
      }).eq('id', bookingId);

      // Free the slot
      await _supabase.from('parking_slots').update({
        'status': 'free',
      }).eq('id', slotId);

      await fetchBookings();
      return true;
    } catch (e) {
      print('Cancel Error: $e');
      return false;
    }
  }

  /// Auto-cancel expired bookings (grace period exceeded)
  Future<void> cancelExpiredBookings() async {
    try {
      final now = DateTime.now().toIso8601String();

      final expired = await _supabase
          .from('bookings')
          .select('id, slot_id')
          .eq('status', 'active')
          .lt('grace_until', now);

      for (final booking in expired) {
        await _supabase.from('bookings').update({'status': 'expired'}).eq('id', booking['id']);
        await _supabase.from('parking_slots').update({'status': 'free'}).eq('id', booking['slot_id']);
      }

      if (expired.isNotEmpty) {
        await fetchBookings();
      }
    } catch (e) {
      print('Cleanup Error: $e');
    }
  }
}
