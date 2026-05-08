import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class CsvLogic {
  final LokasiRepository _repository = LokasiRepository();

  Future<String?> pickAndUploadCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        return await uploadCsvFromFile(File(result.files.single.path!));
      }
      return null;
    } catch (e) {
      return "Terjadi kesalahan: ${e.toString()}";
    }
  }

  Future<String?> uploadCsvFromFile(File file) async {
    try {
      final input = await file.readAsString();
      
      // Menggunakan Csv().decode sesuai versi library yang terpasang
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

      List<Map<String, dynamic>> pointData = [];
      int jalanCount = 0;
      
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 2) continue;

        final String nama = namaIdx != -1 && row.length > namaIdx ? row[namaIdx].toString() : "Tanpa Nama";
        final String kategori = kategoriIdx != -1 && row.length > kategoriIdx ? row[kategoriIdx].toString().trim().toLowerCase() : 'bengkel';
        
        // 1. Data JALAN (LineString)
        if (kategori == 'jalan') {
          String? wkt;
          if (geomIdx != -1 && row.length > geomIdx) {
            wkt = row[geomIdx].toString();
          } else if (longIdx != -1 && latIdx != -1 && row.length > longIdx && row.length > latIdx) {
            wkt = "LINESTRING(${row[longIdx]} ${row[latIdx]})";
          }

          if (wkt != null && wkt.toUpperCase().startsWith('LINESTRING')) {
            await _repository.insertJalan(nama, wkt);
            jalanCount++;
          }
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
          
          pointData.add(rowData);
        }
      }

      String summary = "";
      if (pointData.isNotEmpty) {
        await _repository.insertBatchLokasi(pointData);
        summary += "Berhasil mengimpor ${pointData.length} data lokasi (Point). ";
      }
      if (jalanCount > 0) {
        summary += "Berhasil mengimpor $jalanCount data jalan (LineString).";
      }

      return summary.isEmpty ? "Tidak ada data yang valid untuk diimpor." : summary;
    } catch (e) {
      return "Gagal memproses file: ${e.toString()}";
    }
  }

  Future<File?> exportToCsv() async {
    try {
      final List<Map<String, dynamic>> pointData = await _repository.fetchAllLokasi();
      final List<Map<String, dynamic>> jalanData = await _repository.fetchAllJalan();
      
      List<List<dynamic>> rows = [];
      rows.add(['nama', 'kategori', 'jalan', 'geom', 'foto_url']);
      
      for (var item in pointData) {
        rows.add([item['nama'] ?? '', item['kategori'] ?? '', item['jalan'] ?? '', item['geom'] ?? '', item['foto_url'] ?? '']);
      }
      for (var item in jalanData) {
        rows.add([item['nama'] ?? '', 'jalan', '', item['geom'] ?? '', '']);
      }

      // Menggunakan Csv().encode sesuai library
      String csvData = Csv().encode(rows);
      
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/export_gis_full_vector.csv";
      final file = File(path);
      
      return await file.writeAsString(csvData);
    } catch (e) {
      debugPrint("Export error: $e");
      return null;
    }
  }
}
