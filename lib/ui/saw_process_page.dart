import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class SawProcessPage extends StatefulWidget {
  final Function(LatLng, String)? onLocationTap;
  const SawProcessPage({super.key, this.onLocationTap});

  @override
  State<SawProcessPage> createState() => _SawProcessPageState();
}

class _SawProcessPageState extends State<SawProcessPage> {
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _rules = []; // Aturan bobot dari DB
  bool _isLoading = true;

  final LokasiRepository _repository = LokasiRepository();

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate();
  }

  Future<void> _fetchAndCalculate() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Aturan Bobot
      final rules = await _repository.fetchAturan();
      
      // 2. Ambil Data Ranking yang sudah dihitung oleh Supabase
      final processed = await _repository.fetchSawRanking();

      setState(() {
        _rules = rules;
        _candidates = processed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error SAW: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text("Laporan Rekomendasi Lokasi Bengkel (Metode SAW)", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Ranking', 'Nama Lokasi', 'Skor Akhir'],
              data: _candidates.asMap().entries.map((entry) {
                final score = (entry.value['skor_akhir'] ?? 0.0).toDouble();
                return [
                  (entry.key + 1).toString(),
                  entry.value['nama'] ?? '?',
                  score.toStringAsFixed(4)
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _deleteLocation(dynamic id, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Kandidat"),
        content: Text("Apakah Anda yakin ingin menghapus analisis lokasi '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Hapus")
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _repository.deleteLokasi(id);
        
        // Hapus dari state lokal segera agar UI merespon cepat
        setState(() {
          _candidates.removeWhere((item) => 
            item['id'].toString() == id.toString() || 
            item['lokasi_id']?.toString() == id.toString()
          );
        });

        // Refresh data dari server untuk memperbarui ranking/skor kandidat lain
        await _fetchAndCalculate();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data berhasil dihapus.")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranking Pendirian Bengkel"),
        actions: [
          IconButton(onPressed: _generatePdf, icon: const Icon(Icons.picture_as_pdf)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text("🎯 Tujuan: Lokasi Bengkel Baru Terbaik",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const Divider(),
                          const Text("Kalkulasi Otomatis (Metode SAW):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _rules.isEmpty 
                              ? [
                                  const Text("Aturan tidak ditemukan di Database.", 
                                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))
                                ]
                              : _rules
                                  .where((r) => r['tipe_kriteria'] != 'wilayah') // Filter agar Boundary tidak muncul
                                  .map((rule) {
                                    final double bobotPct = (rule['bobot'] as num) * 100;
                                    return _WeightChip(
                                      label: "${rule['kode_kriteria']} ${rule['nama_kriteria']} (${rule['tipe_kriteria']})", 
                                      weight: "${bobotPct.toStringAsFixed(0)}%"
                                    );
                                  }).toList(),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text("*Semakin tinggi Skor Akhir, semakin direkomendasikan.",
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _candidates.length,
                    itemBuilder: (context, index) {
                      final item = _candidates[index];
                      // Pastikan field skor_akhir ada (sesuai View di Supabase)
                      final double score = (item['skor_akhir'] ?? 0.0).toDouble();
                      
                      return ListTile(
                        onTap: () {
                          if (widget.onLocationTap != null && item['geometry_json'] != null) {
                            try {
                              // Parsing dari GeoJSON (geometry_json)
                              final dynamic geomData = item['geometry_json'];
                              final Map<String, dynamic> geometry = geomData is String 
                                  ? jsonDecode(geomData) 
                                  : geomData;
                              
                              final List<dynamic> coordinates = geometry['coordinates'];
                              final double lng = coordinates[0].toDouble();
                              final double lat = coordinates[1].toDouble();
                              
                              final jumpId = (item['lokasi_id'] ?? item['id']).toString();
                              widget.onLocationTap!(LatLng(lat, lng), jumpId);
                            } catch (e) {
                              debugPrint("Error navigating from SAW: $e");
                            }
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: index == 0 ? Colors.amber : Colors.deepPurple[100],
                          child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Skor Akhir: ${score.toStringAsFixed(4)}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index == 0) 
                              const Icon(Icons.stars, color: Colors.amber) 
                            else 
                              const Icon(Icons.location_on_outlined),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                // Log data untuk debug jika masih gagal
                                debugPrint("DEBUG: Data Item Lengkap: $item");
                                
                                // Mencari ID asli tabel (biasanya aliased sebagai lokasi_id, gid, atau tetap id)
                                final deleteId = item['lokasi_id'] ?? item['id'];

                                if (deleteId != null) {
                                  _deleteLocation(deleteId, item['nama'] ?? 'Tanpa Nama');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Gagal: ID data tidak ditemukan."))
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  final String label;
  final String weight;
  const _WeightChip({required this.label, required this.weight});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(weight, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
