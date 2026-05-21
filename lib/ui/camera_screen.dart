import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/loading_overlay_card.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Menyiapkan kamera...';

  void _updateLoading(double progress, String message) {
    if (!mounted) return;
    setState(() {
      _loadingProgress = progress.clamp(0.0, 1.0).toDouble();
      _loadingMessage = message;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupCameras();
  }

  Future<void> _setupCameras() async {
    try {
      _updateLoading(0.2, 'Mencari kamera yang tersedia...');
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _updateLoading(0.5, 'Membuat controller kamera...');
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        _updateLoading(0.8, 'Menginisialisasi preview kamera...');
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isReady = true;
            _loadingProgress = 1.0;
            _loadingMessage = 'Kamera siap.';
          });
        }
      }
    } catch (e) {
      debugPrint("Error setup camera: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(image.path));
      }
    } catch (e) {
      debugPrint("Error capture image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const ColoredBox(color: Colors.black),
            LoadingOverlayCard(
              progress: _loadingProgress,
              message: _loadingMessage,
              color: Colors.white,
              cardColor: const Color(0xFF111827),
              barrierColor: Colors.black.withValues(alpha: 0.24),
              progressBackgroundColor: Colors.white24,
              textColor: Colors.white,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: CameraPreview(_controller!),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Center(
                    child: GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
