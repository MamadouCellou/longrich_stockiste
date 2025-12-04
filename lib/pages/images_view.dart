import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/download_service.dart';

class ImageFullScreenPage extends StatefulWidget {
  final List<ImageItem> images;
  final int initialIndex;
  final String message;

  const ImageFullScreenPage({
    super.key,
    required this.images,
    required this.initialIndex, this.message = "",
  });

  @override
  _ImageFullScreenPageState createState() => _ImageFullScreenPageState();
}

class _ImageFullScreenPageState extends State<ImageFullScreenPage> {
  late PageController _pageController;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  int actualImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    setState(() {
      if (_transformationController.value != Matrix4.identity()) {
        _transformationController.value = Matrix4.identity();
      } else {
        final position = _doubleTapDetails!.localPosition;
        _transformationController.value = Matrix4.identity()
          ..translate(-position.dx * 2, -position.dy * 2)
          ..scale(2.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasMultipleImages = widget.images.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu de l\'image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (widget.images[actualImageIndex].path != null && widget.images[actualImageIndex].path!.isNotEmpty) {
                await DownloadService.downloadImage(
                  context,
                  widget.images[actualImageIndex].path!,
                  widget.message,
                );
              }
            },
          ),

        ],
      ),
      body: Center(
        child: hasMultipleImages
            ? PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            setState(() {
              actualImageIndex = index;
            });
            return _buildImageViewer(widget.images[index]);
          },
        )
            : _buildImageViewer(widget.images.first),
      ),
    );
  }

  Widget _buildImageViewer(ImageItem imageItem) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: _getImageWidget(imageItem),
      ),
    );
  }

  Widget _getImageWidget(ImageItem imageItem) {
    if (imageItem.isLocal) {
      // Si c'est l'image de profil par défaut, on affiche un texte
      if (imageItem.path == null) {
        return const Center(
          child: Text(
            'Aucune image reçu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }

      // Cas d'une image locale depuis assets
      if (imageItem.path!.startsWith('assets/')) {
        return Image.asset(
          imageItem.path!,
          fit: BoxFit.contain,
        );
      }

      // Cas d'une image locale depuis un fichier (téléchargée ou galerie)
      return Image.file(
        File(imageItem.path!),
        fit: BoxFit.contain,
      );
    } else {
      // Cas d'une image en ligne
      return CachedNetworkImage(
        imageUrl: imageItem.path!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    }
  }

}

class ImageItem {
  final String? path;
  final bool isLocal;

  ImageItem({required this.path, required this.isLocal});
}
