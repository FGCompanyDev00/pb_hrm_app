import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';

class SelectAssignmentMembersPage extends StatefulWidget {
  final String projectId;

  const SelectAssignmentMembersPage({super.key, required this.projectId});

  @override
  _SelectAssignmentMembersPageState createState() => _SelectAssignmentMembersPageState();
}

class _SelectAssignmentMembersPageState extends State<SelectAssignmentMembersPage> {
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  List<Map<String, dynamic>> _projectMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchProjectMembers();
  }

  Future<void> _fetchProjectMembers() async {
    try {
      final members = await _workTrackingService.getProjectMembers(widget.projectId);
      setState(() {
        _projectMembers = members;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching project members: $e');
      }
    }
  }

  void _toggleSelection(Map<String, dynamic> member) {
    setState(() {
      if (_selectedMembers.contains(member)) {
        _selectedMembers.remove(member);
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  void _submitSelection() {
    Navigator.pop(context, _selectedMembers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitSelection,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _projectMembers.length,
        itemBuilder: (context, index) {
          final member = _projectMembers[index];
          final isSelected = _selectedMembers.contains(member);
          return ListTile(
            title: Text(member['name']),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (value) {
                _toggleSelection(member);
              },
            ),
          );
        },
      ),
    );
  }
}
