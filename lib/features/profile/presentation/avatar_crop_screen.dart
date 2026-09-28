import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/constants/app_colors.dart';

class AvatarCropScreen extends StatefulWidget {
  final File imageFile;
  final String title;

  const AvatarCropScreen({
    super.key,
    required this.imageFile,
    this.title = 'Adjust Profile Picture',
  });

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  int _rotationTurns = 0;
  double _zoomLevel = 1.0;
  bool _isProcessing = false;

  static const double _cropSize = 280.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
      _resetTransform();
    });
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _zoomLevel = 1.0;
    });
  }

  Future<void> _cropAndSave() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not locate render boundary.');
      }

      // Render at pixel ratio 1.5 (~420x420 px), perfect for high-DPI circular avatars
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image data.');
      }

      final bytes = byteData.buffer.asUint8List();
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';

      if (mounted) {
        Navigator.of(context).pop(base64String);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to crop photo: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            onPressed: _rotateClockwise,
          ),
          IconButton(
            tooltip: 'Reset position',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _resetTransform,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Drag and pinch to position your face inside the circle',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: _cropSize,
                  height: _cropSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Viewport capturing only what is inside
                      ClipOval(
                        child: RepaintBoundary(
                          key: _cropKey,
                          child: Container(
                            width: _cropSize,
                            height: _cropSize,
                            color: Colors.black,
                            child: InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 1.0,
                              maxScale: 4.0,
                              panEnabled: true,
                              scaleEnabled: true,
                              boundaryMargin: const EdgeInsets.all(_cropSize),
                              onInteractionUpdate: (details) {
                                final scale = _transformController.value.getMaxScaleOnAxis();
                                if ((scale - _zoomLevel).abs() > 0.05) {
                                  setState(() {
                                    _zoomLevel = scale.clamp(1.0, 4.0);
                                  });
                                }
                              },
                              child: RotatedBox(
                                quarterTurns: _rotationTurns,
                                child: Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.cover,
                                  width: _cropSize,
                                  height: _cropSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Overlay ring guide
                      IgnorePointer(
                        child: Container(
                          width: _cropSize,
                          height: _cropSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
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
            // Zoom slider control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.zoom_out_rounded,
                      color: Colors.white54, size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        thumbColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _zoomLevel,
                        min: 1.0,
                        max: 4.0,
                        onChanged: (val) {
                          setState(() => _zoomLevel = val);
                          final currentTranslation =
                              _transformController.value.getTranslation();
                          final newMatrix = Matrix4.identity()
                            ..translate(
                                currentTranslation.x, currentTranslation.y)
                            ..scale(val);
                          _transformController.value = newMatrix;
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in_rounded,
                      color: Colors.white54, size: 20),
                ],
              ),
            ),
            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isProcessing ? null : _cropAndSave,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 22),
                  label: Text(
                    _isProcessing ? 'Setting picture...' : 'Set as Profile Picture',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
