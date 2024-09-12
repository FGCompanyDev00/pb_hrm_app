// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
// import 'package:saver_gallery/saver_gallery.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:http/http.dart' as http;
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pb_hrsystem/home/myprofile_page.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   _ProfileScreenState createState() => _ProfileScreenState();
// }

// class DashedLine extends StatelessWidget {
//   final double dashWidth;
//   final double dashHeight;
//   final Color color;

//   const DashedLine({
//     super.key,
//     this.dashWidth = 10.0,
//     this.dashHeight = 4.0,
//     this.color = Colors.yellow,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final boxWidth = constraints.constrainWidth();
//         final dashCount = (boxWidth / (2 * dashWidth)).floor();
//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: List.generate(dashCount, (_) {
//             return SizedBox(
//               width: dashWidth,
//               height: dashHeight,
//               child: DecoratedBox(
//                 decoration: BoxDecoration(color: color),
//               ),
//             );
//           }),
//         );
//       },
//     );
//   }
// }

// class TicketShapeClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     final Path path = Path();

//     path.moveTo(0, 20);

//     path.arcToPoint(
//       const Offset(20, 0),
//       radius: const Radius.circular(20),
//       clockwise: false,
//     );

//     path.lineTo(size.width - 20, 0);
//     path.arcToPoint(
//       Offset(size.width, 20),
//       radius: const Radius.circular(20),
//       clockwise: false,
//     );

//     path.lineTo(size.width, size.height * 0.4);
//     path.arcToPoint(
//       Offset(size.width, size.height * 0.6),
//       radius: const Radius.circular(15),
//       clockwise: false,
//     );

//     // Bottom-right curve
//     path.lineTo(size.width, size.height - 20);
//     path.arcToPoint(
//       Offset(size.width - 20, size.height),
//       radius: const Radius.circular(20),
//       clockwise: false,
//     );

//     path.lineTo(20, size.height);
//     path.arcToPoint(
//       Offset(0, size.height - 20),
//       radius: const Radius.circular(20),
//       clockwise: false,
//     );

//     path.lineTo(0, size.height * 0.6);
//     path.arcToPoint(
//       Offset(0, size.height * 0.4),
//       radius: const Radius.circular(15),
//       clockwise: false,
//     );

//     path.lineTo(0, 20);

//     return path;
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   late Future<Map<String, dynamic>> _profileData;
//   late Future<Map<String, dynamic>> _displayData;

//   final GlobalKey qrKey = GlobalKey();
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

//   @override
//   void initState() {
//     super.initState();
//     _profileData = _fetchProfileData();
//     _displayData = _fetchDisplayData();
//   }

//   Future<Map<String, dynamic>> _fetchProfileData() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? token = prefs.getString('token');

//       if (token == null || token.isEmpty) {
//         throw Exception('No token found. Please log in again.');
//       }

//       final response = await http.get(
//         Uri.parse('https://demo-application-api.flexiflows.co/api/profile/'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final responseBody = jsonDecode(response.body);
//         if (responseBody.containsKey('results') &&
//             responseBody['results'] is Map<String, dynamic>) {
//           return responseBody['results'];
//         } else {
//           throw Exception('Invalid response structure');
//         }
//       } else {
//         debugPrint(
//             'Failed to load profile data - Status Code: ${response.statusCode}');
//         debugPrint('Response Body: ${response.body}');
//         throw Exception('Failed to load profile data');
//       }
//     } catch (e) {
//       debugPrint('Error in _fetchProfileData: $e');
//       throw Exception('Failed to load profile data');
//     }
//   }


//   Future<Map<String, dynamic>> _fetchDisplayData() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? token = prefs.getString('token');

//       if (token == null || token.isEmpty) {
//         throw Exception('No token found. Please log in again.');
//       }

//       final response = await http.get(
//         Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final responseBody = jsonDecode(response.body);
//         if (responseBody.containsKey('results') &&
//             responseBody['results'] is List<dynamic> &&
//             responseBody['results'].isNotEmpty) {
//           return responseBody['results'][0];
//         } else {
//           throw Exception('Invalid response structure');
//         }
//       } else {
//         debugPrint(
//             'Failed to load display data - Status Code: ${response.statusCode}');
//         debugPrint('Response Body: ${response.body}');
//         throw Exception('Failed to load display data');
//       }
//     } catch (e) {
//       debugPrint('Error in _fetchDisplayData: $e');
//       throw Exception('Failed to load display data');
//     }
//   }

//   Future<void> _shareQRCode() async {
//     try {
//       final RenderRepaintBoundary boundary =
//       qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//       final image = await boundary.toImage(pixelRatio: 4.0);
//       final byteData = await image.toByteData(format: ImageByteFormat.png);
//       final uint8List = byteData!.buffer.asUint8List();

//       final tempDir = await getTemporaryDirectory();
//       final file = await File('${tempDir.path}/qr_code.png').create();
//       await file.writeAsBytes(uint8List);

//       await Share.shareXFiles([XFile(file.path)], text: 'Check out my QR code!');
//     } catch (e) {
//       debugPrint('Error sharing QR code: $e');
//       Fluttertoast.showToast(
//         msg: "Error sharing QR code",
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//       );
//     }
//   }

//   Future<void> _downloadQRCode() async {
//     try {
//       // Ensure the QR code widget is rendered
//       final RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

//       if (boundary == null) {
//         Fluttertoast.showToast(
//           msg: "QR Code is not rendered yet. Please wait and try again.",
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.BOTTOM,
//         );
//         return;
//       }

//       // Convert widget to image with a memory-efficient pixel ratio
//       final image = await boundary.toImage(pixelRatio: 2.0);  // Lowered pixelRatio for better memory handling
//       final byteData = await image.toByteData(format: ImageByteFormat.png);
//       final uint8List = byteData!.buffer.asUint8List();

//       // Get temporary directory for saving the image
//       final tempDir = await getTemporaryDirectory();
//       final file = await File('${tempDir.path}/qr_code.png').create();
//       await file.writeAsBytes(uint8List);

//       // Save image using the gallery saver and handle the result
//       final result = await SaverGallery.saveImage(
//         uint8List,
//         quality: 100,  // Set quality lower for better performance
//         name: "qr_code.png",
//         androidExistNotSave: false,
//       );

//       // Check the result and show appropriate message
//       if (result.isSuccess) {
//         Fluttertoast.showToast(
//           msg: "QR Code downloaded successfully",
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.BOTTOM,
//         );
//       } else {
//         Fluttertoast.showToast(
//           msg: "Error downloading QR code. Please try again.",
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.BOTTOM,
//         );
//       }
//     } catch (e) {
//       // Handle any other errors during the process
//       Fluttertoast.showToast(
//         msg: "Error downloading QR code: ${e.toString()}",
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//       );
//       debugPrint('Error downloading QR code: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Provider.of<ThemeNotifier>(context);

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             image: DecorationImage(
//               image: AssetImage('assets/background.png'),
//               fit: BoxFit.cover,
//             ),
//             borderRadius: BorderRadius.only(
//               bottomLeft: Radius.circular(30),
//               bottomRight: Radius.circular(30),
//             ),
//           ),
//         ),
//         centerTitle: true,
//         title: const Text(
//           'QR My Profile',
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 24,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new,
//             color: Colors.black,
//             size: 20,
//           ),
//           onPressed: () {
//             Navigator.pushAndRemoveUntil(
//               context,
//               MaterialPageRoute(builder: (context) => const Dashboard()),
//                   (Route<dynamic> route) => false,
//             );
//           },
//         ),
//         toolbarHeight: 70,
//       ),

//       body: Padding(
//         padding: const EdgeInsets.only(top: kToolbarHeight + 50.0),
//         child: FutureBuilder<Map<String, dynamic>>(
//           future: Future.wait([_profileData, _displayData])
//               .then((results) => {...results[0], ...results[1]}),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             } else if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             } else if (snapshot.hasData) {
//               final data = snapshot.data!;

//               final String vCardData = '''
// BEGIN:VCARD
// VERSION:3.0
// N:${data['employee_surname'] ?? ''};${data['employee_name'] ?? ''};;;
// FN:${data['employee_name'] ?? ''} ${data['employee_surname'] ?? ''}
// EMAIL:${data['employee_email'] ?? ''}
// TEL:${data['employee_tel'] ?? ''}
// PHOTO;TYPE=JPEG;VALUE=URI:${data['images'] ?? ''}
// END:VCARD
// ''';

//               debugPrint(vCardData);

//               return Stack(
//                 children: [

//                   Center(
//                     child: SingleChildScrollView(
//                       child: Padding(
//                         padding: const EdgeInsets.all(25.0),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Stack(
//                               children: [
//                                 Center(
//                                   child: CircleAvatar(
//                                     radius: 60,
//                                     backgroundColor: Colors.grey[200],
//                                     child: CircleAvatar(
//                                       radius: 50,
//                                       backgroundImage: NetworkImage(data['images']),
//                                     ),
//                                   ),
//                                 ),
//                                 Positioned(
//                                   right: 0,
//                                   top: 0,
//                                   bottom: 0,
//                                   child: GestureDetector(
//                                     onTap: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                           builder: (context) =>
//                                           const MyProfilePage(),
//                                         ),
//                                       );
//                                     },
//                                     child: const Icon(
//                                       Icons.arrow_forward_ios,
//                                       size: 28,
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 10),
//                             Text(
//                               'Hi, ${data['employee_name']}',
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.black54, // Subtle text color
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//                             ClipPath(
//                               clipper: TicketShapeClipper(),
//                               child: Container(
//                                 padding: const EdgeInsets.all(16),
//                                 decoration: BoxDecoration(
//                                   color: Colors.lightGreenAccent[100],
//                                   boxShadow: const [
//                                     BoxShadow(
//                                       color: Colors.black26,
//                                       blurRadius: 8,
//                                       offset: Offset(0, 4),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Column(
//                                   children: [
//                                     const Text(
//                                       'Scan for Save Contact',
//                                       style: TextStyle(
//                                         fontSize: 21,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.black,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 15),
//                                     const DashedLine(
//                                       dashWidth: 12,
//                                       dashHeight: 8,
//                                       color: Colors.yellow,
//                                     ),
//                                     const SizedBox(height: 18),
//                                 RepaintBoundary(
//                                   key: qrKey,
//                                   child: QrImageView(
//                                     data: vCardData,
//                                     version: QrVersions.auto,
//                                     size: 250.0,
//                                     gapless: false,
//                                     embeddedImage: const AssetImage('assets/playstore.png'),
//                                     embeddedImageStyle: const QrEmbeddedImageStyle(
//                                       size: Size(40, 40),
//                                     ),
//                                     backgroundColor: Colors.white,
//                                     eyeStyle: const QrEyeStyle(
//                                       eyeShape: QrEyeShape.circle,
//                                       color: Colors.black,
//                                     ),
//                                     dataModuleStyle: const QrDataModuleStyle(
//                                       dataModuleShape: QrDataModuleShape.square,
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                 ),
//                                     const SizedBox(height: 20),],
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceAround,
//                               children: [
//                                 ElevatedButton.icon(
//                                   onPressed: _shareQRCode,
//                                   icon: const Icon(Icons.share, color: Colors.white),
//                                   label: const Text('Share', style: TextStyle(color: Colors.white)),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.grey[700],
//                                     padding: const EdgeInsets.symmetric(horizontal: 39, vertical: 19),
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                   ),
//                                 ),
//                                 ElevatedButton.icon(
//                                   onPressed: _downloadQRCode,
//                                   icon: const Icon(Icons.download, color: Colors.white),
//                                   label: const Text('Download', style: TextStyle(color: Colors.white)),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.amber[700],
//                                     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             } else {
//               return const Center(child: Text('No data available'));
//             }
//           },
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/myprofile_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class DashedLine extends StatelessWidget {
  final double dashWidth;
  final double dashHeight;
  final Color color;

  const DashedLine({
    super.key,
    this.dashWidth = 10.0,
    this.dashHeight = 4.0,
    this.color = Colors.yellow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class TicketShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();

    path.moveTo(0, 20);

    path.arcToPoint(
      const Offset(20, 0),
      radius: const Radius.circular(20),
      clockwise: false,
    );

    path.lineTo(size.width - 20, 0);
    path.arcToPoint(
      Offset(size.width, 20),
      radius: const Radius.circular(20),
      clockwise: false,
    );

    path.lineTo(size.width, size.height * 0.4);
    path.arcToPoint(
      Offset(size.width, size.height * 0.6),
      radius: const Radius.circular(15),
      clockwise: false,
    );

    // Bottom-right curve
    path.lineTo(size.width, size.height - 20);
    path.arcToPoint(
      Offset(size.width - 20, size.height),
      radius: const Radius.circular(20),
      clockwise: false,
    );

    path.lineTo(20, size.height);
    path.arcToPoint(
      Offset(0, size.height - 20),
      radius: const Radius.circular(20),
      clockwise: false,
    );

    path.lineTo(0, size.height * 0.6);
    path.arcToPoint(
      Offset(0, size.height * 0.4),
      radius: const Radius.circular(15),
      clockwise: false,
    );

    path.lineTo(0, 20);

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileData;
  late Future<Map<String, dynamic>> _displayData;

  final GlobalKey qrKey = GlobalKey();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _profileData = _fetchProfileData();
    _displayData = _fetchDisplayData();
  }

  Future<Map<String, dynamic>> _fetchProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('No token found. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('results') &&
            responseBody['results'] is Map<String, dynamic>) {
          return responseBody['results'];
        } else {
          throw Exception('Invalid response structure');
        }
      } else {
        debugPrint(
            'Failed to load profile data - Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception('Failed to load profile data');
      }
    } catch (e) {
      debugPrint('Error in _fetchProfileData: $e');
      throw Exception('Failed to load profile data');
    }
  }


  Future<Map<String, dynamic>> _fetchDisplayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('No token found. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('results') &&
            responseBody['results'] is List<dynamic> &&
            responseBody['results'].isNotEmpty) {
          return responseBody['results'][0];
        } else {
          throw Exception('Invalid response structure');
        }
      } else {
        debugPrint(
            'Failed to load display data - Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception('Failed to load display data');
      }
    } catch (e) {
      debugPrint('Error in _fetchDisplayData: $e');
      throw Exception('Failed to load display data');
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final RenderRepaintBoundary boundary =
      qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(uint8List);

      await Share.shareXFiles([XFile(file.path)], text: 'Check out my QR code!');
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      Fluttertoast.showToast(
        msg: "Error sharing QR code",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      // Ensure the QR code widget is rendered
      final RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        Fluttertoast.showToast(
          msg: "QR Code is not rendered yet. Please wait and try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Convert widget to image with a memory-efficient pixel ratio
      final image = await boundary.toImage(pixelRatio: 2.0);  // Lowered pixelRatio for better memory handling
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      // Get temporary directory for saving the image
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(uint8List);

      // Save image using the gallery saver and handle the result
      final result = await SaverGallery.saveImage(
        uint8List,
        quality: 100,  // Set quality lower for better performance
        name: "qr_code.png",
        androidExistNotSave: false,
      );

      // Check the result and show appropriate message
      if (result.isSuccess) {
        Fluttertoast.showToast(
          msg: "QR Code downloaded successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Error downloading QR code. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      // Handle any other errors during the process
      Fluttertoast.showToast(
        msg: "Error downloading QR code: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      debugPrint('Error downloading QR code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeNotifier>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'QR My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const Dashboard()),
                  (Route<dynamic> route) => false,
            );
          },
        ),
        toolbarHeight: 70,
      ),

      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight + 50.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: Future.wait([_profileData, _displayData])
              .then((results) => {...results[0], ...results[1]}),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final data = snapshot.data!;

              final String vCardData = '''
BEGIN:VCARD
VERSION:3.0
N:${data['employee_surname'] ?? ''};${data['employee_name'] ?? ''};;;
FN:${data['employee_name'] ?? ''} ${data['employee_surname'] ?? ''}
EMAIL:${data['employee_email'] ?? ''}
TEL:${data['employee_tel'] ?? ''}
PHOTO;TYPE=JPEG;VALUE=URI:${data['images'] ?? ''}
END:VCARD
''';

              debugPrint(vCardData);

              return Stack(
                children: [

                  Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Center(
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[200],
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(data['images']),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                          const MyProfilePage(),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      children: [
                                        Text(
                                          "More",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 24,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Hi, ${data['employee_name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54, // Subtle text color
                              ),
                            ),
                            const SizedBox(height: 16),
                            ClipPath(
                              clipper: TicketShapeClipper(),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.lightGreenAccent[100],
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Scan for Save Contact',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    const DashedLine(
                                      dashWidth: 12,
                                      dashHeight: 8,
                                      color: Colors.yellow,
                                    ),
                                    const SizedBox(height: 18),
                                RepaintBoundary(
                                  key: qrKey,
                                  child: QrImageView(
                                    data: vCardData,
                                    version: QrVersions.auto,
                                    size: 250.0,
                                    gapless: false,
                                    embeddedImage: const AssetImage('assets/playstore.png'),
                                    embeddedImageStyle: const QrEmbeddedImageStyle(
                                      size: Size(40, 40),
                                    ),
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.circle,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                    const SizedBox(height: 20),],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _shareQRCode,
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  label: const Text('Share', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 39, vertical: 19),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _downloadQRCode,
                                  icon: const Icon(Icons.download, color: Colors.white),
                                  label: const Text('Download', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(child: Text('No data available'));
            }
          },
        ),
      ),
    );
  }
}
