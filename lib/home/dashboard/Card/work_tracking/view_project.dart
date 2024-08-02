import 'package:flutter/material.dart';

class ViewProjectPage extends StatelessWidget {
  final Map<String, dynamic> project;

  const ViewProjectPage({required this.project});

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
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'View Project',
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
            _buildTextField('Created by', project['create_project_by']),
            const SizedBox(height: 10),
            _buildTextField('Name of Project', project['p_name']),
            const SizedBox(height: 10),
            _buildTextField('Department', project['d_name']),
            const SizedBox(height: 10),
            _buildTextField('Branch', project['b_name']),
            const SizedBox(height: 10),
            _buildTextField('Status', project['s_name']),
            const SizedBox(height: 10),
            _buildDateField('Deadline', project['dl']),
            const SizedBox(height: 10),
            _buildDateField('Extended Deadline', project['extend']),
            const SizedBox(height: 20),
            const Text(
              'Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildProgressBar(project['precent']),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: value ?? ''),
          readOnly: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: date ?? ''),
          readOnly: true,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(String? progressStr) {
    double progress = double.tryParse(progressStr ?? '0.0') ?? 0.0;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: progress / 100,
            color: Colors.yellow,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${progress.toStringAsFixed(0)}%',
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
