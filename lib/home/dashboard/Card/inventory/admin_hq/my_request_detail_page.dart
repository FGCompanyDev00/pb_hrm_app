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
          _isLoading = false;
        });
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
                          _buildItems(isDarkMode),
                          const SizedBox(height: 16),
                          if (_isFinalStatus)
                            FutureBuilder<Widget>(
                              future: _buildFeedbackSection(isDarkMode),
                              builder: (context, snap) => snap.data ?? const SizedBox.shrink(),
                            )
                          else
                            _buildUpdateCancelRow(isDarkMode),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    final imageUrl = _getImageUrl(_requestDetails['img_path']);
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
      child: Row(children: [
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
        _isFinalStatus
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDBB342).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(qty.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDBB342))),
              )
            : Row(children: [
                IconButton(onPressed: () => _decrementQuantity(index), icon: const Icon(Icons.remove_circle_outline), color: isDarkMode ? Colors.white70 : Colors.black54),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDBB342).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(qty.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDBB342)))),
                IconButton(onPressed: () => _incrementQuantity(index), icon: const Icon(Icons.add_circle_outline), color: isDarkMode ? Colors.white70 : Colors.black54),
                IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.delete_outline), color: Colors.red[400]),
              ]),
      ]),
    );
  }

  bool get _isFinalStatus {
    final s = (_requestDetails['status'] ?? '').toString().toLowerCase();
    return s.contains('approved') || s.contains('decline') || s.contains('declined') || s.contains('rejected') || s.contains('received') || s.contains('exported');
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

      final body = {
        'title': _requestDetails['title'] ?? '',
        'details': _requestItems.map((e) => {
              'barcode': e['barcode'] ?? e['bar_code'] ?? '',
              'quantity': (e['quantity'] is String) ? int.tryParse(e['quantity']) ?? 0 : (e['quantity'] ?? 0),
            }).toList(),
        'confirmed': 0,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request_topic/$topicUid'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request updated successfully')));
        await _loadRequestDetails();
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
      final response = await http.put(
        Uri.parse('$baseUrl/api/inventory/request-cancel/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'comment': comment}),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        Navigator.pop(context);
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

  Future<Widget> _buildFeedbackSection(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseUrl = dotenv.env['BASE_URL'];
      final topicUid = _requestDetails['topic_uniq_id'];
      if (token == null || baseUrl == null || topicUid == null) {
        return const SizedBox.shrink();
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
      
      if (response.statusCode != 200) return const SizedBox.shrink();
      
      final decoded = jsonDecode(response.body);
      final List<dynamic> feedbackList = (decoded is List) ? decoded : (decoded['results'] ?? []);
      
      if (feedbackList.isEmpty) return const SizedBox.shrink();

      // Get the latest feedback (first item in the list)
      final feedback = feedbackList.first;
      final String comment = feedback['comment'] ?? '';
      final String decide = feedback['decide'] ?? '';
      final String createdAt = feedback['created_at'] ?? '';
      final String employeeName = feedback['employee_name'] ?? 'Unknown';
      final String employeeSurname = feedback['employee_surname'] ?? '';
      final String imgPath = feedback['img_path'] ?? '';
      final String positionName = feedback['position_name'] ?? '';
      
      final String approverName = '$employeeName $employeeSurname'.trim();
      final String approverImageUrl = _getImageUrl(imgPath);
      final String requesterImageUrl = _getImageUrl(_requestDetails['img_path']);

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
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
          children: [
            // Profile images with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Requester image with position
                Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
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
                                  size: 25,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 25,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requester',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Arrow
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBB342),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 16),
                // Approver image with position
                Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
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
                                  size: 25,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 25,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      positionName.isNotEmpty ? positionName : 'Approver',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date and time
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                fontSize: 14,
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
    } catch (e) {
      debugPrint('🔍 [AdminHQ] Feedback error: $e');
      return const SizedBox.shrink();
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
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'decline':
      case 'declined':
      case 'rejected':
        return Colors.red;
      case 'received':
      case 'exported':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _getImageUrl(String? imagePath) => (imagePath == null || imagePath.isEmpty) ? '' : (imagePath.startsWith('http') ? imagePath : '$_imageBaseUrl$imagePath');
  String _getItemImageUrl(String? imageRef) => (imageRef == null || imageRef.isEmpty) ? '' : (imageRef.startsWith('http') ? imageRef : '$_imageBaseUrl$imageRef');
  String _formatDate(String? dateString) { if (dateString == null) return 'Unknown date'; try { final d = DateTime.parse(dateString); return '${d.day.toString().padLeft(2,'0')} ${_month(d.month)} ${d.year} - ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}'; } catch (_) { return dateString; } }
  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}


