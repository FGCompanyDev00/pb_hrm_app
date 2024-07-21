import 'package:flutter/material.dart';

class ManagementPage1 extends StatelessWidget {
  const ManagementPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management Pages'),
      ),
      body: const Center(
        child: Text('All Management Pages here'),
      ),
    );
  }
}
