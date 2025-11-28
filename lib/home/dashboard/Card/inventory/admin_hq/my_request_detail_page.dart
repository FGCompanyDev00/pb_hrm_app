import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/comment_modal.dart';
import '../inventory_app_bar.dart';

class MyRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MyRequestDetailPage({super.key, required this.requestData});

  @override
  State<MyRequestDetailPage> createState() => _MyRequestDetailPageState();
}

class _MyRequestDetailPageState extends State<MyRequestDetailPage> {
  Map<String, dynamic> _requestDetails = {};
  List<Map<String, dynamic>> _requestItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isSubmitting = false;
  bool _isFeedbackExpanded = false;
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  final String _imageBaseUrl = 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      if (token == null || baseUrl == null) {
        throw Exception('Authentication token or BASE_URL not configured');
      }
      final topicUid = widget.requestData['topic_uniq_id'] ?? widget.requestData['topicid'] ?? '';
      if (topicUid.isEmpty) {
        throw Exception('No topic UID found in request data');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/my-request-topic-detail/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['results'];
        if (result == null) throw Exception('No results');

        final List<dynamic> details = result['details'] ?? [];
        setState(() {
          _requestDetails = Map<String, dynamic>.from(result);
          _requestItems = List<Map<String, dynamic>>.from(details.map((e) => Map<String, dynamic>.from(e)));
          _titleController.text = _requestDetails['title'] ?? '';
          _isLoading = false;
        });
        // Debug: Log status for troubleshooting
        debugPrint('🔍 [MyRequestDetail] Loaded status: "${_requestDetails['status']}"');
        debugPrint('🔍 [MyRequestDetail] CanEditItems: ${_canEditItems}, IsFinalStatus: ${_isFinalStatus}');
      } else {
        throw Exception('Failed to fetch request details: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final isDarkMode = themeNotifier.isDarkMode;
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          appBar: const InventoryAppBar(title: 'My Request', showBack: true),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadRequestDetails, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isDarkMode),
                          const SizedBox(height: 16),
                          // Title field (editable if Supervisor Pending)
                          if (_canEditItems) _buildTitleField(isDarkMode),
                          if (_canEditItems) const SizedBox(height: 16),
                          _buildItems(isDarkMode),
                          const SizedBox(height: 16),
                          if (_isFinalStatus)
                            _buildFeedbackSectionWidget(isDarkMode),
                          if (!_isFinalStatus) _buildUpdateCancelRow(isDarkMode),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    // Check both img_path and img_name for image
    final imgPath = _requestDetails['img_path'] ?? '';
    final imgName = _requestDetails['img_name'] ?? '';
    final imageUrl = _getImageUrl(imgPath.isNotEmpty ? imgPath : imgName);
    final submittedAt = _formatDate(_requestDetails['created_at']);
    final status = (_requestDetails['status'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFDBB342), width: 2)),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person))
                  : const Icon(Icons.person),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_requestDetails['employee_name'] ?? '-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text('Submitted on $submittedAt', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(20)),
                child: Text('Status: $status', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Title',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter request title...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFFDBB342).withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBB342), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Requested Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        ...List.generate(_requestItems.length, (i) => _buildItemCard(_requestItems[i], isDarkMode, i)),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isDarkMode, int index) {
    final name = item['name'] ?? 'Unknown';
    final qty = (item['quantity'] is String) ? int.tryParse(item['quantity']) ?? 0 : (item['quantity'] ?? 0);
    final imageUrl = _getItemImageUrl(item['img_ref']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
      ]),
      child: Stack(
        children: [
          Row(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.computer)) : const Icon(Icons.computer),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
            // Quantity controls (if editable)
            if (_canEditItems)
              Row(children: [
                IconButton(onPressed: () => _decrementQuantity(index), icon: const Icon(Icons.remove_circle_outline), color: isDarkMode ? Colors.white70 : Colors.black54),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDBB342).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(qty.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDBB342)))),
                IconButton(onPressed: () => _incrementQuantity(index), icon: const Icon(Icons.add_circle_outline), color: isDarkMode ? Colors.white70 : Colors.black54),
                IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.delete_outline), color: Colors.red[400]),
              ]),
      ]),
          // Quantity display at bottom right (for final status)
          if (_isFinalStatus && !_canEditItems)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBB342).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  qty.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDBB342),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _isFinalStatus {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    // Supervisor Pending is NOT a final status - user can still edit
    if (s.contains('supervisor pending')) {
      debugPrint('🔍 [MyRequestDetail] Status "$statusStr" is Supervisor Pending - NOT final status');
      return false;
    }
    final isFinal = s.contains('approved') || s.contains('decline') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported') || s.contains('cancel');
    debugPrint('🔍 [MyRequestDetail] Status "$statusStr" isFinalStatus: $isFinal');
    return isFinal;
  }

  bool get _canEditItems {
    final statusStr = (_requestDetails['status'] ?? '').toString();
    final s = statusStr.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
    // Check for supervisor pending status (with or without dots, case insensitive)
    final canEdit = s.contains('supervisor pending');
    debugPrint('🔍 [MyRequestDetail] Status: "$statusStr", Normalized: "$s", CanEditItems: $canEdit');
    return canEdit;
  }

  void _incrementQuantity(int index) {
    setState(() {
      final current = (_requestItems[index]['quantity'] is String) ? int.tryParse(_requestItems[index]['quantity']) ?? 0 : (_requestItems[index]['quantity'] ?? 0);
      _requestItems[index]['quantity'] = current + 1;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      final current = (_requestItems[index]['quantity'] is String) ? int.tryParse(_requestItems[index]['quantity']) ?? 0 : (_requestItems[index]['quantity'] ?? 0);
      if (current > 1) _requestItems[index]['quantity'] = current - 1;
    });
  }

  void _removeItem(int index) {
    setState(() => _requestItems.removeAt(index));
  }

  Widget _buildUpdateCancelRow(bool isDarkMode) {
    return Row(children: [
      Expanded(
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitUpdate,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDBB342), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_isSubmitting ? 'Updating...' : 'Update'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  String? comment;
                  await showDialog(
                    context: context,
                    builder: (context) => CommentModal(
                      action: 'Submit',
                      onConfirm: (c) { comment = c; Navigator.of(context).pop(); },
                      onCancel: () { Navigator.of(context).pop(); },
                    ),
                  );
                  if ((comment ?? '').trim().isNotEmpty) {
                    await _submitCancel((comment ?? '').trim());
                  }
                },
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFDBB342), width: 2), foregroundColor: const Color(0xFFDBB342), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_isSubmitting ? 'Cancelling...' : 'Cancel'),
        ),
      ),
    ]);
  }

  Future<void> _submitUpdate() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) throw Exception('Missing auth or topic id');

      // Validate quantities before sending
      final details = <Map<String, dynamic>>[];
      for (var item in _requestItems) {
        final barcode = item['barcode'] ?? item['bar_code'] ?? '';
        final qty = (item['quantity'] is String) ? int.tryParse(item['quantity']) ?? 0 : (item['quantity'] ?? 0);
        if (barcode.isEmpty) {
          throw Exception('Barcode is required for all items');
        }
        if (qty <= 0) {
          throw Exception('Quantity must be greater than 0 for all items');
        }
        details.add({
          'barcode': barcode,
          'quantity': qty,
        });
      }

      if (details.isEmpty) {
        throw Exception('At least one item is required');
      }

      final body = {
        'title': _titleController.text.trim().isEmpty ? (_requestDetails['title'] ?? '') : _titleController.text.trim(),
        'details': details,
        'confirmed': 0,
      };

      debugPrint('🔍 [MyRequestDetail] Update body: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      debugPrint('🔍 [MyRequestDetail] Update response status: ${response.statusCode}');
      debugPrint('🔍 [MyRequestDetail] Update response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request updated successfully')));
        // Navigate back to refresh the list
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to update (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCancel(String comment) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      if (token == null || baseUrl == null) throw Exception('Missing auth');
      final topicUid = _requestDetails['topic_uniq_id'];
      if (topicUid == null) throw Exception('Missing topic id');
      final body = {'comment': comment};
      debugPrint('🔍 [MyRequestDetail] Cancel body: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request-cancel/$topicUid'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      debugPrint('🔍 [MyRequestDetail] Cancel response status: ${response.statusCode}');
      debugPrint('🔍 [MyRequestDetail] Cancel response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        // Navigate back to refresh the list
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to cancel (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildFeedbackSectionWidget(bool isDarkMode) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFeedbackList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const SizedBox.shrink();
      }
      
        final feedbackList = snapshot.data!;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with expand/collapse button
              InkWell(
                onTap: () {
                  setState(() {
                    _isFeedbackExpanded = !_isFeedbackExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comments & Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        _isFeedbackExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              // Feedback items (shown when expanded)
              if (_isFeedbackExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: feedbackList.map((feedback) {
                      final String comment = feedback['comment'] ?? '';
                      final String createdAt = feedback['created_at'] ?? '';
                      final String employeeName = feedback['employee_name'] ?? 'Unknown';
                      final String employeeSurname = feedback['employee_surname'] ?? '';
                      final String imgPath = feedback['img_path'] ?? '';
                      final String positionName = feedback['position_name'] ?? '';
                      
                      final String approverName = '$employeeName $employeeSurname'.trim();
                      final String approverImageUrl = _getImageUrl(imgPath);
                      // Check both img_path and img_name for requester image
                      final String requesterImgPath = _requestDetails['img_path'] ?? '';
                      final String requesterImgName = _requestDetails['img_name'] ?? '';
                      final String requesterImageUrl = _getImageUrl(requesterImgPath.isNotEmpty ? requesterImgPath : requesterImgName);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
        ),
        child: Column(
          children: [
            // Profile images with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                                // Requester image
                    Container(
                                  width: 40,
                                  height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: requesterImageUrl.isNotEmpty
                            ? Image.network(
                                requesterImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person,
                                  color: Colors.green,
                                              size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                            size: 20,
                              ),
                      ),
                    ),
                                const SizedBox(width: 12),
                // Arrow
                Container(
                                  width: 30,
                                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBB342),
                                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                                    size: 14,
                  ),
                ),
                                const SizedBox(width: 12),
                                // Approver image
                    Container(
                                  width: 40,
                                  height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: approverImageUrl.isNotEmpty
                            ? Image.network(
                                approverImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person,
                                  color: Colors.green,
                                              size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                            size: 20,
                              ),
                      ),
                    ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Employee name and position
                            Text(
                              approverName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (positionName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                    Text(
                                positionName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                            const SizedBox(height: 8),
            // Date and time
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            // Comment
            if (comment.isNotEmpty)
              Text(
                comment,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFeedbackList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) {
        return [];
      }
      
      debugPrint('🔍 [AdminHQ] Fetching feedback for topic: $topicUid');
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/request_reply/$topicUid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      debugPrint('🔍 [AdminHQ] Feedback response status: ${response.statusCode}');
      debugPrint('🔍 [AdminHQ] Feedback response body: ${response.body}');
      
      if (response.statusCode != 200) return [];
      
      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList = (decoded is List) ? decoded : (decoded['results'] ?? []);
      
      return feedbackList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('🔍 [AdminHQ] Feedback error: $e');
      return [];
    }
  }

  Color _getDecideColor(String decide) {
    switch (decide.toLowerCase()) {
      case 'checked':
      case 'approved':
        return Colors.green;
      case 'edit':
        return Colors.orange;
      case 'declined':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Color _statusColor(String s) {
    final statusLower = s.toLowerCase().trim();
    // Check for supervisor pending first
    if (statusLower.contains('supervisor pending')) {
      return Colors.orange; // Kuning/oren untuk Supervisor Pending
    }
    switch (statusLower) {
      case 'approved':
        return Colors.green;
      case 'decline':
      case 'declined':
      case 'rejected':
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      case 'received':
      case 'exported':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    // If already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    // Otherwise, prepend base URL
    return '$_imageBaseUrl$imagePath';
  }
  String _getItemImageUrl(String? imageRef) => (imageRef == null || imageRef.isEmpty) ? '' : (imageRef.startsWith('http') ? imageRef : '$_imageBaseUrl$imageRef');
  String _formatDate(String? dateString) { if (dateString == null) return 'Unknown date'; try { final d = DateTime.parse(dateString); return '${d.day.toString().padLeft(2,'0')} ${_month(d.month)} ${d.year} - ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}'; } catch (_) { return dateString; } }
  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}


