// qr_profile_page.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/models/qr_profile_page.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/myprofile_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/offline_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class DashedLine extends StatelessWidget {
  final double dashWidth;
  final double dashHeight;
  final Color color;

  const DashedLine({
    super.key,
    required this.dashWidth,
    required this.dashHeight,
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

    final double cornerRadius = size.height * 0.05;
    final double notchRadius = size.height * 0.015;

    path.moveTo(0, cornerRadius);

    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    path.lineTo(size.width, size.height * 0.4 - notchRadius);
    path.arcToPoint(
      Offset(size.width, size.height * 0.4 + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: true,
    );

    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    path.lineTo(0, size.height * 0.4 + notchRadius);
    path.arcToPoint(
      Offset(0, size.height * 0.4 - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: true,
    );

    path.lineTo(0, cornerRadius);

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileData;
  late Future<Map<String, dynamic>> _displayData;
  late OfflineProvider offlineProvider;
  final GlobalKey qrKey = GlobalKey();
  final GlobalKey qrFullScreenKey = GlobalKey();

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _isQRCodeFullScreen = false;

  @override
  void initState() {
    super.initState();
    offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
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
        Uri.parse('$baseUrl/api/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('results') && responseBody['results'] is Map<String, dynamic>) {
          return responseBody['results'];
        } else {
          throw Exception(AppLocalizations.of(context)!.invalidResponseStructure);
        }
      } else {
        debugPrint('Failed to load profile data - Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception(AppLocalizations.of(context)!.failedToLoadProfileData);
      }
    } catch (e) {
      debugPrint('Error in _fetchProfileData: $e');
      throw Exception(AppLocalizations.of(context)!.failedToLoadProfileData);
    }
  }

  Future<Map<String, dynamic>> _fetchDisplayData() async {
    if (offlineProvider.isOfflineService.value) {
      final offlineProfile = offlineProvider.getProfile();
      if (offlineProfile != null) {
        return offlineProfile.toMap();
      } else {
        throw Exception(AppLocalizations.of(context)!.failedToLoadDisplayData);
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('token');

        if (token == null || token.isEmpty) {
          throw Exception(AppLocalizations.of(context)!.noTokenFound);
        }

        final response = await http.get(
          Uri.parse('$baseUrl/api/display/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final responseBody = jsonDecode(response.body);
          if (responseBody.containsKey('results') && responseBody['results'] is List<dynamic> && responseBody['results'].isNotEmpty) {
            final record = UserProfileRecord.fromJson(responseBody['results'][0]);

            if (offlineProvider.isExistedProfile()) {
              await offlineProvider.updateProfile(record);
            } else {
              await offlineProvider.addProfile(record);
            }

            return responseBody['results'][0];
          } else {
            throw Exception(AppLocalizations.of(context)!.invalidResponseStructure);
          }
        } else {
          debugPrint('Failed to load display data - Status Code: ${response.statusCode}');
          debugPrint('Response Body: ${response.body}');
          throw Exception(AppLocalizations.of(context)!.failedToLoadDisplayData);
        }
      } catch (e) {
        debugPrint('Error in _fetchDisplayData: $e');
        throw Exception(AppLocalizations.of(context)!.failedToLoadDisplayData);
      }
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.qrCodeNotRendered,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

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
      final RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

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
        fileName: "qr_code.png",
        skipIfExists: false,
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
      final RenderRepaintBoundary? boundary = qrFullScreenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

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
        fileName: "qr_code.png",
        skipIfExists: false,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.qrMyProfile,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 90,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight + 50.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: Future.wait([_profileData, _displayData]).then((results) => {...results[0], ...results[1]}),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasData) {
              Map<String, dynamic> data = {};
              String vCardData = '';
              if (offlineProvider.isOfflineService.value) {
                if (offlineProvider.isExistedQR()) {
                  vCardData = offlineProvider.getQR();
                }
              } else {
                data = snapshot.data!;
                vCardData = '''
BEGIN:VCARD
VERSION:3.0
N:${data['employee_surname'] ?? ''};${data['employee_name'] ?? ''};;;
FN:${data['employee_name'] ?? ''} ${data['employee_surname'] ?? ''}
EMAIL:${data['employee_email'] ?? ''}
TEL:${data['employee_tel'] ?? ''}
${data['images'] != null && data['images'].isNotEmpty ? 'PHOTO;TYPE=JPEG;VALUE=URI:${data['images']}' : ''}
END:VCARD
''';
                if (offlineProvider.isExistedQR()) {
                  offlineProvider.updateQR(QRRecord(data: vCardData));
                } else {
                  offlineProvider.addQR(QRRecord(data: vCardData));
                }
                debugPrint(vCardData);
              }

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
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 10.0,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: qrFullScreenKey,
                            child: QrImageView(
                              data: vCardData,
                              version: QrVersions.auto,
                              size: size.width * 0.8,
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
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: size.height * 0.8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: size.width * 0.12,
                                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                      child: CircleAvatar(
                                          radius: size.width * 0.1,
                                          backgroundImage: data['images'] != null && data['images'].isNotEmpty ? NetworkImage(data['images']) : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                          onBackgroundImageError: (_, __) {
                                            const AssetImage('assets/default_avatar.png');
                                          }),
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
                                            builder: (context) => const MyProfilePage(),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 24,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            AppLocalizations.of(context)!.more,
                                            style: TextStyle(
                                              fontSize: size.width * 0.04,
                                              fontWeight: FontWeight.w500,
                                              color: isDarkMode ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                AppLocalizations.of(context)!.greeting(data['employee_name']),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.green : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              ClipPath(
                                clipper: TicketShapeClipper(),
                                child: Container(
                                  padding: EdgeInsets.all(size.width * 0.04),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF303030) : const Color(0xFFEAF9E5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.scanToSaveContact,
                                        style: TextStyle(
                                          fontSize: size.width * 0.045,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: size.height * 0.015),
                                      Row(
                                        children: [
                                          ClipOval(
                                            child: Container(
                                              width: size.width * 0.04,
                                              height: size.height * 0.02,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                          Expanded(
                                            child: DashedLine(
                                              dashWidth: size.width * 0.02,
                                              dashHeight: size.height * 0.002,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                          ClipOval(
                                            child: Container(
                                              width: size.width * 0.04,
                                              height: size.height * 0.02,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: size.height * 0.018),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10.0),
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isQRCodeFullScreen = true;
                                            });
                                          },
                                          child: RepaintBoundary(
                                            key: qrKey,
                                            child: QrImageView(
                                              data: vCardData,
                                              version: QrVersions.auto,
                                              size: size.width * 0.5,
                                              gapless: false,
                                              backgroundColor: isDarkMode ? const Color(0xFF303030) : const Color(0xFFEAF9E5),
                                              eyeStyle: QrEyeStyle(
                                                eyeShape: QrEyeShape.circle,
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                              dataModuleStyle: QrDataModuleStyle(
                                                dataModuleShape: QrDataModuleShape.square,
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ]);
            } else {
              Map<String, dynamic> data = {};
              String vCardData = '';

              if (offlineProvider.isExistedQR()) {
                vCardData = offlineProvider.getQR();
              }

              if (offlineProvider.isExistedProfile()) {
                data = offlineProvider.getProfile()!.toMap();
              }
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
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 10.0,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: qrFullScreenKey,
                            child: QrImageView(
                              data: vCardData,
                              version: QrVersions.auto,
                              size: size.width * 0.8,
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
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: size.height * 0.8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: size.width * 0.12,
                                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                      child: CircleAvatar(
                                          radius: size.width * 0.1,
                                          backgroundImage: data['images'] != null && data['images'].isNotEmpty ? NetworkImage(data['images']) : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                          onBackgroundImageError: (_, __) {
                                            const AssetImage('assets/default_avatar.png');
                                          }),
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
                                            builder: (context) => const MyProfilePage(),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 24,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                          Text(
                                            AppLocalizations.of(context)!.more,
                                            style: TextStyle(
                                              fontSize: size.width * 0.04,
                                              fontWeight: FontWeight.w500,
                                              color: isDarkMode ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                AppLocalizations.of(context)!.greeting(data['employee_name']),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.green : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              ClipPath(
                                clipper: TicketShapeClipper(),
                                child: Container(
                                  padding: EdgeInsets.all(size.width * 0.04),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF303030) : const Color(0xFFEAF9E5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.scanToSaveContact,
                                        style: TextStyle(
                                          fontSize: size.width * 0.045,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: size.height * 0.015),
                                      Row(
                                        children: [
                                          ClipOval(
                                            child: Container(
                                              width: size.width * 0.04,
                                              height: size.height * 0.02,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                          Expanded(
                                            child: DashedLine(
                                              dashWidth: size.width * 0.02,
                                              dashHeight: size.height * 0.002,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                          ClipOval(
                                            child: Container(
                                              width: size.width * 0.04,
                                              height: size.height * 0.02,
                                              color: Colors.yellow,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: size.height * 0.018),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10.0),
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isQRCodeFullScreen = true;
                                            });
                                          },
                                          child: RepaintBoundary(
                                            key: qrKey,
                                            child: QrImageView(
                                              data: vCardData,
                                              version: QrVersions.auto,
                                              size: size.width * 0.5,
                                              gapless: false,
                                              backgroundColor: isDarkMode ? const Color(0xFF303030) : const Color(0xFFEAF9E5),
                                              eyeStyle: QrEyeStyle(
                                                eyeShape: QrEyeShape.circle,
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                              dataModuleStyle: QrDataModuleStyle(
                                                dataModuleShape: QrDataModuleShape.square,
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ]);
              // return const Center(child: Text('No data available.'));
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
  String gender;
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
      padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.01),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          SizedBox(width: MediaQuery.of(context).size.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
