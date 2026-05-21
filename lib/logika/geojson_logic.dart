import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

typedef GeoJsonProgressCallback = void Function(double progress, String message);

enum GeoJsonImportMode { boundary }

class GeoJsonLogic {
  final LokasiRepository _repository = LokasiRepository();

  Future<String?> pickAndUploadGeoJson({
    required GeoJsonImportMode mode,
    GeoJsonProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call(0.05, 'Membuka pemilih file GeoJSON...');
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['geojson', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        onProgress?.call(0.1, 'File GeoJSON dipilih, mulai membaca isi file...');
        return uploadGeoJsonFromFile(
          File(result.files.single.path!),
          mode: mode,
          onProgress: onProgress,
        );
      }

      return null;
    } catch (e) {
      return 'Terjadi kesalahan saat memilih file GeoJSON: $e';
    }
  }

  Future<String?> uploadGeoJsonFromFile(
    File file, {
    required GeoJsonImportMode mode,
    GeoJsonProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call(0.15, 'Membaca file GeoJSON...');
      final input = await file.readAsString();
      onProgress?.call(0.25, 'Mem-parsing struktur GeoJSON...');
      final dynamic decoded = jsonDecode(input);

      final List<Map<String, dynamic>> features = _normalizeFeatures(decoded);
      if (features.isEmpty) {
        return 'GeoJSON tidak memiliki feature yang bisa diproses.';
      }

      List<List<double>>? boundaryCoords;
      int processed = 0;
      int polygonCount = 0;

      for (final feature in features) {
        final Map<String, dynamic>? geometry = _extractGeometry(feature);
        if (geometry == null) {
          processed++;
          continue;
        }

        final String type = (geometry['type'] ?? '').toString();

        if (mode == GeoJsonImportMode.boundary &&
            (type == 'Polygon' || type == 'MultiPolygon')) {
          final coords = _extractBoundaryCoords(geometry);
          if (coords.isNotEmpty) {
            boundaryCoords ??= coords;
            polygonCount++;
          }
        }

        processed++;
        onProgress?.call(
          0.25 + ((processed / features.length) * 0.45),
          'Memproses feature GeoJSON $processed dari ${features.length}...',
        );
      }

      if (mode == GeoJsonImportMode.boundary && boundaryCoords == null) {
        return 'File GeoJSON boundary harus berisi Polygon atau MultiPolygon yang valid.';
      }

      if (mode == GeoJsonImportMode.boundary && boundaryCoords != null) {
        onProgress?.call(0.9, 'Menyimpan boundary Medan Baru...');
        await _repository.upsertBoundaryRule(jsonEncode(boundaryCoords));
      }

      onProgress?.call(1.0, 'Impor GeoJSON selesai.');

      final boundaryMessage = polygonCount > 1
          ? 'Boundary Medan Baru berhasil diperbarui. Hanya polygon pertama yang dipakai sebagai boundary.'
          : 'Boundary Medan Baru berhasil diperbarui.';
      return boundaryMessage;
    } catch (e) {
      return 'Gagal memproses file GeoJSON: $e';
    }
  }

  List<Map<String, dynamic>> _normalizeFeatures(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final String type = (decoded['type'] ?? '').toString();
      if (type == 'FeatureCollection') {
        final List features = decoded['features'] as List? ?? const [];
        return features.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (type == 'Feature') {
        return [decoded];
      }
      return [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': decoded,
        }
      ];
    }

    return const [];
  }

  Map<String, dynamic>? _extractGeometry(Map<String, dynamic> feature) {
    final dynamic geometry = feature['geometry'];
    if (geometry is Map<String, dynamic>) return geometry;
    if (geometry is Map) return Map<String, dynamic>.from(geometry);
    return null;
  }

  List<List<double>> _extractBoundaryCoords(Map<String, dynamic> geometry) {
    if (geometry['type'] == 'Polygon') {
      final rings = geometry['coordinates'] as List? ?? const [];
      if (rings.isEmpty) return const [];
      return _toLatLngPairs(rings.first);
    }

    final polygons = geometry['coordinates'] as List? ?? const [];
    if (polygons.isEmpty) return const [];
    final firstPolygon = polygons.first as List? ?? const [];
    if (firstPolygon.isEmpty) return const [];
    return _toLatLngPairs(firstPolygon.first);
  }

  List<List<double>> _toLatLngPairs(dynamic rawCoords) {
    final coords = _toCoordinateList(rawCoords);
    final pairs = coords.map((coord) => [coord[1], coord[0]]).toList();
    if (pairs.isNotEmpty && (pairs.first[0] != pairs.last[0] || pairs.first[1] != pairs.last[1])) {
      pairs.add([pairs.first[0], pairs.first[1]]);
    }
    return pairs;
  }

  List<List<double>> _toCoordinateList(dynamic rawCoords) {
    final list = rawCoords as List? ?? const [];
    return list
        .whereType<List>()
        .where((item) => item.length >= 2)
        .map((item) => [double.parse(item[0].toString()), double.parse(item[1].toString())])
        .toList();
  }
}
