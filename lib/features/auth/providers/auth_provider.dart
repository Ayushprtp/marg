import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final String? role;
  final bool isLoading;

  AuthState({this.user, this.role, this.isLoading = true});

  AuthState copyWith({User? user, String? role, bool? isLoading}) {
    return AuthState(
      user: user ?? this.user,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _fetchRole(session.user);
    } else {
      state = state.copyWith(isLoading: false);
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        await _fetchRole(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = AuthState(isLoading: false);
      }
    });
  }

  Future<void> _fetchRole(User user) async {
    try {
      final response = await Supabase.instance.client
          .from('user_roles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      final role = response?['role'] ?? 'client';
      state = AuthState(user: user, role: role, isLoading: false);
    } catch (e) {
      state = AuthState(user: user, role: 'client', isLoading: false);
    }
  }

  Future<void> sendOtp(String phone) async {
    await Supabase.instance.client.auth.signInWithOtp(phone: phone);
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
