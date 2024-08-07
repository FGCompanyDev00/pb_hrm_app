import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';

class AddProjectPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddProject;

  const AddProjectPage({required this.onAddProject, super.key});

  @override
  AddProjectPageState createState() => AddProjectPageState();
}

class AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _deadline1Controller = TextEditingController();
  final TextEditingController _deadline2Controller = TextEditingController();

  String _selectedStatus = 'Processing';
  String _selectedBranch = 'HQ Office';
  String _selectedDepartment = 'Digital Banking Dept';
  double _progress = 0.5;

  final List<String> _statusOptions = ['Processing', 'Pending', 'Finished'];
  final List<String> _branchOptions = [
    'HQ Office',
    'Samsen thai B',
    'HQ office premier room',
    'HQ office loan meeting room',
    'Back Can yon 2F(1)',
    'Back Can yon 2F(2)'
  ];
  final List<String> _departmentOptions = [
    'Digital Banking Dept',
    'IT department',
    'Teller',
    'HQ office loan meeting room',
    'Back Can yon 2F(1)',
    'Back Can yon 2F(2)'
  ];

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  Future<void> _addProject() async {
    if (_formKey.currentState!.validate()) {
      final String projectId = const Uuid().v4();
      final newProject = {
        'project_name': _projectNameController.text,
        'department_id': '1', // Map this to the actual selected department ID
        'branch_id': '1', // Map this to the actual selected branch ID
        'status_id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', // Example status ID
        'precent_of_project': (_progress * 100).toStringAsFixed(0),
        'deadline': _deadline1Controller.text,
        'extended': _deadline2Controller.text,
        'project_id': projectId,
      };

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Add Project'),
            content: const Text('Are you sure you want to add this project?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the confirmation dialog
                  try {
                    await WorkTrackingService().addProject(newProject);
                    widget.onAddProject(newProject);
                    _showSuccessDialog(); // Show success message and navigate back
                  } catch (e) {
                    _showErrorDialog(e.toString());
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project Added'),
        content: const Text('Your project has been added successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the success dialog
              Navigator.of(context).pop(); // Close the add project page
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WorkTrackingPage()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: Text(
          'Create New Project',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: _projectNameController,
                  decoration: InputDecoration(
                    labelText: 'Name of Project',
                    labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the project name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField('Status', _selectedStatus, _statusOptions, (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                _buildDropdownField('Branch', _selectedBranch, _branchOptions, (value) {
                  setState(() {
                    _selectedBranch = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                _buildDropdownField('Department', _selectedDepartment, _departmentOptions, (value) {
                  setState(() {
                    _selectedDepartment = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField('Deadline', _deadline1Controller, isDarkMode),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateField('Extended Deadline', _deadline2Controller, isDarkMode),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Percent *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                _buildProgressBar(isDarkMode),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _addProject,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('+ Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _selectDate(context, controller),
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: Icon(Icons.calendar_today, color: isDarkMode ? Colors.white : Colors.black),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a date';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _progress,
            onChanged: (value) {
              setState(() {
                _progress = value;
              });
            },
            min: 0,
            max: 1,
            divisions: 100,
            label: '${(_progress * 100).toStringAsFixed(0)}%',
            activeColor: isDarkMode ? Colors.amber : Colors.blue,
            inactiveColor: isDarkMode ? Colors.grey : Colors.grey[300],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(_progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
