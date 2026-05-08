import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class MapDashboardPage extends StatefulWidget {
  final LatLng? targetLocation;
  final String? targetId;
  final VoidCallback? onLocationHandled;

  const MapDashboardPage({
    super.key, 
    this.targetLocation, 
    this.targetId,
    this.onLocationHandled,
  });

  @override
  State<MapDashboardPage> createState() => _MapDashboardPageState();
}

class _MapDashboardPageState extends State<MapDashboardPage> {
  final MapController _mapController = MapController();
  final LokasiRepository _repository = LokasiRepository();
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];
  List<Map<String, dynamic>> _rankingData = [];
  List<Map<String, dynamic>> _rules = []; // Aturan lengkap dari DB
  Map<String, int> _bufferRules = {}; // Shortcut radius
  List<LatLng> _medanBaruBoundary = []; // Batas wilayah dari DB
  bool _isLoading = true;
  bool _showBuffers = true;
  bool _showBoundary = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  void didUpdateWidget(MapDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika ada koordinat target, segera gerakkan kamera
    if (widget.targetLocation != null && widget.targetLocation != oldWidget.targetLocation) {
      _handleTargetNavigation();
    }
  }

  void _handleTargetNavigation() {
    // Memberi sedikit jeda agar FlutterMap benar-benar siap setelah _isLoading = false
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      try {
        debugPrint("Navigating map to: ${widget.targetLocation}");
        _mapController.move(widget.targetLocation!, 17.5); // Zoom lebih dekat (17.5)
        
        // Panggil callback agar state target di MainPage dibersihkan
        widget.onLocationHandled?.call();
      } catch (e) {
        debugPrint("Gagal navigasi peta: $e");
      }
    });
  }

  Future<void> _fetchLocations() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Aturan dari Supabase
      final aturanRaw = await _repository.fetchAturan();
      _rules = aturanRaw;
      _bufferRules = {
        for (var a in aturanRaw) a['kode_kriteria'].toString(): (a['radius_buffer'] as num).toInt()
      };

      // Ekstrak Boundary dari DB jika ada
      final boundaryRule = aturanRaw.firstWhere(
        (a) => a['kode_kriteria'] == 'BOUNDARY', 
        orElse: () => {}
      );
      
      List<LatLng> loadedBoundary = [];
      if (boundaryRule.isNotEmpty && boundaryRule['nama_kriteria'] != null) {
        try {
          final List<dynamic> coords = jsonDecode(boundaryRule['nama_kriteria']);
          loadedBoundary = coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();
          // Tutup polygon jika belum tertutup
          if (loadedBoundary.isNotEmpty && loadedBoundary.first != loadedBoundary.last) {
            loadedBoundary.add(loadedBoundary.first);
          }
        } catch (e) {
          debugPrint("Gagal parse boundary: $e");
        }
      }

      // 2. Ambil Data Lokasi & Ranking
      final data = await _repository.fetchRekomendasiLokasi();
      final ranking = await _repository.fetchSawRanking();
      
      if (!mounted) return;

      setState(() {
        _rankingData = ranking;
        _markers = [];
        _circles = [];
        _medanBaruBoundary = loadedBoundary;
        
        // Aturan Buffer Dinamis (Fallback ke default jika DB kosong)
        final double radiusAkses = (_bufferRules['C2'] ?? 200).toDouble();
        final double radiusPesaing = (_bufferRules['C3'] ?? 500).toDouble();

        // Map skor untuk pencarian cepat
        final Map<String, double> scoreMap = {
          for (var r in ranking) r['id'].toString(): (r['skor_akhir'] ?? 0.0).toDouble(),
          // Tambahkan mapping untuk lokasi_id jika view SAW menggunakan alias
          for (var r in ranking) if (r['lokasi_id'] != null) r['lokasi_id'].toString(): (r['skor_akhir'] ?? 0.0).toDouble()
        };

        for (var item in data) {
          // ... (logika pembuatan marker dan circle tetap sama)
          // Mengambil dari field geometry_json (hasil ST_AsGeoJSON dari View)
          final dynamic geomData = item['geometry_json'];
          if (geomData == null) continue;

          final Map<String, dynamic> geometry = geomData is String 
              ? jsonDecode(geomData) 
              : geomData;
          
          final List<dynamic> coordinates = geometry['coordinates'];
          final point = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
          final String id = item['id'].toString();
          final String kategori = item['kategori']?.toString().toLowerCase() ?? '';
          final String nama = (item['nama'] ?? '').toString().toLowerCase();

          // Penentuan Visual Berdasarkan Aturan Buffer
          Color themeColor = Colors.blue;
          IconData iconData = Icons.location_on;
          double bufferRadius = 0;

          if (kategori == 'kandidat') {
            themeColor = Colors.amber;
            iconData = Icons.stars;
            item['is_candidate'] = true;
            if (scoreMap.containsKey(id)) {
               item['skor_akhir'] = scoreMap[id];
            }
          } else if (kategori == 'bengkel') {
            themeColor = Colors.red;
            iconData = Icons.settings_applications;
            bufferRadius = radiusPesaing;
          } else if (kategori == 'fasum' || nama.contains('jalan')) {
            themeColor = Colors.orange;
            iconData = Icons.add_road;
            bufferRadius = radiusAkses;
          }

          // Marker
          _markers.add(
            Marker(
              point: point,
              width: item['is_candidate'] == true ? 65 : 45,
              height: item['is_candidate'] == true ? 65 : 45,
              child: GestureDetector(
                onTap: () => _showLocationDetail(item),
                child: Column(
                  children: [
                    if (item['is_candidate'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(4)),
                        child: Text("RANK ${ranking.indexWhere((r) => r['id'] == id) + 1}", 
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    Icon(iconData, color: themeColor, size: item['is_candidate'] == true ? 35 : 28),
                  ],
                ),
              ),
            ),
          );

          // Buffer Layer
          if (bufferRadius > 0) {
            _circles.add(
              CircleMarker(
                point: point,
                radius: bufferRadius,
                useRadiusInMeter: true,
                color: themeColor.withValues(alpha: 0.15),
                borderColor: themeColor,
                borderStrokeWidth: 1,
              ),
            );
          }
        }
        _isLoading = false;
      });

      // Navigasi ke target jika ada (setelah loading selesai dan peta dirender)
      if (widget.targetLocation != null) {
        _handleTargetNavigation();
      }
    } catch (e) {
      debugPrint("Error Map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLocationDetail(Map<String, dynamic> data) {
    // Cari ranking dari data jika ada (misal di masa depan kita join data)
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['nama'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Kategori: ${data['kategori']?.toString().toUpperCase() ?? 'N/A'}"),
            Text("Jalan: ${data['jalan'] ?? 'N/A'}"),
            if (data['skor_akhir'] != null)
              Text("Skor SAW: ${data['skor_akhir'].toStringAsFixed(4)}", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (data['foto_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(data['foto_url'], height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const LatLng centerMedanBaru = LatLng(3.5659, 98.6605);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("GIS Bengkel Medan Baru"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Kembali ke Medan Baru",
            onPressed: () {
              _mapController.move(centerMedanBaru, 14.0);
            },
          ),
          IconButton(
            icon: Icon(_showBuffers ? Icons.layers : Icons.layers_clear),
            onPressed: () => setState(() => _showBuffers = !_showBuffers),
            tooltip: "Toggle Radius Buffer",
          ),
          IconButton(
            icon: Icon(_showBoundary ? Icons.map : Icons.map_outlined),
            onPressed: () => setState(() => _showBoundary = !_showBoundary),
            tooltip: "Toggle Batas Wilayah",
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: centerMedanBaru, // Center Medan Baru
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'trpl6a.sig.rasyid.sig_bengkel_motor_medan_baru',
                  ),
                  if (_showBoundary)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _medanBaruBoundary,
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2.5,
                        ),
                      ],
                    ),
                  if (_showBuffers) CircleLayer(circles: _circles),
                  MarkerLayer(markers: _markers),
                ],
              ),
              // Legend / GIS Panel
              Positioned(
                bottom: 20,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Legenda Analisis GIS", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      _buildLegendItem(Icons.stars, Colors.amber, "Kandidat Bengkel Baru"),
                      ..._rules.where((r) => r['kode_kriteria'] != 'BOUNDARY').map((rule) {
                        final String kode = rule['kode_kriteria'] ?? '';
                        final int radius = rule['radius_buffer'] ?? 0;
                        final String nama = rule['nama_kriteria'] ?? '';
                        
                        Color color = Colors.blue;
                        IconData icon = Icons.location_on;
                        
                        if (kode == 'C3') {
                          color = Colors.red;
                          icon = Icons.settings_applications;
                        } else if (kode == 'C2') {
                          color = Colors.orange;
                          icon = Icons.add_road;
                        }
                        
                        return _buildLegendItem(icon, color, "$nama ($kode: Radius ${radius}m)");
                      }),
                      if (_showBoundary)
                        _buildLegendItem(Icons.polyline, Colors.blue, "Batas Wilayah"),
                    ],
                  ),
                ),
              ),
              // Top Ranking Panel
              if (_rankingData.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Top 3 Rekomendasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Divider(height: 8),
                        ..._rankingData.take(3).map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text("${_rankingData.indexOf(r) + 1}. ${r['nama']}", 
                            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchLocations,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
