
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';

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

  final Map<String, String> statusMap = {
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Completed': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };


  @override
  void initState() {
    super.initState();

    _status = statusMap.entries
        .firstWhere((entry) => entry.value == widget.project['status_id'], orElse: () => const MapEntry('Pending', '40d2ba5e-a978-47ce-bc48-caceca8668e9'))
        .key;
    _branch = 'HQ office';
    _department = 'Digital Banking Dept';
    _nameController = TextEditingController(text: widget.project['p_name']);
    _deadline1Controller = TextEditingController(text: widget.project['dl']);
    _deadline2Controller = TextEditingController(text: widget.project['extend']);
    _progress = (double.tryParse(widget.project['precent']?.toString() ?? '0') ?? 0) / 100;
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

  Future<void> _updateProject() async {
    if (_nameController.text.isEmpty || _deadline1Controller.text.isEmpty || _deadline2Controller.text.isEmpty) {
      _showErrorDialog('All fields are required');
      return;
    }

    final updatedProject = {
      "project_name": _nameController.text.trim(),
      "department_id": "147",
      "branch_id": "1",
      "status_id": statusMap[_status]!,
      "precent_of_project": (_progress * 100).toStringAsFixed(0),
      "deadline": _deadline1Controller.text.trim(),
      "extended": _deadline2Controller.text.trim(),
    };

    try {
      final response = await WorkTrackingService().updateProject(widget.project['project_id'], updatedProject);

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onUpdate(updatedProject);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${_nameController.text}" has been successfully updated.'),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      } else {
        _showErrorDialog('Failed to update project: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _deleteProject() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the project "${widget.project['p_name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed) {
      try {
        await WorkTrackingService().deleteProject(widget.project['project_id']);
        widget.onDelete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${widget.project['p_name']}" has been successfully deleted.'),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        _showErrorDialog(e.toString());
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 24.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          title: const Padding(
            padding: EdgeInsets.only(top: 30.0),
            child: Text('Edit Project'),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleteProject,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.grey,
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
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.amber,
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
                  Expanded(child: _buildDateField('Deadline', _deadline1Controller)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDateField('Extended Deadline', _deadline2Controller)),
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

  Widget _buildDateField(String label, TextEditingController controller) {
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