import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard.dart';
import 'package:pb_hrsystem/nav/custom_buttom_nav_bar.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Dashboard()),
            );
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileInfoRow(icon: Icons.person, label: 'Gender', value: 'Male'),
            ProfileInfoRow(icon: Icons.badge, label: 'Name & Surname', value: 'John Doe'),
            ProfileInfoRow(icon: Icons.location_city, label: 'Place of Birth', value: 'vientiane'),
            ProfileInfoRow(icon: Icons.date_range, label: 'Date Start Work', value: 'Nov 3, 2014'),
            ProfileInfoRow(icon: Icons.date_range, label: 'Passes Probation Date', value: 'Jan 3, 2015'),
            ProfileInfoRow(icon: Icons.account_balance, label: 'Department', value: 'Administration and General Services Department'),
            ProfileInfoRow(icon: Icons.location_on, label: 'Branch', value: 'Xaythany'),
            ProfileInfoRow(icon: Icons.phone, label: 'Tel.', value: '020 22345555'),
            ProfileInfoRow(icon: Icons.email, label: 'Emails', value: 'admin@psvsystem.com'),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.yellow),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
