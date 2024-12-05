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
  _ReturnCarPageDetailsState createState() => _ReturnCarPageDetailsState();
}

class _ReturnCarPageDetailsState extends State<ReturnCarPageDetails> {
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
      Uri.parse(
          '$baseUrl/api/office-administration/car_permit/complete/${widget.uid}'),
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
        showResponseModal(context, success: true, message: responseData['message']);
      } else {
        // API returned an error
        String errorMessage = responseData['message'] ?? 'An error occurred.';
        showResponseModal(context, success: false, message: errorMessage);
      }
    } else if (responseData != null && responseData['message'] != null) {
      // Handle error message from API payload
      String errorMessage = responseData['message'];
      showResponseModal(context, success: false, message: errorMessage);
    } else {
      // HTTP error without specific API error message
      showResponseModal(context, success: false, message: 'Failed to confirm return. Please try again.');
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
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: const Padding(
            padding: EdgeInsets.only(top: 30.0),
            child: Text(
              'Return',
              style: TextStyle(
                color: Colors.black,
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
                  eventData?['created_date'] != null
                      ? DateFormat('MMMM dd, yyyy').format(
                      DateTime.parse(eventData!['created_date']).toLocal())
                      : '',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTextField('Recipient Name *', recipientNameController),
                  const SizedBox(height: 12),
                  buildTextField('Distance *', distanceController, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  buildDateField(
                      context, 'Departure Date *', departureDateController),
                  const SizedBox(height: 12),
                  buildDateField(
                      context, 'Return Date *', returnDateController),
                  const SizedBox(height: 12),
                  const Text(
                    'File',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2AD30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(type: FileType.any);

                          if (result != null) {
                            setState(() {
                              selectedFile = result.files.first;
                            });
                          }
                        },
                        child: const Text('Choose File'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedFile != null
                              ? selectedFile!.name
                              : 'No file chosen',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBB342),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => validateAndProceed(),
                child: const Text(
                  'Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDateField(BuildContext context, String label,
      TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            DateTime initialDate = DateTime.now();
            if (controller.text.isNotEmpty) {
              try {
                initialDate = DateTime.parse(controller.text);
              } catch (e) {}
            }

            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );

            if (pickedDate != null) {
              String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
              controller.text = formattedDate;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void validateAndProceed() {
    if (recipientNameController.text.isEmpty ||
        distanceController.text.isEmpty ||
        departureDateController.text.isEmpty ||
        returnDateController.text.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Proceed to comment modal
      showCommentModal(context);
    }
  }

  void showCommentModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble,
                      color: Color(0xFFE2BD30), size: 40),
                  const SizedBox(height: 10),
                  const Text('Comment',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Please put your comment here',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2BD30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      confirmReturn();
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showResponseModal(BuildContext context, {required bool success, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: success ? const Color(0xFFE2BD30) : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    success ? 'SUCCESS' : 'ERROR',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      success ? const Color(0xFFE2BD30) : Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (success) {
                        Navigator.pop(context); // Return to previous screen
                      }
                    },
                    child: const Text('Okay'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    } else if (eventData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: buildAppBar(context),
        body: const Center(child: Text('Failed to load data')),
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: buildAppBar(context),
        body: buildBody(context),
      );
    }
  }
}
