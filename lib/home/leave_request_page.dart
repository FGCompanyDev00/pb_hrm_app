// leave_request_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';

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
    final allLeaveTypes = useState<List<Map<String, dynamic>>>([]);
    final filteredLeaveTypes = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLeaveTypes = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

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
                  if (title == 'Success') {
                    typeController.clear();
                    descriptionController.clear();
                    startDateController.clear();
                    endDateController.clear();
                    daysController.text = '0';
                    leaveTypeId.value = null;
                  }
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    }

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
                        filteredLeaveTypes.value = allLeaveTypes.value.where((type) {
                          final typeName = type['name'].toString().toLowerCase();
                          return typeName.contains(value.toLowerCase());
                        }).toList();
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: isLoadingLeaveTypes.value
                          ? const Center(child: CircularProgressIndicator())
                          : filteredLeaveTypes.value.isEmpty
                          ? const Center(child: Text('No leave types available'))
                          : ListView.builder(
                        controller: scrollController,
                        itemCount: filteredLeaveTypes.value.length,
                        itemBuilder: (context, index) {
                          final leaveType = filteredLeaveTypes.value[index];
                          return ListTile(
                            title: Text(
                              leaveType['name'],
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            onTap: () {
                              typeController.text = leaveType['name'];
                              leaveTypeId.value = leaveType['leave_type_id'];
                              Navigator.pop(context);
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

    Future<List<Map<String, dynamic>>> fetchLeaveTypes() async {
      isLoadingLeaveTypes.value = true;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        showCustomDialog(context, 'Error', 'User not authenticated');
        isLoadingLeaveTypes.value = false;
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

        if (data.containsKey('results')) {
          List<Map<String, dynamic>> types =
          List<Map<String, dynamic>>.from(data['results']);
          isLoadingLeaveTypes.value = false;
          return types;
        } else {
          showCustomDialog(context, 'Error', 'Unexpected API response structure.');
          isLoadingLeaveTypes.value = false;
          return [];
        }
      } else {
        showCustomDialog(context, 'Error', 'Failed to load leave types');
        isLoadingLeaveTypes.value = false;
        return [];
      }
    }

    useEffect(() {
      fetchLeaveTypes().then((types) {
        allLeaveTypes.value = types;
        filteredLeaveTypes.value = types;
      });
      return null;
    }, []);

    Future<void> pickDate(BuildContext context, TextEditingController controller,
        bool isStartDate) async {
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
          if (endDateController.text.isNotEmpty) {
            final endDate = DateFormat('yyyy-MM-dd').parse(endDateController.text);
            if (pickedDate.isAfter(endDate)) {
              showCustomDialog(
                  context, 'Invalid Date', 'Start date cannot be after the end date.');
              return;
            }
          }
          controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        } else {
          if (startDateController.text.isNotEmpty) {
            final startDate = DateFormat('yyyy-MM-dd').parse(startDateController.text);
            if (pickedDate.isBefore(startDate)) {
              showCustomDialog(
                  context, 'Invalid Date', 'End date cannot be before the start date.');
              return;
            }
          }
          controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        }

        if (startDateController.text.isNotEmpty && endDateController.text.isNotEmpty) {
          final startDate =
          DateFormat('yyyy-MM-dd').parse(startDateController.text);
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
          daysController.text.isNotEmpty &&
          leaveTypeId.value != null) {
        try {
          isSubmitting.value = true;
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token == null) {
            showCustomDialog(context, 'Error', 'User not authenticated');
            isSubmitting.value = false;
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

          if (response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 204) {
            showCustomDialog(context, 'Success',
                'Your leave request has been submitted successfully.');
          } else if (response.statusCode == 400) {
            final responseBody = jsonDecode(response.body);
            String errorMessage = 'Failed to submit leave request.';
            if (responseBody is Map && responseBody.containsKey('message')) {
              errorMessage = responseBody['message'];
            }
            showCustomDialog(context, 'Error', errorMessage);
          } else if (response.statusCode == 401) {
            showCustomDialog(
                context, 'Unauthorized', 'Your session has expired. Please log in again.');
          } else {
            showCustomDialog(context, 'Error',
                'Failed to submit leave request. Please try again.');
          }
        } catch (e) {
          showCustomDialog(context, 'Error', 'An error occurred: $e');
        } finally {
          isSubmitting.value = false;
        }
      } else {
        showCustomDialog(context, 'Error',
            'Please fill in all fields to submit your leave request.');
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Leave Request Form',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white  // Dark mode text color
                : Colors.black, // Light mode text color
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white // White icon for dark mode
                : Colors.black, // Black icon for light mode
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting.value ? null : saveData,
                      icon: const Icon(Icons.send),
                      label: const Text("Submit"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black // Dark mode text color
                            : Colors.white, // Light mode text color
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade700 // Dark mode background color
                            : Colors.orange, // Light mode background color
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 15.0, horizontal: 30.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Type*"),
                      const SizedBox(height: 5),
                      TextField(
                        controller: typeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 10.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: const Icon(Icons.list),
                        ),
                        onTap: () => showLeaveTypeBottomSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Description*"),
                      const SizedBox(height: 5),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 10.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Start Date*"),
                            const SizedBox(height: 5),
                            TextField(
                              controller: startDateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15.0, horizontal: 10.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              onTap: () =>
                                  pickDate(context, startDateController, true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("End Date*"),
                            const SizedBox(height: 5),
                            TextField(
                              controller: endDateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15.0, horizontal: 10.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              onTap: () =>
                                  pickDate(context, endDateController, false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Days*"),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: daysController,
                              readOnly: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15.0, horizontal: 10.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  int currentDays =
                                      int.tryParse(daysController.text) ?? 0;
                                  daysController.text =
                                      (currentDays + 1).toString();
                                },
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                onPressed: () {
                                  int currentDays =
                                      int.tryParse(daysController.text) ?? 0;
                                  if (currentDays > 1) {
                                    daysController.text =
                                        (currentDays - 1).toString();
                                  }
                                },
                                icon: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isSubmitting.value)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
