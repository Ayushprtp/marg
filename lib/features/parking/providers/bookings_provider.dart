import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final bookingsProvider =
    StateNotifierProvider<
      BookingsNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) {
      return BookingsNotifier();
    });

/// Fetches completed/expired parking sessions (history)
final parkingHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('bookings')
      .select(
        '*, parking_lots(name, address), parking_slots(slot_label, slot_row, slot_col, price_per_hour), payments(amount, status, method), vehicles(plate_number)',
      )
      .eq('user_id', userId)
      .inFilter('status', ['cancelled', 'expired', 'completed'])
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class BookingsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  RealtimeChannel? _subscription;

  BookingsNotifier() : super(const AsyncValue.loading()) {
    fetchBookings();
    _setupRealtime();
  }

  final _supabase = Supabase.instance.client;

  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = _supabase
        .channel('public:bookings_and_sessions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            fetchBookings();
            // Also invalidate history when things complete
            // Not directly available here but we can assume fetchBookings does the active ones
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parking_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            fetchBookings();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  /// Fetch all active/current bookings and sessions for the user
  Future<void> fetchBookings() async {
    state = const AsyncValue.loading();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final bookingsRes = await _supabase
          .from('bookings')
          .select(
            '*, parking_lots(name, address), parking_slots(slot_label, slot_row, slot_col, price_per_hour), vehicles(plate_number)',
          )
          .eq('user_id', userId)
          .inFilter('status', ['active', 'arrived'])
          .order('created_at', ascending: false);

      final sessionsRes = await _supabase
          .from('parking_sessions')
          .select(
            '*, parking_lots(name, address), parking_slots(slot_label, slot_row, slot_col, price_per_hour)',
          )
          .eq('user_id', userId)
          .isFilter('exited_at', null)
          .order('entered_at', ascending: false);

      final List<Map<String, dynamic>> combined = [];
      
      for (var b in bookingsRes) {
        combined.add({...b, 'is_session': false});
      }

      for (var s in sessionsRes) {
        // Only add sessions if there is NO corresponding arrived booking
        final hasBooking = combined.any((b) => b['slot_id'] == s['slot_id'] && b['status'] == 'arrived');
        if (!hasBooking) {
          combined.add({
            ...s,
            'status': 'parked',
            'booked_for': s['entered_at'],
            'is_session': true,
          });
        }
      }

      combined.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] ?? a['entered_at'] ?? DateTime.now().toIso8601String());
        final dateB = DateTime.parse(b['created_at'] ?? b['entered_at'] ?? DateTime.now().toIso8601String());
        return dateB.compareTo(dateA);
      });

      state = AsyncValue.data(combined);
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
      final bookingResponse = await _supabase
          .from('bookings')
          .insert({
            'user_id': userId,
            'slot_id': slotId,
            'lot_id': lotId,
            'vehicle_id': vehicleId,
            'booked_for': bookedFor.toIso8601String(),
            'grace_until': bookedFor
                .add(const Duration(minutes: 15))
                .toIso8601String(),
            'status': 'active',
          })
          .select()
          .single();

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
      await _supabase
          .from('parking_slots')
          .update({'status': 'reserved'})
          .eq('id', slotId);

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
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);

      // Free the slot
      await _supabase
          .from('parking_slots')
          .update({'status': 'free'})
          .eq('id', slotId);

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
        await _supabase
            .from('bookings')
            .update({'status': 'expired'})
            .eq('id', booking['id']);
        await _supabase
            .from('parking_slots')
            .update({'status': 'free'})
            .eq('id', booking['slot_id']);
      }

      if (expired.isNotEmpty) {
        await fetchBookings();
      }
    } catch (e) {
      print('Cleanup Error: $e');
    }
  }
}
