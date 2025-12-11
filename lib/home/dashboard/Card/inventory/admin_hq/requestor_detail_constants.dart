/// Constants for Requestor Detail Page
class RequestorDetailConstants {
  // Image base URL
  static const String imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  // Request sources
  static const String sourceApproval = 'approval';
  static const String sourceMyRequest = 'my_request';
  static const String sourceMyReceive = 'my_receive';

  // Status values (normalized)
  static const String statusSupervisorPending = 'supervisor pending';
  static const String statusApproved = 'approved';
  static const String statusReceived = 'received';
  static const String statusDeclined = 'declined';
  static const String statusRejected = 'rejected';
  static const String statusCancelled = 'cancelled';
  static const String statusExported = 'exported';
  static const String statusPending = 'pending';

  // HTTP timeout configuration
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // API endpoints
  static const String endpointRequestTopic = '/api/inventory/request_topic';
  static const String endpointMyRequestTopicDetail = '/api/inventory/my-request-topic-detail';
  static const String endpointWaiting = '/api/inventory/waiting';
  static const String endpointReceived = '/api/inventory/received';
  static const String endpointRequestWaiting = '/api/inventory/request-waiting';
  static const String endpointDecline = '/api/inventory/decline';
  static const String endpointRequestCancel = '/api/inventory/request-cancel';
  static const String endpointRequestReply = '/api/inventory/request_reply';

  // Status normalization helper
  static String normalizeStatus(String status) {
    return status.toLowerCase().trim().replaceAll(RegExp(r'[.\s]+'), ' ');
  }

  // Check if status is final (cannot be edited)
  static bool isFinalStatus(String status) {
    final normalized = normalizeStatus(status);
    if (normalized.contains(statusSupervisorPending)) {
      return false;
    }
    return normalized.contains(statusApproved) ||
        normalized.contains('decline') ||
        normalized.contains(statusDeclined) ||
        normalized.contains(statusRejected) ||
        normalized.contains(statusReceived) ||
        normalized.contains(statusExported) ||
        normalized.contains('cancel');
  }

  // Check if items can be edited
  static bool canEditItems(String status) {
    final normalized = normalizeStatus(status);
    return normalized.contains(statusSupervisorPending);
  }
}
