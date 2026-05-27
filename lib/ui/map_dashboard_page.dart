import 'dart:convert';
import 'dart:math' as math;
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
  final Function(LatLng)? onConfirmSelection;

  const MapDashboardPage({
    super.key, 
    this.targetLocation, 
    this.targetId,
    this.onLocationHandled,
    this.onConfirmSelection,
  });

  @override
  State<MapDashboardPage> createState() => _MapDashboardPageState();
}

class _MapDashboardPageState extends State<MapDashboardPage> {
  final MapController _mapController = MapController();
  final LokasiRepository _repository = LokasiRepository();
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];
  List<Polyline> _roadLines = [];
  List<LatLng> _medanBaruBoundary = [];
  LatLng? _activeAutoKandidat;
  bool _isLoading = true;
  bool _showBuffers = true;
  bool _showBoundary = true;
  bool _showRoads = true;
  bool _showLegend = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Menyiapkan peta...';

  // State pencarian
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _allLocations = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetLocation != null && widget.targetLocation != oldWidget.targetLocation) {
      _handleTargetNavigation();
    }
  }

  void _handleTargetNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(widget.targetLocation!, 17.5);
        if (widget.targetId == 'AUTO_KANDIDAT') {
          setState(() {
            _activeAutoKandidat = widget.targetLocation;
          });
        }
        if (widget.targetId != null && widget.targetId != 'AUTO_KANDIDAT') {
          _repository.fetchAllLokasi().then((data) {
             final targetData = data.firstWhere(
               (d) => d['id']?.toString() == widget.targetId, 
               orElse: () => {}
             );
             if (targetData.isNotEmpty && mounted) {
                _showLocationDetail(targetData);
             }
          });
        }
        widget.onLocationHandled?.call();
      } catch (e) {
        debugPrint("Gagal navigasi: $e");
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
      // 1. Ambil Aturan & Fallback Boundary
      final aturanRaw = await _repository.fetchAturan();
      advanceLoading('Aturan analisis dimuat.');
      
      final Map<String, int> localBufferRules = {
        for (var a in aturanRaw) a['kode_kriteria']?.toString() ?? '': (a['radius_buffer'] as num?)?.toInt() ?? 0
      };

      List<LatLng> localBoundary = [];
      final boundaryRule = aturanRaw.firstWhere((a) => a['kode_kriteria'] == 'BOUNDARY', orElse: () => {});
      if (boundaryRule.isNotEmpty && boundaryRule['nama_kriteria'] != null) {
        try {
          final List<dynamic> coords = jsonDecode(boundaryRule['nama_kriteria']);
          localBoundary = coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();
        } catch (e) { debugPrint("Fallback boundary error: $e"); }
      }

      // 2. Ambil Geometri Vektor (Jalan & Wilayah via View)
      final vektorData = await _repository.fetchGeometriVektor();
      advanceLoading('Data wilayah dimuat.');
      
      List<Polyline> localRoads = [];
      
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
              if (geometry == null) continue;
              final String type = geometry['type'] ?? '';
              final dynamic coords = geometry['coordinates'];
              if (coords == null) continue;

              final properties = f['properties'] ?? {};
              final String jenis = (properties['jenis'] ?? '').toString().toLowerCase();
              Color roadColor = const Color(0xFF1E40AF);
              double roadWidth = 4.5;
              if (jenis.contains('residential')) {
                roadColor = const Color(0xFFF97316);
                roadWidth = 2.5;
              }

              if (type == 'LineString' && coords is List) {
                localRoads.add(Polyline(
                  points: coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                  color: roadColor, strokeWidth: roadWidth,
                ));
              } else if (type == 'MultiLineString' && coords is List) {
                for (var line in coords) {
                  if (line is List) {
                    localRoads.add(Polyline(
                      points: line.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
                      color: roadColor, strokeWidth: roadWidth,
                    ));
                  }
                }
              }
            }
          } catch (e) { debugPrint("Error roads: $e"); }
        } else if (v['tipe'] == 'polygon' && rawData is List) {
          // Hanya gunakan dari view jika fallback BOUNDARY kosong
          if (localBoundary.isEmpty) {
            for (var item in rawData) {
              try {
                final dynamic geomRaw = item['geometry'];
                if (geomRaw != null) {
                  final Map<String, dynamic> geometry = geomRaw is String ? jsonDecode(geomRaw) : geomRaw as Map<String, dynamic>;
                  if (geometry['type'] == 'Polygon') {
                    final coords = geometry['coordinates'][0] as List;
                    localBoundary = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
                    break;
                  }
                }
              } catch (e) { debugPrint("Error polygon view: $e"); }
            }
          }
        }
      }

      // 3. Ambil Lokasi & Ranking
      final data = await _repository.fetchRekomendasiLokasi();
      advanceLoading('Data lokasi dimuat.');
      final ranking = await _repository.fetchSawRanking();
      advanceLoading('Ranking SAW dimuat.');
      
      List<Marker> localMarkers = [];
      List<CircleMarker> localCircles = [];
      
      final double radiusJalan = (localBufferRules['C2'] ?? 200).toDouble();
      final double radiusFasum = (localBufferRules['C3'] ?? 200).toDouble();
      final double radiusPesaing = (localBufferRules['C4'] ?? 500).toDouble();

      final Map<String, double> scoreMap = {
        for (var r in ranking) r['id']?.toString() ?? '': (r['skor_akhir'] as num?)?.toDouble() ?? 0.0,
        for (var r in ranking) if (r['lokasi_id'] != null) r['lokasi_id'].toString(): (r['skor_akhir'] as num?)?.toDouble() ?? 0.0
      };

      for (var item in data) {
        final dynamic geomData = item['geometry_json'];
        if (geomData == null) continue;
        final Map<String, dynamic> geometry = geomData is String ? jsonDecode(geomData) : geomData;
        final List<dynamic> coordinates = geometry['coordinates'];
        final point = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
        final String id = item['id']?.toString() ?? '';
        final String kategori = item['kategori']?.toString().toLowerCase() ?? '';
        final String nama = (item['nama'] ?? '').toString().toLowerCase();

        Color themeColor = const Color(0xFF38BDF8);
        IconData iconData = Icons.location_on;
        double bufferRadius = 0;
        int rankIndex = ranking.indexWhere((r) => (r['id']?.toString() == id) || (r['lokasi_id']?.toString() == id));
        int rank = rankIndex != -1 ? rankIndex + 1 : 0;

        if (kategori == 'kandidat') {
          if (rank == 1) {
            themeColor = const Color(0xFF10B981);
          } else if (rank > 1 && rank <= 3) {
            themeColor = const Color(0xFFF59E0B);
          } else {
            themeColor = const Color(0xFFF97316);
          }
          iconData = Icons.stars;
          if (scoreMap.containsKey(id)) {
            item['skor_akhir'] = scoreMap[id];
          }
        } else if (kategori == 'bengkel') {
          themeColor = const Color(0xFFEF4444);
          iconData = Icons.build;
          bufferRadius = radiusPesaing;
        } else if (kategori == 'fasum') {
          themeColor = const Color(0xFF38BDF8);
          iconData = Icons.radar;
          bufferRadius = radiusFasum;
        } else if (nama.contains('jalan')) {
          themeColor = const Color(0xFF1E40AF);
          iconData = Icons.location_on;
          bufferRadius = radiusJalan;
        }

        localMarkers.add(Marker(
          point: point, width: (kategori == 'kandidat') ? 65 : 45, height: (kategori == 'kandidat') ? 65 : 45,
          child: GestureDetector(
            onTap: () => _showLocationDetail(item),
            child: Column(children: [
              if (kategori == 'kandidat' && rank > 0)
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(4)), child: Text("RANK $rank", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              Icon(iconData, color: themeColor, size: (kategori == 'kandidat') ? 35 : 28),
            ]),
          ),
        ));

        if (bufferRadius > 0) {
          localCircles.add(CircleMarker(
            point: point, radius: bufferRadius, useRadiusInMeter: true,
            color: themeColor.withValues(alpha: 0.2), borderColor: themeColor, borderStrokeWidth: 1,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _allLocations = data;
        _roadLines = localRoads;
        _medanBaruBoundary = localBoundary;
        _markers = localMarkers;
        _circles = localCircles;
        _isLoading = false;
        _loadingProgress = 1.0;
        _loadingMessage = 'Peta siap.';
      });

      if (widget.targetLocation != null) _handleTargetNavigation();
    } catch (e) {
      debugPrint("Error Map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLocations = [];
        _isSearching = false;
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredLocations = _allLocations.where((loc) {
        final name = (loc['nama'] ?? '').toString().toLowerCase();
        final street = (loc['jalan'] ?? '').toString().toLowerCase();
        final category = (loc['kategori'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) || 
               street.contains(lowercaseQuery) || 
               category.contains(lowercaseQuery);
      }).toList();
      _isSearching = true;
    });
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    const double earthRadius = 6378137;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      LatLng p1 = points[i];
      LatLng p2 = points[(i + 1) % points.length];
      double rad(double deg) => deg * (math.pi / 180.0);
      area += rad(p2.longitude - p1.longitude) * (2 + math.sin(rad(p1.latitude)) + math.sin(rad(p2.latitude)));
    }
    area = (area * earthRadius * earthRadius / 2.0).abs();
    return area / 10000;
  }

  void _showAreaInfo() {
    if (_medanBaruBoundary.isEmpty) return;
    double areaHa = _calculateArea(_medanBaruBoundary);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.layers, color: Colors.white), const SizedBox(width: 12), Text("Kecamatan Medan Baru\nLuas Wilayah: ${areaHa.toStringAsFixed(2)} Ha", style: const TextStyle(fontWeight: FontWeight.bold))]),
        backgroundColor: const Color(0xFF0F766E), duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLocationDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController, padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF97316))), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text((data['kategori'] ?? 'N/A').toString().toUpperCase(), style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 12)))])),
                  if (data['skor_akhir'] != null)
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Column(children: [const Text("SKOR SAW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))), Text((data['skor_akhir'] as num).toStringAsFixed(4), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))]))
                ],
              ),
              const SizedBox(height: 24), const Divider(), const SizedBox(height: 16),
              _buildDetailRow(Icons.map, "Alamat", data['jalan'] ?? 'Alamat tidak tersedia'),
              _buildDetailRow(Icons.access_time, "Jam Operasional", data['waktu_buka'] != null ? "${data['waktu_buka']} - ${data['waktu_tutup'] ?? '--:--'}" : "Data tidak tersedia"),
              _buildDetailRow(Icons.event_busy, "Hari Libur", data['hari_libur'] ?? "Tidak ada hari libur"),
              _buildDetailRow(Icons.straighten, "Luas Lahan", data['luas_lahan'] != null ? "${data['luas_lahan']} m2" : "Data tidak tersedia"),
              if (data['is_resmi'] == true) _buildDetailRow(Icons.workspace_premium, "Status", "Bengkel Resmi (Authorized)", color: Colors.blue),
              const SizedBox(height: 24),
              if (data['foto_url'] != null && data['foto_url'].toString().isNotEmpty) ...[
                const Text("Foto Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(data['foto_url'], width: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())), errorBuilder: (context, error, stackTrace) => Container(height: 100, color: Colors.grey.shade100, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image, color: Colors.grey), Text("Gagal memuat foto")])))),
              ],
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("TUTUP DETAIL"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: color ?? Colors.grey.shade600), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 14, color: color ?? Colors.black87, fontWeight: FontWeight.w500))]))]));
  }

  @override
  Widget build(BuildContext context) {
    const LatLng centerMedanBaru = LatLng(3.5659, 98.6605);
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText("GIS Medan Baru", style: TextStyle(fontSize: 16)),
        actions: [
          const SupabaseStatusDot(),
          IconButton(icon: const Icon(Icons.refresh), tooltip: "Segarkan Data", onPressed: _fetchLocations),
          IconButton(icon: const Icon(Icons.my_location), tooltip: "Fokus Wilayah", onPressed: () => _mapController.move(centerMedanBaru, 14.0)),
          IconButton(icon: Icon(_showBuffers ? Icons.layers : Icons.layers_clear), onPressed: () => setState(() => _showBuffers = !_showBuffers), tooltip: "Toggle Buffer"),
          IconButton(icon: Icon(_showBoundary ? Icons.crop_square_rounded : Icons.crop_square_outlined), onPressed: () => setState(() => _showBoundary = !_showBoundary), tooltip: "Toggle Batas Wilayah"),
          IconButton(icon: Icon(_showRoads ? Icons.route : Icons.route_outlined), onPressed: () => setState(() => _showRoads = !_showRoads), tooltip: "Toggle Jalan Utama"),
          IconButton(icon: Icon(_showLegend ? Icons.info : Icons.info_outline), onPressed: () => setState(() => _showLegend = !_showLegend), tooltip: "Toggle Legenda"),
        ],
      ),
      body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centerMedanBaru, 
                  initialZoom: 14.0,
                  onTap: (tapPosition, point) {
                    if (_isSearching) {
                      setState(() {
                        _isSearching = false;
                      });
                      _searchFocusNode.unfocus();
                    }
                  },
                ),
                children: [
                  TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'trpl6a.sig.rasyid.sig_bengkel_motor_medan_baru'),
                  if (_showBoundary && _medanBaruBoundary.isNotEmpty)
                    GestureDetector(
                      onTapUp: (details) => _showAreaInfo(),
                      child: PolygonLayer(polygons: [Polygon(points: _medanBaruBoundary, color: const Color(0xFF0F766E).withValues(alpha: 0.1), borderColor: const Color(0xFF0F766E), borderStrokeWidth: 3.0)]),
                    ),
                  if (_showRoads && _roadLines.isNotEmpty) PolylineLayer(polylines: _roadLines),
                  if (_showBuffers && _circles.isNotEmpty) CircleLayer(circles: _circles),
                  if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
                  if (_activeAutoKandidat != null)
                    MarkerLayer(markers: [Marker(point: _activeAutoKandidat!, width: 80, height: 80, child: const Icon(Icons.stars, color: Colors.blueAccent, size: 45, shadows: [Shadow(blurRadius: 10, color: Colors.black26)]))]),
                ],
              ),
              // Floating Search Bar & Results Dropdown
              Positioned(
                top: 16, left: 16, right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Cari bengkel, jalan, atau kategori...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFF97316)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    _searchFocusNode.unfocus();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_isSearching && _filteredLocations.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.98),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredLocations.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final loc = _filteredLocations[index];
                            final String name = loc['nama'] ?? 'Tanpa Nama';
                            final String category = (loc['kategori'] ?? 'N/A').toString().toUpperCase();
                            final String address = loc['jalan'] ?? 'Alamat tidak tersedia';
                            
                            IconData categoryIcon = Icons.location_on;
                            Color categoryColor = const Color(0xFF38BDF8);
                            if (category.toLowerCase() == 'bengkel') {
                              categoryIcon = Icons.build;
                              categoryColor = const Color(0xFFEF4444);
                            } else if (category.toLowerCase() == 'kandidat') {
                              categoryIcon = Icons.stars;
                              categoryColor = const Color(0xFFF97316);
                            } else if (category.toLowerCase() == 'fasum') {
                              categoryIcon = Icons.radar;
                              categoryColor = const Color(0xFF38BDF8);
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: categoryColor.withValues(alpha: 0.1),
                                child: Icon(categoryIcon, color: categoryColor, size: 18),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              dense: true,
                              onTap: () {
                                final dynamic geomData = loc['geometry_json'];
                                if (geomData != null) {
                                  final Map<String, dynamic> geometry = geomData is String ? jsonDecode(geomData) : geomData;
                                  final List<dynamic> coordinates = geometry['coordinates'];
                                  final point = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
                                  
                                  _mapController.move(point, 17.5);
                                  _showLocationDetail(loc);
                                }
                                
                                setState(() {
                                  _searchController.text = name;
                                  _isSearching = false;
                                });
                                _searchFocusNode.unfocus();
                              },
                            );
                          },
                        ),
                      )
                    else if (_isSearching && _filteredLocations.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.98),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: Colors.grey, size: 20),
                            SizedBox(width: 12),
                            Text(
                              "Tidak ada lokasi ditemukan",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_isLoading) LoadingOverlayCard(progress: _loadingProgress, message: _loadingMessage, color: const Color(0xFFF97316)),
              if (_showLegend)
                Positioned(
                  bottom: 20, left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Legenda Analisis GIS", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 20), GestureDetector(onTap: () => setState(() => _showLegend = false), child: const Icon(Icons.close, size: 18, color: Colors.grey))]),
                        const Divider(),
                        _buildLegendItem(Icons.stars, const Color(0xFF10B981), "Kandidat Strategis (Rank 1)"),
                        _buildLegendItem(Icons.stars, const Color(0xFFF59E0B), "Kandidat Potensial (Rank 2-3)"),
                        _buildLegendItem(Icons.build, const Color(0xFFEF4444), "Bengkel Kompetitor"),
                        _buildLegendItem(Icons.radar, const Color(0xFF38BDF8), "Fasilitas Umum (Fasum)"),
                        _buildLegendItem(Icons.circle, Colors.blueGrey.withValues(alpha: 0.4), "Area Jangkauan (Buffer)"),
                        _buildLegendItem(Icons.route, const Color(0xFF1E40AF), "Jaringan Jalan Utama"),
                        _buildLegendItem(Icons.crop_square_rounded, const Color(0xFF0F766E), "Batas Wilayah Medan Baru"),
                      ],
                    ),
                  ),
                ),
              if (_activeAutoKandidat != null && widget.onConfirmSelection != null)
                Positioned(
                  bottom: 20, left: 20, right: 20,
                  child: Card(
                    elevation: 12, shadowColor: Colors.orange.withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFF97316), width: 1)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 20), SizedBox(width: 8), Text("Kandidat Strategis Ditemukan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]), IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _activeAutoKandidat = null))]),
                          const Divider(),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(onPressed: () { final loc = _activeAutoKandidat!; setState(() => _activeAutoKandidat = null); widget.onConfirmSelection!(loc); }, icon: const Icon(Icons.add_location_alt), label: const Text("LANJUT KE INPUT DATA"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12))]));
  }
}
