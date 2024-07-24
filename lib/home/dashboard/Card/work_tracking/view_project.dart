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
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'View',
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
            _buildTextField('Create person', project['author']),
            const SizedBox(height: 10),
            _buildTextField('Name of Project', project['title']),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildTextField('Status', project['status'])),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('Branch', 'HQ office')),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField('Department', 'Digital Banking Dept'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDateField('Dead-line1', project['deadline1'])),
                const SizedBox(width: 10),
                Expanded(child: _buildDateField('Dead-line2', project['deadline2'])),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Percent *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildProgressBar(project['progress']),
            const SizedBox(height: 20),
            Text(
              'Member:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildMemberAvatars(),
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
          readOnly: true,
          decoration: InputDecoration(
            suffixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
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

  Widget _buildMemberAvatars() {
    return Row(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/member$index.png'),
            radius: 20,
          ),
        );
      }),
    );
  }
}
