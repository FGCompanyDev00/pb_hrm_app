import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class LeaveManagementPage extends HookWidget {
  const LeaveManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final typeController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final startDateController = useTextEditingController();
    final endDateController = useTextEditingController();
    final daysController = useTextEditingController(text: '0');
    final leaveTypeId = useState<int?>(null);

    // Function to show a dialog and clear input fields
    void showCustomDialog(BuildContext context, String title, String content) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  // Clear all input fields
                  typeController.clear();
                  descriptionController.clear();
                  startDateController.clear();
                  endDateController.clear();
                  daysController.clear();
                  leaveTypeId.value = null;

                  // Close the dialog
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    }

    // Fetch leave types from API
    Future<List<Map<String, dynamic>>> fetchLeaveTypes() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        EasyLoading.showError('User not authenticated');
        return [];
      }

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave-types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results']);
      } else {
        EasyLoading.showError('Failed to load leave types');
        return [];
      }
    }

    // Function to pick a date
    Future<void> pickDate(BuildContext context, TextEditingController controller) async {
      DateTime initialDate = DateTime.now();
      DateTime firstDate = DateTime(2000);
      DateTime lastDate = DateTime(2100);

      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );

      if (pickedDate != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        if (startDateController.text.isNotEmpty && endDateController.text.isNotEmpty) {
          final startDate = DateFormat('yyyy-MM-dd').parse(startDateController.text);
          final endDate = DateFormat('yyyy-MM-dd').parse(endDateController.text);
          final difference = endDate.difference(startDate).inDays + 1;
          daysController.text = difference.toString();
        }
      }
    }

    // Function to save leave data
    Future<void> saveData() async {
      if (typeController.text.isNotEmpty &&
          descriptionController.text.isNotEmpty &&
          startDateController.text.isNotEmpty &&
          endDateController.text.isNotEmpty &&
          daysController.text.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token == null) {
            EasyLoading.showError('User not authenticated');
            return;
          }

          final requestBody = {
            'take_leave_from': startDateController.text,
            'take_leave_to': endDateController.text,
            'take_leave_type_id': leaveTypeId.value.toString(),
            'take_leave_reason': descriptionController.text,
            'days': daysController.text,
          };

          final response = await http.post(
            Uri.parse('https://demo-application-api.flexiflows.co/api/leave_request'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            EasyLoading.showSuccess('Your leave request has been submitted!');
            showCustomDialog(context, 'Success', 'Your leave request has been submitted successfully.');
          } else {
            EasyLoading.showError('Failed to submit leave request');
            showCustomDialog(context, 'Error', 'Failed to submit leave request.');
          }
        } catch (e) {
          EasyLoading.showError('Error: $e');
          showCustomDialog(context, 'Error', 'An error occurred: $e');
        }
      } else {
        EasyLoading.showError('Please fill in all fields');
        showCustomDialog(context, 'Error', 'Please fill in all fields to submit your leave request.');
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Leave"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchLeaveTypes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No leave types found.');
                }

                final leaveTypes = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: AnimationLimiter(
                      child: Column(
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 500),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            horizontalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            TextButton.icon(
                              onPressed: saveData,
                              icon: const Icon(Icons.add),
                              label: const Text("Add"),
                              style: TextButton.styleFrom(
                                foregroundColor: isDarkMode ? Colors.white : Colors.black,
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: typeController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Type*',
                                labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                suffixIcon: PopupMenuButton<String>(
                                  icon: const Icon(Icons.list),
                                  onSelected: (String value) async {
                                    typeController.text = value;

                                    // Find the selected leave type's ID
                                    final selectedLeaveType = leaveTypes.firstWhere(
                                          (leaveType) => leaveType['name'] == value,
                                    );
                                    leaveTypeId.value = selectedLeaveType['leave_type_id'];
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return leaveTypes.map<PopupMenuItem<String>>((leaveType) {
                                      return PopupMenuItem<String>(
                                        value: leaveType['name'],
                                        child: Text(leaveType['name']),
                                      );
                                    }).toList();
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: startDateController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Start Date',
                                      labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    onTap: () => pickDate(context, startDateController),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: endDateController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'End Date',
                                      labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    onTap: () => pickDate(context, endDateController),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: daysController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Days*',
                                      labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
