import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/theme_provider.dart';

class RootHomeScreen extends ConsumerStatefulWidget {
  const RootHomeScreen({super.key});

  @override
  ConsumerState<RootHomeScreen> createState() => _RootHomeScreenState();
}

class _RootHomeScreenState extends ConsumerState<RootHomeScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      // Query the user_details view we created
      final res = await supabase.from('user_details').select('*').order('created_at');
      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(res);
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

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await supabase.from('user_roles').update({'role': newRole}).eq('id', userId);
      _fetchUsers(); // refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Root Dashboard'),
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
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(user['username'] ?? 'Unknown', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    subtitle: Text('Role: ${user['role']} | Phone: ${user['phone_number'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                    trailing: DropdownButton<String>(
                      value: user['role'],
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: const TextStyle(color: Color(0xFF799E83)),
                      underline: const SizedBox(),
                      items: ['client', 'operator', 'root'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null && newValue != user['role']) {
                          _updateRole(user['id'], newValue);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
