import 'package:flutter/material.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Approvals'),
      ),
      body: Center(
        child: Text('Approvals Page'),
      ),
    );
  }
}
