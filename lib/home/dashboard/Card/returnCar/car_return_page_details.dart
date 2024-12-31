// lib/return_car_page_details.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReturnCarPageDetails extends StatefulWidget {
  final String uid;
  const ReturnCarPageDetails({super.key, required this.uid});

  @override
  ReturnCarPageDetailsState createState() => ReturnCarPageDetailsState();
}

class ReturnCarPageDetailsState extends State<ReturnCarPageDetails> {
  bool isLoading = true;
  Map<String, dynamic>? eventData;
  final TextEditingController recipientNameController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController departureDateController = TextEditingController();
  final TextEditingController returnDateController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  PlatformFile? selectedFile;

  @override
  void initState() {
    super.initState();
    fetchEventData();
  }

  Future<void> fetchEventData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('No token found');
      }
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/app/tasks/approvals/return/${widget.uid}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['results'] != null) {
        eventData = data['results'];

        // Map fields correctly
        recipientNameController.text = eventData?['requestor_name'] ?? '';
        distanceController.text = eventData?['distance_end']?.toString() ?? '';
        departureDateController.text = eventData?['date_out'] ?? '';
        returnDateController.text = eventData?['date_in'] ?? '';

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        if (kDebugMode) {
          print('No results found in response.');
        }
      }
    } else {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('Failed to load event data: ${response.statusCode}');
      }
    }
  }

  Future<void> confirmReturn() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (kDebugMode) {
        print('No token found');
      }
      return;
    }

    final Map<String, String> body = {
      'distance_end': distanceController.text,
      'real_time_out': departureDateController.text,
      'real_time_in': returnDateController.text,
      'driver_name': recipientNameController.text,
    };

    if (commentController.text.isNotEmpty) {
      body['comment'] = commentController.text;
    }

    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/office-administration/car_permit/complete/${widget.uid}'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(body);

    if (selectedFile != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'files',
        selectedFile!.bytes!,
        filename: selectedFile!.name,
      ));
    }

    final response = await request.send();

    if (kDebugMode) {
      print('Response status: ${response.statusCode}');
    }

    final responseBody = await response.stream.bytesToString();
    Map<String, dynamic>? responseData;

    try {
      responseData = json.decode(responseBody);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to parse response body: $e');
      }
    }

    if (response.statusCode == 200 && responseData != null) {
      if (responseData['statusCode'] == 200 || responseData['statusCode'] == 201) {
        // Success
        if (mounted) showResponseModal(context, success: true, message: responseData['message']);
      } else {
        // API returned an error
        String errorMessage = responseData['message'] ?? 'An error occurred.';
        if (mounted) showResponseModal(context, success: false, message: errorMessage);
      }
    } else if (responseData != null && responseData['message'] != null) {
      // Handle error message from API payload
      String errorMessage = responseData['message'];
      if (mounted) showResponseModal(context, success: false, message: errorMessage);
    } else {
      // HTTP error without specific API error message
      if (mounted) showResponseModal(context, success: false, message: 'Failed to confirm return. Please try again.');
    }
  }

  @override
  void dispose() {
    recipientNameController.dispose();
    distanceController.dispose();
    departureDateController.dispose();
    returnDateController.dispose();
    commentController.dispose();
    super.dispose();
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return PreferredSize(
      preferredSize: const Size.fromHeight(80.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 30.0),
            child: Text(
              'Return',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  eventData?['created_date'] != null ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(eventData!['created_date']).toLocal()) : '',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.green,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTextField(
                    'Recipient Name *',
                    recipientNameController,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  buildTextField(
                    'Distance *',
                    distanceController,
                    keyboardType: TextInputType.number,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  buildDateField(context, 'Departure Date *', departureDateController, isDarkMode),
                  const SizedBox(height: 12),
                  buildDateField(context, 'Return Date *', returnDateController, isDarkMode),
                  const SizedBox(height: 12),
                  Text(
                    'File',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.green : Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

                          if (result != null) {
                            setState(() {
                              selectedFile = result.files.first;
                            });
                          }
                        },
                        child: Text(
                          'Select file',
                          style: TextStyle(
                            color: isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (selectedFile != null) ...[
                        Expanded(
                          child: Text(
                            selectedFile!.name,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Comment',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your comment here',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                      fillColor: isDarkMode ? Colors.grey[700] : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey : Colors.grey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey : Colors.grey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.orangeAccent : const Color(0xFFE2AD30),
                        ),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      confirmReturn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.orangeAccent : const Color(0xFFE2AD30),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Confirm Return',
                      style: TextStyle(
                        color: isDarkMode ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey : Colors.grey,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.orangeAccent : const Color(0xFFE2AD30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDateField(BuildContext context, String label, TextEditingController controller, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: Icon(
                Icons.calendar_today,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: controller.text.isNotEmpty ? DateTime.parse(controller.text) : DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                  builder: (context, child) {
                    return Theme(
                      data: isDarkMode
                          ? ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Colors.orangeAccent,
                                onPrimary: Colors.black,
                                surface: Colors.grey[800]!,
                                onSurface: Colors.white,
                              ),
                            )
                          : ThemeData.light(),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null) {
                  controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey : Colors.grey,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.orangeAccent : const Color(0xFFE2AD30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void showResponseModal(
    BuildContext context, {
    required bool success,
    required String message,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text(
            success ? 'Success' : 'Error',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  color: isDarkMode ? Colors.orangeAccent : Colors.blue,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: buildAppBar(context),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? Colors.orangeAccent : Colors.blue,
              ),
            )
          : buildBody(context),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
    );
  }
}
