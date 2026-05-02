import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/csv_logic.dart';

class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  final CsvLogic _csvLogic = CsvLogic();
  late StreamSubscription _intentDataStreamSubscription;
  bool _isLoading = false;

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

    setState(() => _isLoading = true);
    
    try {
      // receive_sharing_intent biasanya memberikan path file lokal yang sudah bisa dibaca langsung
      // atau setidaknya bisa dibaca oleh File() jika itu path file://
      File file = File(path);

      final message = await _csvLogic.uploadCsvFromFile(file);
      if (mounted) {
        setState(() => _isLoading = false);
        if (message != null) _showSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    setState(() => _isLoading = true);
    final message = await _csvLogic.pickAndUploadCsv();
    if (mounted) {
      setState(() => _isLoading = false);
      if (message != null) _showSnackBar(message);
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    final file = await _csvLogic.exportToCsv();
    if (mounted) {
      setState(() => _isLoading = false);
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
        title: const Text('Manajemen Data CSV'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Mohon tunggu...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_copy_rounded, size: 80, color: Colors.deepPurple),
                  const SizedBox(height: 20),
                  const Text(
                    'Pilih file CSV dengan format:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('nama,kategori,jalan,longitude,latitude,foto_url,timestamp_utc'),
                  const SizedBox(height: 30),
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
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(280, 50),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
