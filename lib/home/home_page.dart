import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable back button
      
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/profile_picture.png'),
            ),
            const SizedBox(width: 10),
            Text(
              'John Doe',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage('assets/home_banner.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Action Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3 / 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard('My History', Icons.history),
                _buildActionCard('Approvals', Icons.check_circle),
                _buildActionCard('KPI', Icons.bar_chart),
                _buildActionCard('Work Tracking', Icons.track_changes),
                _buildActionCard('Inventory', Icons.inventory),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle card tap
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.green),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
