class NotificationModel {
  final int id;
  final String type;
  final String requestor;
  final String date;
  final String time;
  final String status;
  final String imageUrl;

  NotificationModel({
    required this.id,
    required this.type,
    required this.requestor,
    required this.date,
    required this.time,
    required this.status,
    required this.imageUrl,
  });

  // Factory constructor to create an instance of NotificationModel from JSON data
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: json['message'],
      requestor: json['created_by'],
      date: json['created_at'].substring(0, 10),
      time: json['created_at'].substring(11, 16),
      status: json['status'] == 0 ? 'Pending' : 'Read',
      imageUrl: json['images'] ?? 'https://default-image-url.com', // Fallback to a default image URL if not provided
    );
  }
}