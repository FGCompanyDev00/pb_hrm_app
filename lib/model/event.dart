class Event {
  final int id;
  final String requestorId;
  final String requestorName;
  final String imgPath;
  final int leaveTypeId;
  final String name;
  final String reason;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int days;
  final String status;
  final bool isMeeting;

  Event({
    required this.id,
    required this.requestorId,
    required this.requestorName,
    required this.imgPath,
    required this.leaveTypeId,
    required this.name,
    required this.reason,
    required this.startDateTime,
    required this.endDateTime,
    required this.days,
    required this.status,
    this.isMeeting = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['take_leave_request_id'],
      requestorId: json['requestor_id'],
      requestorName: json['requestor_name'],
      imgPath: json['img_path'],
      leaveTypeId: json['leave_type_id'],
      name: json['name'],
      reason: json['take_leave_reason'],
      startDateTime: DateTime.parse(json['take_leave_from']),
      endDateTime: DateTime.parse(json['take_leave_to']),
      days: json['days'],
      status: json['is_approve'],
    );
  }
}
