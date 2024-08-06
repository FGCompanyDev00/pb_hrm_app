import 'package:flutter/material.dart';

class KpiPage extends StatelessWidget {
  const KpiPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KPI'),
      ),
      body: Center(
        child: Text('KPI Page'),
      ),
    );
  }
}
