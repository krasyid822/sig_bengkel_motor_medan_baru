import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class MapDashboardPage extends StatefulWidget {
  const MapDashboardPage({super.key});

  @override
  State<MapDashboardPage> createState() => _MapDashboardPageState();
}

class _MapDashboardPageState extends State<MapDashboardPage> {
  final MapController _mapController = MapController();
  final LokasiRepository _repository = LokasiRepository();
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];
  bool _isLoading = true;
  bool _showBuffers = true;
  bool _showBoundary = true;

  // Koordinat Batas Wilayah Medan Baru (Sederhana)
  final List<LatLng> _medanBaruBoundary = [
    const LatLng(3.5950, 98.6510),
    const LatLng(3.6030, 98.6530),
    const LatLng(3.6055, 98.6555),
    const LatLng(3.6040, 98.6590),
    const LatLng(3.6015, 98.6645),
    const LatLng(3.5985, 98.6695),
    const LatLng(3.5910, 98.6710),
    const LatLng(3.5850, 98.6700),
    const LatLng(3.5760, 98.6670),
    const LatLng(3.5680, 98.6630),
    const LatLng(3.5665, 98.6580),
    const LatLng(3.5690, 98.6520),
    const LatLng(3.5750, 98.6480),
    const LatLng(3.5820, 98.6465),
    const LatLng(3.5890, 98.6475),
    const LatLng(3.5950, 98.6510), // Tutup polygon
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final data = await _repository.fetchRekomendasiLokasi();
      
      setState(() {
        _markers = [];
        _circles = [];
        
        for (var item in data) {
          if (item['geometry'] == null) continue;

          // Parsing GeoJSON geometry
          final Map<String, dynamic> geometry = item['geometry'] is String 
              ? jsonDecode(item['geometry']) 
              : item['geometry'];
          
          final List<dynamic> coordinates = geometry['coordinates'];
          final double long = coordinates[0].toDouble();
          final double lat = coordinates[1].toDouble();
          final point = LatLng(lat, long);

          // Marker
          Color markerColor = Colors.blue;
          IconData markerIcon = Icons.location_on;
          double bufferRadius = 0;
          Color bufferColor = Colors.blue.withValues(alpha: 0.2);

          if (item['kategori'] == 'bengkel') {
            markerColor = Colors.red;
            markerIcon = Icons.settings_applications;
            bufferRadius = 500; // Aturan README: Bengkel 500m
            bufferColor = Colors.red.withValues(alpha: 0.2);
          } else {
            // Cek sub-kategori berdasarkan nama/jalan untuk Fasum
            String nama = (item['nama'] ?? '').toString().toLowerCase();
            if (nama.contains('jalan')) {
              markerColor = Colors.orange;
              bufferRadius = 200; // Aturan README: Jalan Utama 200m
              bufferColor = Colors.orange.withValues(alpha: 0.2);
            } else if (nama.contains('permukiman') || nama.contains('perumahan')) {
              markerColor = Colors.green;
              bufferRadius = 300; // Aturan README: Permukiman 300m
              bufferColor = Colors.green.withValues(alpha: 0.2);
            }
          }

          _markers.add(
            Marker(
              point: point,
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _showLocationDetail(item),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    markerIcon,
                    color: markerColor,
                    size: 30,
                  ),
                ),
              ),
            ),
          );

          // Radius (Buffer) sesuai aturan README
          if (bufferRadius > 0) {
            _circles.add(
              CircleMarker(
                point: point,
                radius: bufferRadius,
                useRadiusInMeter: true,
                color: bufferColor,
                borderColor: markerColor,
                borderStrokeWidth: 1,
              ),
            );
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching map data: $e");
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
    const LatLng centerMedanBaru = LatLng(3.5952, 98.6638);
    
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
                      const Text("Legenda GIS", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      _buildLegendItem(Icons.settings_applications, Colors.red, "Bengkel/Pesaing (500m)"),
                      _buildLegendItem(Icons.location_on, Colors.orange, "Jalan Utama (200m)"),
                      _buildLegendItem(Icons.location_on, Colors.green, "Permukiman (300m)"),
                      _buildLegendItem(Icons.location_on, Colors.blue, "Fasilitas Umum Lain"),
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
