import 'package:flutter/material.dart';
import 'package:pb_hrsystem/login/ready_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Handle skip
                    },
                    child:  Text(AppLocalizations.of(context)!.skip,style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  const Column(
                    children: [
                      SizedBox(height: 4),
                      Text("Lao", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/camera_image.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
               Center(
                child: Text(
                  AppLocalizations.of(context)!.cameraAndPhoto,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
               Center(
                child: Text(
                 AppLocalizations.of(context)!.manyFunctions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ReadyPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child:  Text(AppLocalizations.of(context)!.next, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "4 of 8",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
