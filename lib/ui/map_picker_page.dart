import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  final LokasiRepository _repository = LokasiRepository();
  
  List<Marker> _otherMarkers = [];
  List<CircleMarker> _circles = [];
  List<Polyline> _roadLines = [];
  List<LatLng> _boundaryPoints = [];
  Map<String, int> _bufferRules = {};
  
  bool _isLoading = true;
  bool _showLegend = false;
  bool _isOutsideBoundary = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _fetchAllMapData();
  }

  Future<void> _fetchAllMapData() async {
    try {
      // 1. Ambil Aturan & Buffer
      final aturanRaw = await _repository.fetchAturan();
      _bufferRules = {
        for (var a in aturanRaw) a['kode_kriteria'].toString(): (a['radius_buffer'] as num).toInt()
      };

      // 2. Ambil Geometri Vektor (Jalan & Wilayah)
      final vektorData = await _repository.fetchGeometriVektor();
      List<Polyline> loadedRoads = [];
      List<LatLng> loadedBoundary = [];

      for (var v in vektorData) {
        final dynamic rawData = v['data'];
        if (rawData == null) continue;

        if (v['tipe'] == 'line') {
          try {
            final Map<String, dynamic> geojson = rawData is String 
                ? jsonDecode(rawData) 
                : (rawData is List ? {"type": "FeatureCollection", "features": rawData} : rawData as Map<String, dynamic>);
            
            final List<dynamic> features = geojson['features'] as List? ?? [];
            for (var f in features) {
              final geometry = f['geometry'];
              final properties = f['properties'] ?? {};
              if (geometry == null) continue;
              final String type = geometry['type'] ?? '';
              final dynamic coords = geometry['coordinates'];
              final String jenis = (properties['jenis'] ?? '').toString().toLowerCase();

              Color roadColor = const Color(0xFF1E40AF);
              double roadWidth = 4.0;
              if (jenis.contains('residential')) {
                roadColor = const Color(0xFFF97316).withValues(alpha: 0.6);
                roadWidth = 2.0;
              }

              if (type == 'LineString' && coords is List) {
                loadedRoads.add(Polyline(
                  points: coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                  color: roadColor, strokeWidth: roadWidth,
                ));
              } else if (type == 'MultiLineString' && coords is List) {
                for (var line in coords) {
                  if (line is List) {
                    loadedRoads.add(Polyline(
                      points: line.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                      color: roadColor, strokeWidth: roadWidth,
                    ));
                  }
                }
              }
            }
          } catch (e) { debugPrint("Error parsing roads in picker: $e"); }
        } else if (v['tipe'] == 'polygon' && rawData is List) {
          for (var item in rawData) {
            try {
              final dynamic geomRaw = item['geometry'];
              if (geomRaw != null) {
                final Map<String, dynamic> geometry = geomRaw is String ? jsonDecode(geomRaw) : geomRaw as Map<String, dynamic>;
                if (geometry['type'] == 'Polygon') {
                  final coords = geometry['coordinates'][0] as List;
                  loadedBoundary = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
                  break;
                }
              }
            } catch (e) { debugPrint("Error parsing polygon in picker: $e"); }
          }
        }
      }

      // 3. Ambil Lokasi & Ranking (Sama seperti Dashboard)
      final dataLocations = await _repository.fetchRekomendasiLokasi();
      final ranking = await _repository.fetchSawRanking();
      
      List<Marker> markers = [];
      List<CircleMarker> circles = [];
      
      final double radiusAkses = (_bufferRules['C2'] ?? 200).toDouble();
      final double radiusPesaing = (_bufferRules['C3'] ?? 500).toDouble();

      for (var item in dataLocations) {
        final dynamic geomData = item['geometry_json'];
        if (geomData == null) continue;
        final Map<String, dynamic> geometry = geomData is String ? jsonDecode(geomData) : geomData;
        final List<dynamic> coordinates = geometry['coordinates'];
        final point = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
        final String id = item['id'].toString();
        final String kategori = item['kategori']?.toString().toLowerCase() ?? '';

        Color themeColor = const Color(0xFF38BDF8);
        IconData iconData = Icons.location_on;
        double bufferRadius = 0;
        int rank = ranking.indexWhere((r) => r['id'] == id) + 1;

        if (kategori == 'kandidat') {
          if (rank == 1) {
            themeColor = const Color(0xFF10B981);
          } else if (rank <= 3) {
            themeColor = const Color(0xFFF59E0B);
          } else {
            themeColor = const Color(0xFFF97316);
          }
          iconData = Icons.stars;
        } else if (kategori == 'bengkel') {
          themeColor = const Color(0xFFEF4444);
          iconData = Icons.build;
          bufferRadius = radiusPesaing;
        } else {
          themeColor = const Color(0xFF38BDF8);
          iconData = Icons.radar;
          bufferRadius = radiusAkses;
        }

        markers.add(Marker(
          point: point, width: (kategori == 'kandidat') ? 60 : 40, height: (kategori == 'kandidat') ? 60 : 40,
          child: Column(
            children: [
              if (kategori == 'kandidat' && rank > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(4)),
                  child: Text("RANK $rank", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              Icon(iconData, color: themeColor, size: (kategori == 'kandidat') ? 30 : 24),
            ],
          ),
        ));

        if (bufferRadius > 0) {
          circles.add(CircleMarker(
            point: point, radius: bufferRadius, useRadiusInMeter: true,
            color: themeColor.withValues(alpha: 0.15), borderColor: themeColor, borderStrokeWidth: 1,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _bufferRules = _bufferRules;
          _roadLines = loadedRoads;
          _boundaryPoints = loadedBoundary;
          _otherMarkers = markers;
          _circles = circles;
          _isLoading = false;
          _checkBoundary(_selectedLocation);
        });
      }
    } catch (e) {
      debugPrint("Gagal muat data map picker: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return true;
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude; double y = point.latitude;
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y || polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude <= x || polygon[j].longitude <= x)) {
        if (polygon[i].longitude + (y - polygon[i].latitude) / (polygon[j].latitude - polygon[i].latitude) * (polygon[j].longitude - polygon[i].longitude) < x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  void _checkBoundary(LatLng point) {
    if (_boundaryPoints.isNotEmpty) {
      setState(() {
        _isOutsideBoundary = !_isPointInPolygon(point, _boundaryPoints);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi di Peta'),
        actions: [
          IconButton(
            icon: Icon(_showLegend ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showLegend = !_showLegend),
            tooltip: 'Legenda',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _selectedLocation),
            tooltip: 'Konfirmasi Lokasi',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 16.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                  _checkBoundary(point);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'trpl6a.sig.rasyid.sig_bengkel_motor_medan_baru',
              ),
              if (!_isLoading && _boundaryPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _boundaryPoints,
                      color: const Color(0xFF0F766E).withValues(alpha: 0.05),
                      borderColor: const Color(0xFF0F766E).withValues(alpha: 0.5),
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
              if (!_isLoading && _roadLines.isNotEmpty) PolylineLayer(polylines: _roadLines),
              if (!_isLoading && _circles.isNotEmpty) CircleLayer(circles: _circles),
              if (!_isLoading && _otherMarkers.isNotEmpty) MarkerLayer(markers: _otherMarkers),
              
              // Marker Pin Utama yang digerakkan user
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation, width: 50, height: 50,
                    child: Icon(Icons.location_pin, color: _isOutsideBoundary ? Colors.black : Colors.blueAccent, size: 45),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 10, left: 10, right: 10,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text("Sinkronisasi data analisis...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          
          if (_showLegend)
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Analisis GIS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Divider(height: 12),
                    _buildLegendItem(Icons.stars, const Color(0xFF10B981), "Kandidat Rank 1"),
                    _buildLegendItem(Icons.stars, const Color(0xFFF59E0B), "Kandidat Rank 2-3"),
                    _buildLegendItem(Icons.build, const Color(0xFFEF4444), "Bengkel Kompetitor"),
                    _buildLegendItem(Icons.radar, const Color(0xFF38BDF8), "Fasum / Jalan"),
                    _buildLegendItem(Icons.circle, Colors.grey.withValues(alpha: 0.4), "Area Jangkauan (Buffer)"),
                    _buildLegendItem(Icons.location_pin, Colors.blueAccent, "Titik Pilih Baru"),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isOutsideBoundary && !_isLoading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text("Lokasi di luar batas Medan Baru!", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Card(
                  elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Sinkronisasi Analisis Aktif', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316), fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, _selectedLocation),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('KONFIRMASI LOKASI'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                            backgroundColor: _isOutsideBoundary ? Colors.grey : const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
