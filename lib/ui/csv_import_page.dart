import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/csv_logic.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/loading_overlay_card.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  final CsvLogic _csvLogic = CsvLogic();
  late StreamSubscription _intentDataStreamSubscription;
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Mohon tunggu...';

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
    // Untuk menangani file yang dishare saat aplikasi sedang berjalan (foreground/background)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // Untuk menangani file yang dishare saat aplikasi dibuka pertama kali (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    });
  }

  Future<void> _handleSharedFile(String? path) async {
    if (path == null) return;
    
    // Jika path adalah URL (diawali http) atau teks panjang tanpa ekstensi .csv, 
    // abaikan saja karena itu urusan DataCollectionPage
    bool isLikelyUrl = path.startsWith('http');
    bool hasCsvExtension = path.toLowerCase().endsWith('.csv');
    bool isContentUri = path.startsWith('content://');

    if (!hasCsvExtension && !isContentUri) {
      // Jika itu URL atau teks biasa, jangan tampilkan error "Hanya file CSV" 
      // karena mungkin user sedang share lokasi Gmaps
      if (!isLikelyUrl) {
         debugPrint("Shared item ignored by CSV page (not a CSV): $path");
      }
      return;
    }

    _setLoadingState(
      isLoading: true,
      progress: 0.05,
      message: 'Menerima file CSV dari aplikasi lain...',
    );
    
    try {
      // receive_sharing_intent biasanya memberikan path file lokal yang sudah bisa dibaca langsung
      // atau setidaknya bisa dibaca oleh File() jika itu path file://
      File file = File(path);

      final message = await _csvLogic.uploadCsvFromFile(
        file,
        onProgress: (progress, message) {
          _setLoadingState(isLoading: true, progress: progress, message: message);
        },
      );
      if (mounted) {
        _setLoadingState(
          isLoading: false,
          progress: 1.0,
          message: 'Impor CSV selesai.',
        );
        if (message != null) _showSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _setLoadingState(isLoading: false);
        _showSnackBar("Gagal memproses file share: ${e.toString()}");
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      message: 'Menyiapkan impor CSV...',
    );
    final message = await _csvLogic.pickAndUploadCsv(
      onProgress: (progress, message) {
        _setLoadingState(isLoading: true, progress: progress, message: message);
      },
    );
    if (mounted) {
      _setLoadingState(
        isLoading: false,
        progress: 1.0,
        message: 'Impor CSV selesai.',
      );
      if (message != null) _showSnackBar(message);
    }
  }

  Future<void> _handleExport() async {
    _setLoadingState(
      isLoading: true,
      progress: 0.0,
      message: 'Menyiapkan ekspor CSV...',
    );
    final file = await _csvLogic.exportToCsv(
      onProgress: (progress, message) {
        _setLoadingState(isLoading: true, progress: progress, message: message);
      },
    );
    if (mounted) {
      _setLoadingState(
        isLoading: false,
        progress: 1.0,
        message: 'Ekspor CSV selesai.',
      );
      if (file != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Data Lokasi Bengkel Medan Baru',
          ),
        );
      } else {
        _showSnackBar("Gagal mengekspor data.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText('Manajemen Data CSV'),
        actions: const [
          SupabaseStatusDot(),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_copy_rounded, size: 80, color: Color(0xFFF97316)),
                  const SizedBox(height: 20),
                  const Text(
                    'Pilih file CSV untuk data point:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'nama,kategori,jalan,longitude,latitude,foto_url,waktu_buka,waktu_tutup,hari_libur,is_resmi',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _handleImport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Pilih & Impor CSV ke Supabase'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      minimumSize: const Size(280, 50),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _handleExport,
                    icon: const Icon(Icons.download),
                    label: const Text('Ekspor & Bagikan CSV'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(280, 50),
                    ),
                  ),
                ],
              ),
          ),
          if (_isLoading)
            LoadingOverlayCard(
              progress: _loadingProgress,
              message: _loadingMessage,
              color: Color(0xFFF97316),
            ),
        ],
      ),
    );
  }
}

