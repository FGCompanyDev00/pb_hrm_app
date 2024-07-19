import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';
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

    final leaveTypes = ['Holiday Leave', 'Sick Leave', 'Unpaid Leave'];

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
        controller.text = DateFormat('dd-MM-yyyy').format(pickedDate);
        if (startDateController.text.isNotEmpty && endDateController.text.isNotEmpty) {
          final startDate = DateFormat('dd-MM-yyyy').parse(startDateController.text);
          final endDate = DateFormat('dd-MM-yyyy').parse(endDateController.text);
          final difference = endDate.difference(startDate).inDays + 1;
          daysController.text = difference.toString();
        }
      }
    }

    void saveData() {
      if (typeController.text.isNotEmpty &&
          descriptionController.text.isNotEmpty &&
          startDateController.text.isNotEmpty &&
          endDateController.text.isNotEmpty &&
          daysController.text.isNotEmpty) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Column(
                children: [
                  Image.asset(
                    'assets/success_icon.png',
                    height: 60,
                  ),
                  const SizedBox(height: 10),
                  const Text('Success'),
                ],
              ),
              content: const Text('Your data has been saved!'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        EasyLoading.showError('Please fill in all fields');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Please fill in all fields to submit your leave request.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Leave Management"),
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
            child: Container(
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
                            foregroundColor: isDarkMode ? Colors.white : Colors.black, backgroundColor: Colors.orange,
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
                              onSelected: (String value) {
                                typeController.text = value;
                              },
                              itemBuilder: (BuildContext context) {
                                return leaveTypes.map<PopupMenuItem<String>>((String value) {
                                  return PopupMenuItem<String>(
                                    value: value,
                                    child: Text(value),
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
            ),
          ),
        ],
      ),
    );
  }
}
