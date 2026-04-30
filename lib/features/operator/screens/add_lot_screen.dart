import 'package:flutter/material.dart';

class AddLotScreen extends StatelessWidget {
  const AddLotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Parking Lot')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Lot Name')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Description')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Address')),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Next: Configure Slots'),
            )
          ],
        ),
      ),
    );
  }
}
