import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'aws_config.dart';

class SNSService {
  final String _accessKeyId = AWSConfig.accessKeyId;
  final String _secretAccessKey = AWSConfig.secretAccessKey;
  final String _region = AWSConfig.region;
  final String _platformEndpointArn = AWSConfig.platformEndpointArn;
  final String _snsTopicArn = AWSConfig.snsTopicArn;

  Future<void> sendNotification(String message, String subject) async {
    final endpoint = 'https://sns.$_region.amazonaws.com/';

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final body = {
      'Action': 'Publish',
      'TopicArn': _snsTopicArn,
      'Message': message,
      'Subject': subject,
      'AWSAccessKeyId': _accessKeyId,
      'AWSSecretAccessKey': _secretAccessKey,
      'SignatureVersion': '2',
      'Version': '2010-03-31',
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully');
      } else {
        debugPrint('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}
