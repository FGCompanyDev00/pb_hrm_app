import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatelessWidget {
  final String imagePath;

  const ImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imagePath),
          backgroundDecoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ),
    );
  }
}
