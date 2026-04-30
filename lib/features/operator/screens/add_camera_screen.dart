import 'package:flutter/material.dart';

class AddCameraScreen extends StatelessWidget {
  const AddCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Camera')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Camera Label (e.g. CAM_A)')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Stream URL (e.g. 0 for OBS)')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Camera Type'),
              items: ['slot_cam', 'entry_cam', 'exit_cam'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {},
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Save Camera'),
            )
          ],
        ),
      ),
    );
  }
}
