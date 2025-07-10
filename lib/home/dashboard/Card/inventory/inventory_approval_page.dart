// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'inventory_app_bar.dart';

class InventoryApprovalPage extends StatefulWidget {
  const InventoryApprovalPage({super.key});

  @override
  State<InventoryApprovalPage> createState() => _InventoryApprovalPageState();
}

class _InventoryApprovalPageState extends State<InventoryApprovalPage> {
  final List<Map<String, dynamic>> _dummyApprovals = [
    {
      'title': 'Your Asset',
      'type': 'For Office',
      'date': '01-05-2024',
      'time': '14:00',
      'status': 'Pending',
      'avatarUrl': 'https://example.com/avatar1.jpg',
    },
    {
      'title': 'Your Asset',
      'type': 'For Office',
      'date': '01-05-2024',
      'time': '12:40',
      'status': 'Pending',
      'avatarUrl': 'https://example.com/avatar2.jpg',
    },
    {
      'title': 'Your Asset',
      'type': 'For Office',
      'date': '01-05-2024',
      'time': '12:00',
      'status': 'Pending',
      'avatarUrl': 'https://example.com/avatar3.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: const InventoryAppBar(
            title: 'Approval',
            showBack: true,
          ),
          body: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabButton('My Request', true, isDarkMode),
                    const SizedBox(width: 16),
                    _buildTabButton('Approval', false, isDarkMode),
                  ],
                ),
              ),
              Expanded(
                child: _buildApprovalsList(isDarkMode),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String text, bool isSelected, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFDBB342) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : isDarkMode
                  ? Colors.white70
                  : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildApprovalsList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dummyApprovals.length,
      itemBuilder: (context, index) {
        final approval = _dummyApprovals[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDBB342).withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        image: approval['avatarUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(approval['avatarUrl']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: approval['avatarUrl'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            approval['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            approval['type'],
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBB342).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        approval['status'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDBB342),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${approval['date']} ${approval['time']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
