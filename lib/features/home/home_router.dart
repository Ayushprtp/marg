import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_home_screen.dart';
import 'operator_home_screen.dart';
import 'root_home_screen.dart';

class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  String? role;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Not logged in");
      }

      final res = await supabase
          .from('user_roles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          role = res?['role'] as String? ?? 'client';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching role: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF799E83))),
      );
    }

    if (role == 'root') {
      return const RootHomeScreen();
    } else if (role == 'operator') {
      return const OperatorHomeScreen();
    } else {
      return const ClientHomeScreen();
    }
  }
}
