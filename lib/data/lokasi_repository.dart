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
      // Memanggil VIEW v_lokasi_peta yang sudah mengonversi geometry
      final response = await _supabase
          .from('v_lokasi_peta')
          .select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data lokasi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSawRanking() async {
    try {
      // Mengambil hasil perhitungan SAW dari View di Supabase
      final response = await _supabase
          .from('v_rekomendasi_bengkel_saw')
          .select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil ranking SAW: $e');
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

  Future<void> deleteLokasi(dynamic id) async {
    try {
      // DIAGNOSTIK: Cek apakah data ada sebelum dihapus
      final check = await _supabase.from('lokasi').select('id').eq('id', id).maybeSingle();
      
      if (check == null) {
        debugPrint("DIAGNOSTIK: ID '$id' BENAR-BENAR TIDAK ADA di tabel 'lokasi'. Ini berarti ID dari View bukan ID asli tabel.");
        throw Exception("ID dari View tidak cocok dengan ID di tabel utama.");
      }

      debugPrint("DIAGNOSTIK: ID ditemukan. Mencoba menghapus...");
      
      // Jika data ada tapi response delete kosong, berarti masalahnya adalah RLS Policy di Supabase
      final response = await _supabase.from('lokasi').delete().eq('id', id).select();
      
      if (response.isEmpty) {
        debugPrint("DIAGNOSTIK: Delete berhasil dipanggil tapi nol baris terhapus. Periksa RLS Policy (DELETE) di Dashboard Supabase!");
        throw Exception("Izin hapus ditolak. Periksa kebijakan RLS di Supabase.");
      }
      
      debugPrint("Berhasil menghapus data dengan ID: $id");
    } catch (e) {
      debugPrint("Error detail: $e");
      throw Exception('Gagal menghapus data: $e');
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
