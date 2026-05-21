import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

typedef CsvProgressCallback = void Function(double progress, String message);

class CsvLogic {
  final LokasiRepository _repository = LokasiRepository();

  Future<String?> pickAndUploadCsv({CsvProgressCallback? onProgress}) async {
    try {
      onProgress?.call(0.05, 'Membuka pemilih file CSV...');
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        onProgress?.call(0.1, 'File CSV dipilih, mulai membaca isi file...');
        return await uploadCsvFromFile(
          File(result.files.single.path!),
          onProgress: onProgress,
        );
      }
      return null;
    } catch (e) {
      return "Terjadi kesalahan: ${e.toString()}";
    }
  }

  Future<String?> uploadCsvFromFile(File file, {CsvProgressCallback? onProgress}) async {
    try {
      onProgress?.call(0.15, 'Membaca file CSV...');
      final input = await file.readAsString();
      
      // Menggunakan Csv().decode sesuai versi library yang terpasang
      onProgress?.call(0.25, 'Mem-parsing baris CSV...');
      List<List<dynamic>> rows = Csv().decode(input);
      
      if (rows.length <= 1) {
        return "File CSV kosong atau hanya berisi header.";
      }

      final header = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
      
      final int namaIdx = header.indexOf('nama');
      final int kategoriIdx = header.indexOf('kategori');
      final int jalanIdx = header.indexOf('jalan');
      final int longIdx = header.indexOf('longitude');
      final int latIdx = header.indexOf('latitude');
      final int fotoUrlIdx = header.indexOf('foto_url');
      final int geomIdx = header.indexOf('geom'); 
      final int bukaIdx = header.indexOf('waktu_buka');
      final int tutupIdx = header.indexOf('waktu_tutup');
      final int liburIdx = header.indexOf('hari_libur');
      final int resmiIdx = header.indexOf('is_resmi');

      List<Map<String, dynamic>> pointData = [];
      final int totalRows = rows.length - 1;
      
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 2) continue;

        final String nama = namaIdx != -1 && row.length > namaIdx ? row[namaIdx].toString() : "Tanpa Nama";
        final String kategori = kategoriIdx != -1 && row.length > kategoriIdx ? row[kategoriIdx].toString().trim().toLowerCase() : 'bengkel';
        
        // 1. Data JALAN (LineString)
        if (kategori == 'jalan') {
          final rowProgress = i / totalRows;
          onProgress?.call(0.25 + (rowProgress * 0.45), 'Melewati data jalan di CSV $i dari $totalRows...');
          continue;
        }

        // 2. Data Point
        String? pointGeom;
        if (geomIdx != -1 && row.length > geomIdx && row[geomIdx].toString().toUpperCase().startsWith('POINT')) {
          pointGeom = row[geomIdx].toString();
        } else if (longIdx != -1 && latIdx != -1 && row.length > longIdx && row.length > latIdx) {
          pointGeom = "POINT(${row[longIdx]} ${row[latIdx]})";
        }

        if (pointGeom != null) {
          final Map<String, dynamic> rowData = {
            'nama': nama,
            'kategori': kategori,
            'jalan': jalanIdx != -1 && row.length > jalanIdx ? row[jalanIdx].toString() : '',
            'geom': pointGeom,
          };
          
          if (fotoUrlIdx != -1 && row.length > fotoUrlIdx) {
            rowData['foto_url'] = row[fotoUrlIdx].toString();
          }

          // Atribut Tambahan untuk SAW & Operasional
          if (bukaIdx != -1 && row.length > bukaIdx) rowData['waktu_buka'] = row[bukaIdx].toString();
          if (tutupIdx != -1 && row.length > tutupIdx) rowData['waktu_tutup'] = row[tutupIdx].toString();
          if (liburIdx != -1 && row.length > liburIdx) rowData['hari_libur'] = row[liburIdx].toString();
          if (resmiIdx != -1 && row.length > resmiIdx) {
             rowData['is_resmi'] = row[resmiIdx].toString().toLowerCase() == 'true';
          }
          
          pointData.add(rowData);
        }

        final rowProgress = i / totalRows;
        onProgress?.call(0.25 + (rowProgress * 0.45), 'Memproses data CSV $i dari $totalRows...');
      }

      String summary = "";
      if (pointData.isNotEmpty) {
        onProgress?.call(0.8, 'Mengunggah ${pointData.length} data lokasi ke database...');
        await _repository.insertBatchLokasi(pointData);
        summary += "Berhasil mengimpor ${pointData.length} data lokasi (Point). ";
      }

      onProgress?.call(1.0, 'Impor CSV selesai.');

      return summary.isEmpty ? "Tidak ada data yang valid untuk diimpor." : summary;
    } catch (e) {
      return "Gagal memproses file: ${e.toString()}";
    }
  }

  Future<File?> exportToCsv({CsvProgressCallback? onProgress}) async {
    try {
      onProgress?.call(0.15, 'Mengambil data lokasi...');
      final List<Map<String, dynamic>> pointData = await _repository.fetchAllLokasi();
      onProgress?.call(0.35, 'Menyaring data point untuk ekspor...');
      
      List<List<dynamic>> rows = [];
      rows.add(['nama', 'kategori', 'jalan', 'geom', 'foto_url', 'waktu_buka', 'waktu_tutup', 'hari_libur', 'is_resmi']);
      
      for (var item in pointData) {
        rows.add([
          item['nama'] ?? '', 
          item['kategori'] ?? '', 
          item['jalan'] ?? '', 
          item['geom'] ?? '', 
          item['foto_url'] ?? '',
          item['waktu_buka'] ?? '',
          item['waktu_tutup'] ?? '',
          item['hari_libur'] ?? '',
          item['is_resmi'] ?? false,
        ]);
      }
      // Menggunakan Csv().encode sesuai library
      onProgress?.call(0.7, 'Menyusun file CSV...');
      String csvData = Csv().encode(rows);
      
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/export_gis_full_vector.csv";
      final file = File(path);
      
      onProgress?.call(0.9, 'Menyimpan file ekspor...');
      final savedFile = await file.writeAsString(csvData);
      onProgress?.call(1.0, 'Ekspor CSV selesai.');
      return savedFile;
    } catch (e) {
      debugPrint("Export error: $e");
      return null;
    }
  }
}
