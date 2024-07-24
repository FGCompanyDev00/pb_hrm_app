import 'package:flutter/material.dart';

class EditProjectPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EditProjectPage({required this.project});

  @override
  _EditProjectPageState createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  late String _status;
  late String _branch;
  late String _department;
  late String _name;
  late String _deadline1;
  late String _deadline2;
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
    _name = widget.project['title'];
    _deadline1 = widget.project['deadline1'];
    _deadline2 = widget.project['deadline2'];
    _progress = widget.project['progress'];
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
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
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
                    onPressed: () {},
                    icon: Icon(Icons.delete),
                    label: Text('Delete'),
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
                    onPressed: () {},
                    icon: Icon(Icons.update),
                    label: Text('Update'),
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
            _buildTextField('Name of Project', _name),
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
                Expanded(child: _buildDateField('Dead-line1', _deadline1)),
                const SizedBox(width: 10),
                Expanded(child: _buildDateField('Dead-line2', _deadline2)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Percent *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildProgressBar(_progress),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onChanged: (newValue) {
            setState(() {
              value = newValue;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField(
      String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: options
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: date),
          decoration: InputDecoration(
            suffixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onChanged: (newValue) {
            setState(() {
              date = newValue;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            color: Colors.yellow,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
