// qr_profile_page.dart

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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  // Define two separate GlobalKeys
  final GlobalKey qrKey = GlobalKey();
  final GlobalKey qrFullScreenKey = GlobalKey();

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _isQRCodeFullScreen = false;

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
        throw Exception(AppLocalizations.of(context)!.noTokenFound);
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
          throw Exception(AppLocalizations.of(context)!.invalidResponseStructure);
        }
      } else {
        debugPrint(
            'Failed to load profile data - Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception(AppLocalizations.of(context)!.failedToLoadProfileData);
      }
    } catch (e) {
      debugPrint('Error in _fetchProfileData: $e');
      throw Exception(AppLocalizations.of(context)!.failedToLoadProfileData);
    }
  }

  Future<Map<String, dynamic>> _fetchDisplayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.noTokenFound);
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
          throw Exception(AppLocalizations.of(context)!.invalidResponseStructure);
        }
      } else {
        debugPrint(
            'Failed to load display data - Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception(AppLocalizations.of(context)!.failedToLoadDisplayData);
      }
    } catch (e) {
      debugPrint('Error in _fetchDisplayData: $e');
      throw Exception(AppLocalizations.of(context)!.failedToLoadDisplayData);
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

      await Share.shareXFiles([XFile(file.path)], text: AppLocalizations.of(context)!.shareQRCodeText);
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.errorSharingQRCode,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      // Access the embedded QR code RepaintBoundary using qrKey
      final RenderRepaintBoundary? boundary =
      qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.qrCodeNotRendered,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(uint8List);

      final result = await SaverGallery.saveImage(
        uint8List,
        quality: 100,
        name: "qr_code.png",
        androidExistNotSave: false,
      );

      if (result.isSuccess) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.qrCodeDownloadedSuccess,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.errorDownloadingQRCodeGeneral,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.errorDownloadingQRCode(e.toString()),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      debugPrint('Error downloading QR code: $e');
    }
  }

  Future<void> _saveQRCodeToGallery() async {
    try {
      final RenderRepaintBoundary? boundary =
      qrFullScreenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.qrCodeNotRendered,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();

      final result = await SaverGallery.saveImage(
        uint8List,
        quality: 100,
        name: "qr_code.png",
        androidExistNotSave: false,
      );

      if (result.isSuccess) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.qrCodeSavedToGallery,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.errorSavingQRCodeGeneral,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.errorSavingQRCode(e.toString()),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      debugPrint('Error saving QR code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeNotifier>(context);
    final size = MediaQuery.of(context).size;

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
        title: Text(
          AppLocalizations.of(context)!.qrMyProfile,
          style: const TextStyle(
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
        backgroundColor: Colors.transparent, // Ensure transparent background
        elevation: 0, // Remove shadow
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
              return Center(child: Text(AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString())));
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

              return Stack(children: [
                if (_isQRCodeFullScreen)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isQRCodeFullScreen = false;
                      });
                    },
                    onLongPress: () async {
                      final shouldSave = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.saveImageTitle),
                          content: Text(AppLocalizations.of(context)!.saveImageConfirmation),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              child: Text(AppLocalizations.of(context)!.save),
                            ),
                          ],
                        ),
                      );
                      if (shouldSave ?? false) {
                        _saveQRCodeToGallery();
                      }
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.9),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: qrFullScreenKey, // Use separate key
                            child: QrImageView(
                              data: vCardData,
                              version: QrVersions.auto,
                              size: size.width * 0.8,
                              gapless: false,
                              embeddedImage:
                              const AssetImage('assets/playstore.png'),
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
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints:
                          BoxConstraints(maxHeight: size.height * 0.8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: size.width * 0.10,
                                      backgroundColor: Colors.grey[200],
                                      child: CircleAvatar(
                                        radius: size.width * 0.09,
                                        backgroundImage:
                                        NetworkImage(data['images']),
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
                                      child: Row(
                                        children: [
                                          Text(
                                            AppLocalizations.of(context)!.more,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const Icon(
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
                                AppLocalizations.of(context)!.greeting(data['employee_name']),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  Colors.black54, // Subtle text color
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
                                      Text(
                                        AppLocalizations.of(context)!.scanToSaveContact,
                                        style: const TextStyle(
                                          fontSize: 15,
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
                                      Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                              Colors.black.withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isQRCodeFullScreen = true;
                                            });
                                          },
                                          child: RepaintBoundary(
                                            key: qrKey, // Assign to embedded QR code
                                            child: QrImageView(
                                              data: vCardData,
                                              version: QrVersions.auto,
                                              size: size.width * 0.45,
                                              gapless: false,
                                              embeddedImage: const AssetImage(
                                                  'assets/playstore.png'),
                                              embeddedImageStyle:
                                              const QrEmbeddedImageStyle(
                                                size: Size(40, 40),
                                              ),
                                              backgroundColor: Colors.white,
                                              eyeStyle: const QrEyeStyle(
                                                eyeShape: QrEyeShape.circle,
                                                color: Colors.black,
                                              ),
                                              dataModuleStyle:
                                              const QrDataModuleStyle(
                                                dataModuleShape:
                                                QrDataModuleShape.square,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Share Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _shareQRCode,
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: Text(AppLocalizations.of(context)!.share),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[700],
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Download Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _downloadQRCode,
                                      icon: const Icon(
                                        Icons.download_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: Text(AppLocalizations.of(context)!.download),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber[700],
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
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
                  )
              ]);
            } else {
              return Center(
                  child: Text(AppLocalizations.of(context)!.noDataAvailable));
            }
          },
        ),
      ),
    );
  }
}

class UserProfile {
  final String id;
  final String employeeId;
  final String name;
  final String surname;
  final String images;
  final String employee_tel;
  final String employee_email;
  String gender; // Assuming this is part of the profile
  String roles;

  UserProfile({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.surname,
    required this.images,
    required this.employee_tel,
    required this.employee_email,
    this.gender = 'N/A',
    this.roles = 'No roles available',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? 'N/A',
      name: json['employee_name'] ?? 'N/A',
      surname: json['employee_surname'] ?? 'N/A',
      images: json['images'] ?? 'default_avatar.jpg',
      employee_tel: json['employee_tel'] ?? 'N/A',
      employee_email: json['employee_email'] ?? 'N/A',
      gender: json['gender'] ?? 'N/A',
      roles: json['roles'] ?? 'No roles available',
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
