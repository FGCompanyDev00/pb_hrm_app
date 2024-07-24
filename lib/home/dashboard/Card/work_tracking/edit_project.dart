import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';

class EditProjectPage extends StatefulWidget {
  final Map<String, dynamic> project;
  final Function(Map<String, dynamic>) onUpdate;
  final Function onDelete;

  const EditProjectPage({super.key, required this.project, required this.onUpdate, required this.onDelete});

  @override
  _EditProjectPageState createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  late TextEditingController _nameController;
  late TextEditingController _deadline1Controller;
  late TextEditingController _deadline2Controller;
  late String _status;
  late String _branch;
  late String _department;
  late double _progress;

  final List<String> _statusOptions = ['Pending', 'Processing', 'Completed'];
  final List<String> _branchOptions = ['HQ office', 'Branch office'];
  final List<String> _departmentOptions = ['Digital Banking Dept', 'HR Dept', 'Finance Dept'];

  @override
  void initState() {
    super.initState();
    _status = widget.project['status'];
    _branch = 'HQ office';
    _department = 'Digital Banking Dept';
    _nameController = TextEditingController(text: widget.project['title']);
    _deadline1Controller = TextEditingController(text: widget.project['deadline1']);
    _deadline2Controller = TextEditingController(text: widget.project['deadline2']);
    _progress = widget.project['progress'];
  }

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

  void _updateProject() {
    final updatedProject = {
      'title': _nameController.text,
      'status': _status,
      'deadline1': _deadline1Controller.text,
      'deadline2': _deadline2Controller.text,
      'progress': _progress,
    };
    widget.onUpdate(updatedProject);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Project Updated'),
          content: const Text('Your project has been updated successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context); // Close the edit page
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProject() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.onDelete();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const WorkTrackingPage()),
                    );
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteProject,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.grey, // Text color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _updateProject,
                    icon: const Icon(Icons.update),
                    label: const Text('Update'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.amber, // Text color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField('Name of Project', _nameController),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDropdownField('Status', _status, _statusOptions, (value) {
                  setState(() {
                    _status = value!;
                  });
                })),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdownField('Branch', _branch, _branchOptions, (value) {
                  setState(() {
                    _branch = value!;
                  });
                })),
              ],
            ),
            const SizedBox(height: 10),
            _buildDropdownField('Department', _department, _departmentOptions, (value) {
              setState(() {
                _department = value!;
              });
            }),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDateField('Dead-line1', _deadline1Controller, true)),
                const SizedBox(width: 10),
                Expanded(child: _buildDateField('Dead-line2', _deadline2Controller, false)),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildProgressBar(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, bool isDeadline1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _selectDate(context, controller),
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
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
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(_progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
