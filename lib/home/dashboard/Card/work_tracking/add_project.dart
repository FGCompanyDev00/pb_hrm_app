import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_people_page.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key});

  @override
  AddProjectPageState createState() => AddProjectPageState();
}

class AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _deadline1Controller = TextEditingController();
  final TextEditingController _deadline2Controller = TextEditingController();

  // Map for status names and their corresponding IDs
  final Map<String, String> statusMap = {
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  String _selectedStatus = 'Processing';
  String _selectedBranch = 'HQ Office';
  String _selectedDepartment = 'Digital Banking Dept';
  double _progress = 0.5;
  bool _isLoading = false;

  @override
  void dispose() {
    _projectNameController.dispose();
    _deadline1Controller.dispose();
    _deadline2Controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    try {
      print('Opening date picker for ${controller == _deadline1Controller ? 'Deadline' : 'Extended Deadline'}');
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
        print('Selected date for ${controller == _deadline1Controller ? 'Deadline' : 'Extended Deadline'}: ${controller.text}');
      } else {
        print('No date selected for ${controller == _deadline1Controller ? 'Deadline' : 'Extended Deadline'}');
      }
    } catch (e) {
      print('Error selecting date: $e');
      _showErrorDialog('Failed to select date. Please try again.');
    }
  }

  Future<void> _createProjectAndProceed() async {
    print('Attempting to create project...');
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      print('Form is valid. Preparing data for API.');

      final newProject = {
        'project_name': _projectNameController.text.trim(),
        'department_id': '1',
        'branch_id': '1',
        'status_id': statusMap[_selectedStatus]!,
        'precent_of_project': (_progress * 100).toStringAsFixed(0),
        'deadline': _deadline1Controller.text.trim(),
        'extended': _deadline2Controller.text.trim(),
      };

      print('Project Data: $newProject');

      try {
        print('Sending project data to API...');
        final projectId = await WorkTrackingService().addProject(newProject);
        print('Received project ID from API: $projectId');

        if (projectId != null) {
          print('Navigating to AddPeoplePage with project ID: $projectId');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AddPeoplePage(projectId: projectId),
            ),
          );
        } else {
          print('API returned null project ID.');
          _showErrorDialog('Project created but failed to retrieve project ID. Please try again.');
        }
      } catch (e) {
        print('Error creating project: $e');
        _showErrorDialog('Failed to create project. Error: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
        print('Finished project creation process.');
      }
    } else {
      print('Form validation failed.');
    }
  }

  void _showErrorDialog(String message) {
    print('Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              print('Error dialog dismissed.');
              Navigator.of(context).pop();
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Create Project',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            print('Back button pressed.');
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    label: 'Name of Project',
                    controller: _projectNameController,
                    isDarkMode: isDarkMode,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        print('Validation failed: Project name is empty.');
                        return 'Please enter the project name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Status',
                    value: _selectedStatus,
                    options: ['Processing', 'Pending', 'Finished'],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                      print('Selected Status: $value');
                    },
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Branch',
                    value: _selectedBranch,
                    options: ['HQ Office', 'Samsen Thai B', 'HQ Office Premier Room'],
                    onChanged: (value) {
                      setState(() {
                        _selectedBranch = value!;
                      });
                      print('Selected Branch: $value');
                    },
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Department',
                    value: _selectedDepartment,
                    options: ['Digital Banking Dept', 'IT Department', 'Teller'],
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartment = value!;
                      });
                      print('Selected Department: $value');
                    },
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Deadline',
                          controller: _deadline1Controller,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildDateField(
                          label: 'Extended Deadline',
                          controller: _deadline2Controller,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Progress *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProgressBar(isDarkMode),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? () {
          print('Button pressed but currently loading. Action is disabled.');
        } : _createProjectAndProceed,
        backgroundColor: Colors.green,
        icon: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.arrow_forward),
        label: const Text('Next'),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isDarkMode,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 10),
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
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _selectDate(context, controller),
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                suffixIcon: Icon(Icons.calendar_today, color: isDarkMode ? Colors.white : Colors.black),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
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
              print('Progress updated to: ${(_progress * 100).toStringAsFixed(0)}%');
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
