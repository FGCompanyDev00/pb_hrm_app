import 'package:flutter/material.dart';

class WorkTrackingPage extends StatelessWidget {
  const WorkTrackingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work Tracking'),
      ),
      body: Center(
        child: Text('Work Tracking Page'),
      ),
    );
  }
}
