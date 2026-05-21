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

  Future<void> insertJalan(String nama, String wktLineString) async {
    try {
      await _supabase.from('namajalan_utama').insert({
        'nama': nama,
        'geom': wktLineString,
      });
    } catch (e) {
      throw Exception('Gagal menyimpan data jalan: $e');
    }
  }

  Future<void> updateLokasi(dynamic id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('lokasi').update(data).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Error Update Database: ${e.message} (Detail: ${e.details})');
    } catch (e) {
      throw Exception('Gagal memperbarui data lokasi: $e');
    }
  }

  Future<void> replaceJalanBatch(List<Map<String, dynamic>> data) async {
    try {
      await _supabase.from('namajalan_utama').delete().neq('nama', '');
      if (data.isNotEmpty) {
        await _supabase.from('namajalan_utama').insert(data);
      }
    } catch (e) {
      throw Exception('Gagal mengganti data jalan dari GeoJSON: $e');
    }
  }

  Future<void> upsertBoundaryRule(String boundaryJson) async {
    try {
      await _supabase.from('aturan_sig').upsert({
        'kode_kriteria': 'BOUNDARY',
        'nama_kriteria': boundaryJson,
        'bobot': 0,
        'radius_buffer': 0,
        'tipe_kriteria': 'wilayah',
      }, onConflict: 'kode_kriteria');
    } catch (e) {
      throw Exception('Gagal menyimpan boundary wilayah: $e');
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
      // Mengambil dari VIEW agar koordinat latitude/longitude sudah terurai
      final response = await _supabase.from('v_lokasi_peta').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil semua data lokasi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllJalan() async {
    try {
      final response = await _supabase.from('namajalan_utama').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data jalan: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAturan() async {
    try {
      final response = await _supabase.from('aturan_sig').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching aturan_sig: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchGeometriVektor() async {
    try {
      // Mengambil data Polygon Wilayah LANGSUNG dari VIEW v_wilayah_geojson
      final wilayah = await _supabase.from('v_wilayah_geojson').select('geometry');
      // Mengambil data LineString Jalan
      final jalan = await _supabase.rpc('get_jalan_geojson');
      
      return [
        {'tipe': 'polygon', 'data': wilayah},
        {'tipe': 'line', 'data': jalan},
      ];
    } catch (e) {
      debugPrint("Info: Gagal mengambil data vektor. $e");
      return [];
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
