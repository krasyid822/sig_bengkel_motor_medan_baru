import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LokasiRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> insertBatchLokasi(List<Map<String, dynamic>> data) async {
    try {
      await _supabase.from('lokasi').insert(data);
    } on PostgrestException catch (e) {
      throw Exception('Error Database: ${e.message} (Detail: ${e.details})');
    } catch (e) {
      throw Exception('Gagal mengunggah data ke Supabase: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRekomendasiLokasi() async {
    try {
      final response = await _supabase
          .from('leaflet_lokasi_rekomendasi')
          .select('*, geometry:geom.ST_AsGeoJSON()');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data lokasi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllLokasi() async {
    try {
      final response = await _supabase.from('lokasi').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil semua data lokasi: $e');
    }
  }

  Future<String?> uploadFoto(File file) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'dokumentasi/$fileName';

      // Menggunakan storage.from().upload() dengan penanganan eksplisit untuk bucket
      // Pastikan bucket 'sig_assets' sudah diset ke 'Public' di dashboard Supabase
      final String bucketName = 'sig_assets';
      
      await _supabase.storage.from(bucketName).upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint("Error detail upload: $e");
      // Jika error 404, biasanya bucket benar-benar tidak ditemukan atau typo
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        throw Exception('Bucket "sig_assets" tidak ditemukan. Pastikan nama bucket di Supabase EXACTLY "sig_assets" (case sensitive) dan statusnya Public.');
      }
      throw Exception('Gagal mengunggah foto ke Supabase Storage: $e');
    }
  }
}
