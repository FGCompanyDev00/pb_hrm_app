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

    // Form Key for Validation
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Controllers
    final typeController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final startDateController = useTextEditingController();
    final endDateController = useTextEditingController();
    final daysController = useTextEditingController(text: '0');
    final searchController = useTextEditingController();

    // State Variables
    final leaveTypeId = useState<int?>(null);
    final allLeaveTypes = useState<List<Map<String, dynamic>>>([]);
    final filteredLeaveTypes = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLeaveTypes = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

    // Helper Method to Show Dialog
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
                    formKey.currentState?.reset();
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

    // Helper Method to Show Leave Type Bottom Sheet
    void showLeaveTypeBottomSheet(BuildContext context) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  children: [
                    // Search Field
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
                    // Leave Types List
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

    // Fetch Leave Types from API
    Future<List<Map<String, dynamic>>> fetchLeaveTypes() async {
      isLoadingLeaveTypes.value = true;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        showCustomDialog(context, 'Error', 'User not authenticated');
        isLoadingLeaveTypes.value = false;
        return [];
      }

      try {
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
        } else if (response.statusCode == 401) {
          showCustomDialog(
              context, 'Unauthorized', 'Your session has expired. Please log in again.');
          isLoadingLeaveTypes.value = false;
          return [];
        } else {
          showCustomDialog(context, 'Error', 'Failed to load leave types');
          isLoadingLeaveTypes.value = false;
          return [];
        }
      } catch (e) {
        showCustomDialog(context, 'Error', 'An error occurred: $e');
        isLoadingLeaveTypes.value = false;
        return [];
      }
    }

    // Fetch Leave Types on Init
    useEffect(() {
      fetchLeaveTypes().then((types) {
        allLeaveTypes.value = types;
        filteredLeaveTypes.value = types;
      });
      return null;
    }, []);

    // Date Picker Method
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
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: isDarkMode
                ? ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.orange,
                onPrimary: Colors.white,
                surface: Colors.grey[800]!,
                onSurface: Colors.white,
              ),
            )
                : ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.orange,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
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

    // Save Data Method
    Future<void> saveData() async {
      if (formKey.currentState?.validate() ?? false) {
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
            'Please fill in all required fields to submit your leave request.');
      }
    }

    // Widget Builder for Text Fields
    Widget buildTextField({
      required String label,
      required TextEditingController controller,
      bool readOnly = false,
      Widget? prefixIcon,
      Widget? suffixIcon,
      int maxLines = 1,
      String? Function(String?)? validator,
      VoidCallback? onTap,
      TextInputType keyboardType = TextInputType.text,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              contentPadding:
              const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
            ),
            validator: validator,
            onTap: onTap,
          ),
        ],
      );
    }

    // Responsive Layout Builder
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Leave Request Form',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode
            ? Colors.black.withOpacity(0.8)
            : Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image:
              AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: constraints.maxWidth < 600 ? 180 : 60),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Submit Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting.value ? null : saveData,
                            icon: const Icon(Icons.send),
                            label: const Text("Submit"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: isDarkMode
                                  ? Colors.black
                                  : Colors.white,
                              backgroundColor: isDarkMode
                                  ? Colors.orange.shade700
                                  : const Color(0xFFDBB342),
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15.0, horizontal: 32.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Type Field
                        buildTextField(
                          label: "Type*",
                          controller: typeController,
                          readOnly: true,
                          suffixIcon: const Icon(Icons.list),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a leave type';
                            }
                            return null;
                          },
                          onTap: () => showLeaveTypeBottomSheet(context),
                        ),
                        const SizedBox(height: 20),
                        // Description Field
                        buildTextField(
                          label: "Description*",
                          controller: descriptionController,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Date Fields
                        Row(
                          children: [
                            Expanded(
                              child: buildTextField(
                                label: "Start Date*",
                                controller: startDateController,
                                readOnly: true,
                                prefixIcon: const Icon(Icons.calendar_today),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a start date';
                                  }
                                  return null;
                                },
                                onTap: () =>
                                    pickDate(context, startDateController, true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: buildTextField(
                                label: "End Date*",
                                controller: endDateController,
                                readOnly: true,
                                prefixIcon: const Icon(Icons.calendar_today),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select an end date';
                                  }
                                  return null;
                                },
                                onTap: () =>
                                    pickDate(context, endDateController, false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Days Field (Enhanced)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Days*", style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 5),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  // Decrement Button
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
                                    tooltip: 'Decrease days',
                                  ),
                                  // Days Text Field
                                  Expanded(
                                    child: TextFormField(
                                      controller: daysController,
                                      readOnly: true,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 12.0),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Days cannot be empty';
                                        }
                                        if (int.tryParse(value) == null ||
                                            int.parse(value) <= 0) {
                                          return 'Invalid number of days';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  // Increment Button
                                  IconButton(
                                    onPressed: () {
                                      int currentDays =
                                          int.tryParse(daysController.text) ?? 0;
                                      daysController.text =
                                          (currentDays + 1).toString();
                                    },
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Increase days',
                                  ),
                                ],
                              ),
                            ),
                            // Display Validation Error if any
                            // Positioned below the container for better UX
                            // Only show if there is an error
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Loading Indicator
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
        },
      ),
    );
  }
}
