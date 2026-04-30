import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

class OperatorDashboard extends ConsumerWidget {
  const OperatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text("Add New Parking Lot"),
            leading: const Icon(Icons.add_location_alt),
            onTap: () => context.push('/operator/add-lot'),
          ),
          ListTile(
            title: const Text("Manage Lots & Slots"),
            leading: const Icon(Icons.grid_view),
            onTap: () => context.push('/operator/manage-slots'),
          ),
          ListTile(
            title: const Text("Add Camera"),
            leading: const Icon(Icons.camera_alt),
            onTap: () => context.push('/operator/add-camera'),
          ),
        ],
      ),
    );
  }
}
