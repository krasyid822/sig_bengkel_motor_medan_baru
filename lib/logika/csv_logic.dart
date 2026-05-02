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

      List<Map<String, dynamic>> dataToUpload = [];
      
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        if (namaIdx != -1 && longIdx != -1 && latIdx != -1 && 
            row.length > namaIdx && row.length > longIdx && row.length > latIdx) {
          final Map<String, dynamic> rowData = {
            'nama': row[namaIdx].toString(),
            'kategori': kategoriIdx != -1 && row.length > kategoriIdx 
                ? row[kategoriIdx].toString().trim().toLowerCase() 
                : 'bengkel',
            'jalan': jalanIdx != -1 && row.length > jalanIdx ? row[jalanIdx].toString() : '',
            'geom': 'POINT(${row[longIdx]} ${row[latIdx]})',
          };
          
          if (fotoUrlIdx != -1 && row.length > fotoUrlIdx) {
            rowData['foto_url'] = row[fotoUrlIdx].toString();
          }
          
          dataToUpload.add(rowData);
        }
      }

      if (dataToUpload.isNotEmpty) {
        await _repository.insertBatchLokasi(dataToUpload);
        return "Berhasil mengimpor ${dataToUpload.length} data ke Supabase.";
      } else {
        return "Format kolom tidak sesuai. Pastikan ada header: nama, longitude, latitude.";
      }
    } catch (e) {
      return "Gagal memproses file: ${e.toString()}";
    }
  }

  Future<File?> exportToCsv() async {
    try {
      final List<Map<String, dynamic>> data = await _repository.fetchAllLokasi();
      
      List<List<dynamic>> rows = [];
      // Header
      rows.add(['nama', 'kategori', 'jalan', 'longitude', 'latitude', 'timestamp_utc', 'foto_url']);
      
      for (var item in data) {
        String long = '0.0';
        String lat = '0.0';

        try {
          final dynamic geomData = item['geom'];
          if (geomData is String) {
            final clean = geomData.replaceAll('POINT(', '').replaceAll(')', '');
            final coords = clean.split(' ');
            if (coords.length >= 2) {
              long = coords[0];
              lat = coords[1];
            }
          } else if (geomData is Map) {
            final coords = geomData['coordinates'] as List;
            long = coords[0].toString();
            lat = coords[1].toString();
          }
        } catch (e) {
          debugPrint("Gagal parsing koordinat: $e");
        }
        
        rows.add([
          item['nama'] ?? '',
          item['kategori'] ?? '',
          item['jalan'] ?? '',
          long,
          lat,
          item['created_at'] ?? '',
          item['foto_url'] ?? '',
        ]);
      }

      // Menggunakan Csv().encode
      String csvData = Csv().encode(rows);
      
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/data_lokasi_export.csv";
      final file = File(path);
      
      return await file.writeAsString(csvData);
    } catch (e) {
      debugPrint("Export error: $e");
      return null;
    }
  }
}
