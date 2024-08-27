import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
    final searchController = useTextEditingController();
    final leaveTypes = useState<List<Map<String, dynamic>>>([]);

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
                  typeController.clear();
                  descriptionController.clear();
                  startDateController.clear();
                  endDateController.clear();
                  daysController.clear();
                  leaveTypeId.value = null;
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    }

    Future<List<Map<String, dynamic>>> fetchLeaveTypes() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        showCustomDialog(context, 'Error', 'User not authenticated');
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
        showCustomDialog(context, 'Error', 'Failed to load leave types');
        return [];
      }
    }

    useEffect(() {
      fetchLeaveTypes().then((types) {
        leaveTypes.value = types;
      });
      return null;
    }, []);

    void showLeaveTypeBottomSheet(BuildContext context) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return DraggableScrollableSheet(
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search leave type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        // Filter the leave types based on search input
                        leaveTypes.value = leaveTypes.value.where((type) {
                          final typeName = type['name'].toString().toLowerCase();
                          return typeName.contains(value.toLowerCase());
                        }).toList();
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: leaveTypes.value.length,
                        itemBuilder: (context, index) {
                          final leaveType = leaveTypes.value[index];
                          return ListTile(
                            title: Text(
                              leaveType['name'],
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () {
                              typeController.text = leaveType['name'];
                              leaveTypeId.value = leaveType['leave_type_id'];
                              Navigator.pop(context); // Close the bottom sheet
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    Future<void> pickDate(BuildContext context, TextEditingController controller, bool isStartDate) async {
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
        if (isStartDate) {
          // Check if the start date is after the end date
          if (endDateController.text.isNotEmpty) {
            final endDate = DateFormat('yyyy-MM-dd').parse(endDateController.text);
            if (pickedDate.isAfter(endDate)) {
              showCustomDialog(context, 'Invalid Date', 'Start date cannot be after the end date.');
              return;
            }
          }
          controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        } else {
          // Check if the end date is before the start date
          if (startDateController.text.isNotEmpty) {
            final startDate = DateFormat('yyyy-MM-dd').parse(startDateController.text);
            if (pickedDate.isBefore(startDate)) {
              showCustomDialog(context, 'Invalid Date', 'End date cannot be before the start date.');
              return;
            }
          }
          controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        }

        // Calculate the number of days if both dates are selected
        if (startDateController.text.isNotEmpty && endDateController.text.isNotEmpty) {
          final startDate = DateFormat('yyyy-MM-dd').parse(startDateController.text);
          final endDate = DateFormat('yyyy-MM-dd').parse(endDateController.text);
          final difference = endDate.difference(startDate).inDays + 1;
          daysController.text = difference.toString();
        }
      }
    }

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
            showCustomDialog(context, 'Error', 'User not authenticated');
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

          // Log the raw response to inspect what the API is returning
          print('Response status: ${response.statusCode}');
          print('Response body: ${response.body}');

          // Handle different status codes
          if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
            showCustomDialog(context, 'Success', 'Your leave request has been submitted successfully.');
          } else {
            // Handle other status codes or unexpected responses
            try {
              final responseBody = jsonDecode(response.body);
              if (responseBody['success'] == true || responseBody.containsKey('data')) {
                showCustomDialog(context, 'Success', 'Your leave request has been submitted successfully.');
              } else {
                showCustomDialog(context, 'Error', 'Failed to submit leave request. Please check your input and try again.');
              }
            } catch (e) {
              showCustomDialog(context, 'Error', 'Failed to submit leave request. Please check your input and try again.');
            }
          }
        } catch (e) {
          showCustomDialog(context, 'Error', 'An error occurred: $e');
        }
      } else {
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
        flexibleSpace: Image.asset(
          'assets/ready_bg.png',
          fit: BoxFit.cover,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white54, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
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
                          ElevatedButton.icon(
                            onPressed: saveData,
                            icon: const Icon(Icons.add),
                            label: const Text("Add"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white, backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            onTap: () => showLeaveTypeBottomSheet(context),
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
                                  onTap: () => pickDate(context, startDateController, true),
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
                                  onTap: () => pickDate(context, endDateController, false),
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
      ),
    );
  }
}
