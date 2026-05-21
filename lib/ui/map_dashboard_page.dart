import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/loading_overlay_card.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

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
  List<Polyline> _roadLines = []; // Data Vector Line (Jalan)
  List<Map<String, dynamic>> _rules = []; // Aturan lengkap dari DB
  Map<String, int> _bufferRules = {}; // Shortcut radius
  List<LatLng> _medanBaruBoundary = []; // Batas wilayah dari DB
  bool _isLoading = true;
  bool _showBuffers = true;
  bool _showBoundary = true;
  bool _showRoads = true;
  bool _showLegend = false; // Status collapse legenda
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Menyiapkan peta...';

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
        
        // Coba tampilkan detail otomatis jika ID ditemukan
        if (widget.targetId != null) {
          _repository.fetchAllLokasi().then((data) {
             final targetData = data.firstWhere(
               (d) => d['id'].toString() == widget.targetId, 
               orElse: () => {}
             );
             if (targetData.isNotEmpty && mounted) {
                _showLocationDetail(targetData);
             }
          });
        }
        
        // Panggil callback agar state target di MainPage dibersihkan
        widget.onLocationHandled?.call();
      } catch (e) {
        debugPrint("Gagal navigasi peta: $e");
      }
    });
  }

  Future<void> _fetchLocations() async {
    const int totalSteps = 4;
    int completedSteps = 0;

    void advanceLoading(String message) {
      completedSteps++;
      if (!mounted) return;
      setState(() {
        _loadingMessage = message;
        _loadingProgress = completedSteps / totalSteps;
      });
    }

    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Mengambil aturan analisis...';
    });
    try {
      // 1. Ambil Aturan dari Supabase
      final aturanRaw = await _repository.fetchAturan();
      advanceLoading('Aturan analisis dimuat.');
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

      // 2. Ambil Data Vektor (Polygon & Line)
      final vektorData = await _repository.fetchGeometriVektor();
      advanceLoading('Data geometri wilayah dan jalan dimuat.');
      List<Polyline> loadedRoads = [];
      
      for (var v in vektorData) {
        if (v['tipe'] == 'line' && v['data'] != null) {
          try {
            final dynamic rawData = v['data'];
            final Map<String, dynamic> geojson = rawData is String ? jsonDecode(rawData) : rawData;
            final List<dynamic> features = geojson['features'] as List? ?? [];
            
            for (var f in features) {
              final geometry = f['geometry'];
              final properties = f['properties'] ?? {};
              if (geometry == null) continue;
              
              final String type = geometry['type'] ?? '';
              final dynamic coords = geometry['coordinates'];
              final String jenis = (properties['jenis'] ?? '').toString().toLowerCase();

              // Warna berbeda berdasarkan jenis jalan
              Color roadColor = const Color(0xFF1E40AF); // Blue for Jalan Utama
              double roadWidth = 4.5;

              if (jenis.contains('residential')) {
                roadColor = const Color(0xFFF97316); // Orange for Residential
                roadWidth = 2.5;
              }

              if (type == 'LineString') {
                loadedRoads.add(Polyline(
                  points: (coords as List).map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                  color: roadColor,
                  strokeWidth: roadWidth,
                ));
              } else if (type == 'MultiLineString') {
                for (var line in (coords as List)) {
                  loadedRoads.add(Polyline(
                    points: (line as List).map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                    color: roadColor,
                    strokeWidth: roadWidth,
                  ));
                }
              }
            }
          } catch (e) {
            debugPrint("Error parsing road GeoJSON: $e");
          }
        } else if (v['tipe'] == 'polygon' && v['data'] != null) {
          // Parsing GeoJSON dari View v_wilayah_geojson
          final List<dynamic> listData = v['data'];
          for (var item in listData) {
            final dynamic geomRaw = item['geometry'];
            if (geomRaw != null && loadedBoundary.isEmpty) {
              final Map<String, dynamic> geometry = geomRaw is String ? jsonDecode(geomRaw) : geomRaw;
              if (geometry['type'] == 'Polygon') {
                final coords = geometry['coordinates'][0] as List;
                loadedBoundary = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
                break; // Ambil wilayah pertama yang ditemukan
              }
            }
          }
        }
      }

      // 3. Ambil Data Lokasi & Ranking
      final data = await _repository.fetchRekomendasiLokasi();
      advanceLoading('Data lokasi dimuat.');
      final ranking = await _repository.fetchSawRanking();
      advanceLoading('Ranking SAW dimuat, merender peta...');
      
      if (!mounted) return;

      setState(() {
        _loadingProgress = 1.0;
        _loadingMessage = 'Peta siap digunakan.';
        _markers = [];
        _circles = [];
        _roadLines = loadedRoads;
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

          // Penentuan Visual Berdasarkan Aturan Buffer & SAW
          Color themeColor = const Color(0xFF38BDF8); // Default buffer color
          IconData iconData = Icons.location_on;
          double bufferRadius = 0;
          int rank = ranking.indexWhere((r) => r['id'] == id) + 1;

          if (kategori == 'kandidat') {
            // Warna Berdasarkan Ranking SAW
            if (rank == 1) {
              themeColor = const Color(0xFF10B981); // Sangat Strategis (Green)
            } else if (rank <= 3) {
              themeColor = const Color(0xFFF59E0B); // Cukup Strategis (Amber)
            } else {
              themeColor = const Color(0xFFF97316); // Default Candidate (Orange)
            }
            iconData = Icons.stars;
            item['is_candidate'] = true;
            if (scoreMap.containsKey(id)) {
               item['skor_akhir'] = scoreMap[id];
            }
          } else if (kategori == 'bengkel') {
            themeColor = const Color(0xFFEF4444); // Kurang Strategis/Kompetitor (Red)
            iconData = Icons.build;
            bufferRadius = radiusPesaing;
          } else if (kategori == 'fasum' || nama.contains('jalan')) {
            themeColor = const Color(0xFF38BDF8); // Fasum (Blue) sesuai Legenda
            iconData = Icons.radar;
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
                        decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(4)),
                        child: Text("RANK $rank", 
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    Icon(iconData, color: themeColor, size: item['is_candidate'] == true ? 35 : 28),
                  ],
                ),
              ),
            ),
          );

          // Buffer Layer (Mengikuti warna marker/legenda)
          if (bufferRadius > 0) {
            _circles.add(
              CircleMarker(
                point: point,
                radius: bufferRadius,
                useRadiusInMeter: true,
                color: themeColor.withValues(alpha: 0.2), // Mengikuti warna marker
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nama'] ?? 'Tanpa Nama',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (data['kategori'] ?? 'N/A').toString().toUpperCase(),
                            style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data['skor_akhir'] != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text("SKOR SAW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          Text(
                            data['skor_akhir'].toStringAsFixed(4),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.map, "Alamat", data['jalan'] ?? 'Alamat tidak tersedia'),
              _buildDetailRow(
                Icons.access_time, 
                "Jam Operasional", 
                data['waktu_buka'] != null ? "${data['waktu_buka']} - ${data['waktu_tutup'] ?? '--:--'}" : "Data tidak tersedia"
              ),
              _buildDetailRow(Icons.event_busy, "Hari Libur", data['hari_libur'] ?? "Tidak ada hari libur"),
              _buildDetailRow(
                Icons.straighten, 
                "Luas Lahan", 
                data['luas_lahan'] != null ? "${data['luas_lahan']} m2" : "Data tidak tersedia"
              ),
              if (data['is_resmi'] == true)
                _buildDetailRow(Icons.verified_user, "Status", "Bengkel Resmi (Authorized)", color: Colors.blue),
              
              const SizedBox(height: 24),
              if (data['foto_url'] != null && data['foto_url'].toString().isNotEmpty) ...[
                const Text("Foto Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    data['foto_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey.shade100,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.broken_image, color: Colors.grey), Text("Gagal memuat foto")],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("TUTUP DETAIL"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, color: color ?? Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const LatLng centerMedanBaru = LatLng(3.5659, 98.6605);
    
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText(
          "GIS Medan Baru",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          const SupabaseStatusDot(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Segarkan Data",
            onPressed: _fetchLocations,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Fokus Wilayah",
            onPressed: () => _mapController.move(centerMedanBaru, 14.0),
          ),
          IconButton(
            icon: Icon(_showBuffers ? Icons.layers : Icons.layers_clear),
            onPressed: () => setState(() => _showBuffers = !_showBuffers),
            tooltip: "Toggle Buffer",
          ),
          IconButton(
            icon: Icon(_showBoundary ? Icons.crop_square_rounded : Icons.crop_square_outlined),
            onPressed: () => setState(() => _showBoundary = !_showBoundary),
            tooltip: "Toggle Batas Wilayah",
          ),
          IconButton(
            icon: Icon(_showRoads ? Icons.route : Icons.route_outlined),
            onPressed: () => setState(() => _showRoads = !_showRoads),
            tooltip: "Toggle Jalan Utama",
          ),
          IconButton(
            icon: Icon(_showLegend ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showLegend = !_showLegend),
            tooltip: "Toggle Legenda",
          ),
        ],
      ),
      body: Stack(
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
                  if (_showBoundary && _medanBaruBoundary.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _medanBaruBoundary,
                          color: const Color(0xFF0F766E).withValues(alpha: 0.1), // Hijau Toska Tua Transparan
                          borderColor: const Color(0xFF0F766E),
                          borderStrokeWidth: 3.0,
                        ),
                      ],
                    ),
                  if (_showRoads && _roadLines.isNotEmpty) PolylineLayer(polylines: _roadLines),
                  if (_showBuffers && _circles.isNotEmpty) CircleLayer(circles: _circles),
                  if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
                ],
              ),
              // Linear Loading Bar at Top
              if (_isLoading)
                LoadingOverlayCard(
                  progress: _loadingProgress,
                  message: _loadingMessage,
                  color: const Color(0xFFF97316),
                ),
              // Legend / GIS Panel (Collapsible)
              if (_showLegend)
                Positioned(
                  bottom: 20,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Legenda Analisis GIS", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => _showLegend = false),
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildLegendItem(Icons.stars, const Color(0xFF10B981), "Kandidat Strategis"),
                        _buildLegendItem(Icons.build, const Color(0xFFEF4444), "Bengkel Kompetitor"),
                        _buildLegendItem(Icons.radar, const Color(0xFF38BDF8), "Area Jangkauan (Buffer)"),
                        const Divider(),
                        const Text("Kriteria SAW (Dinamis):", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ..._rules.where((r) => !['BOUNDARY', 'wilayah'].contains(r['kode_kriteria']) && !['BOUNDARY', 'wilayah'].contains(r['tipe_kriteria'])).map((rule) {
                          final String kode = rule['kode_kriteria'] ?? '';
                          final String nama = rule['nama_kriteria'] ?? '';
                          
                          IconData icon = Icons.analytics;
                          if (kode == 'C1') icon = Icons.people;
                          if (kode == 'C2') icon = Icons.route;
                          if (kode == 'C3') icon = Icons.storefront;
                          if (kode == 'C4') icon = Icons.verified;
                          
                          return _buildLegendItem(icon, Colors.grey.shade700, "$nama ($kode)");
                        }),
                        if (_showBoundary)
                          _buildLegendItem(Icons.polyline, const Color(0xFF38BDF8), "Batas Wilayah"),
                      ],
                    ),
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
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
