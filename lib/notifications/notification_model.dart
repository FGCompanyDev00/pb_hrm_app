class NotificationModel {
  final int id;
  final String employeeId;
  final String projectId;
  final String meetingId;
  final String asId;
  final String message;
  final int status;
  final String createdBy;
  final DateTime createdAt;
  final String imageUrl;

  NotificationModel({
    required this.id,
    required this.employeeId,
    required this.projectId,
    required this.meetingId,
    required this.asId,
    required this.message,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl = 'https://your-image-url.com',
  });

  // Factory constructor to create an instance of NotificationModel from JSON data
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      employeeId: json['employee_id'] ?? '',
      projectId: json['project_id'] ?? '',
      meetingId: json['meeting_id'] ?? '',
      asId: json['as_id'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 0,
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['imageUrl'] ?? 'https://your-image-url.com',
    );
  }
}
