import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/geojson_logic.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/loading_overlay_card.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

class GeoJsonImportPage extends StatefulWidget {
  const GeoJsonImportPage({super.key});

  @override
  State<GeoJsonImportPage> createState() => _GeoJsonImportPageState();
}

class _GeoJsonImportPageState extends State<GeoJsonImportPage> {
  final GeoJsonLogic _geoJsonLogic = GeoJsonLogic();
  late StreamSubscription _intentDataStreamSubscription;
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Mohon tunggu...';
  final GeoJsonImportMode _selectedMode = GeoJsonImportMode.boundary;

  void _setLoadingState({
    required bool isLoading,
    double? progress,
    String? message,
  }) {
    if (!mounted) return;
    setState(() {
      _isLoading = isLoading;
      if (progress != null) _loadingProgress = progress.clamp(0.0, 1.0).toDouble();
      if (message != null) _loadingMessage = message;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupSharingIntentListener();
  }

  void _setupSharingIntentListener() {
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    }, onError: (err) {
      debugPrint('getIntentDataStream geojson error: $err');
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    });
  }

  Future<void> _handleSharedFile(String? path) async {
    if (path == null) return;

    final lowercasePath = path.toLowerCase();
    final isGeoJson = lowercasePath.endsWith('.geojson') || lowercasePath.endsWith('.json');
    if (!isGeoJson) return;

    _setLoadingState(
      isLoading: true,
      progress: 0.05,
      message: 'Menerima file GeoJSON dari aplikasi lain...',
    );

    final message = await _geoJsonLogic.uploadGeoJsonFromFile(
      File(path),
      mode: _selectedMode,
      onProgress: (progress, message) {
        _setLoadingState(isLoading: true, progress: progress, message: message);
      },
    );

    if (!mounted) return;
    _setLoadingState(
      isLoading: false,
      progress: 1.0,
      message: 'Impor GeoJSON selesai.',
    );
    if (message != null) _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleImport() async {
    _setLoadingState(
      isLoading: true,
      progress: 0.0,
      message: 'Menyiapkan impor GeoJSON...',
    );

    final message = await _geoJsonLogic.pickAndUploadGeoJson(
      mode: _selectedMode,
      onProgress: (progress, message) {
        _setLoadingState(isLoading: true, progress: progress, message: message);
      },
    );

    if (!mounted) return;
    _setLoadingState(
      isLoading: false,
      progress: 1.0,
      message: 'Impor GeoJSON selesai.',
    );
    if (message != null) _showSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText('Manajemen GeoJSON'),
        actions: const [
          SupabaseStatusDot(),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.polyline_rounded, size: 80, color: Color(0xFF0F766E)),
                  const SizedBox(height: 20),
                  const Text(
                    'Unggah GeoJSON untuk data vektor polygon batas wilayah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih file GeoJSON yang berisi Polygon atau MultiPolygon untuk memperbarui batas wilayah Medan Baru.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _handleImport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload GeoJSON ke Supabase'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      minimumSize: const Size(300, 50),
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            LoadingOverlayCard(
              progress: _loadingProgress,
              message: _loadingMessage,
              color: Color(0xFF0F766E),
            ),
        ],
      ),
    );
  }
}
