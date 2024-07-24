import 'package:flutter/material.dart';

class AddEventPage extends StatelessWidget {
  const AddEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event Page'),
      ),
      body: const Center(
        child: Text('Event Here'),
      ),
    );
  }
}
