import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/theme_provider.dart';

class OperatorHomeScreen extends ConsumerStatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  ConsumerState<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends ConsumerState<OperatorHomeScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() => isLoading = true);
    try {
      // Because of RLS, operators can only see roles that are 'client'.
      // If we query user_details, it will naturally filter out root/operator if the RLS on user_roles restricts it.
      // Let's filter explicitly just to be safe.
      final res = await supabase.from('user_details').select('*').eq('role', 'client').order('created_at');
      if (mounted) {
        setState(() {
          clients = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF799E83)))
          : clients.isEmpty 
              ? const Center(child: Text('No clients found', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final user = clients[index];
                    return Card(
                      color: Theme.of(context).colorScheme.surface,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF799E83),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(user['username'] ?? 'Unknown', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        subtitle: Text('Phone: ${user['phone_number'] ?? 'N/A'}\nDOB: ${user['dob'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
