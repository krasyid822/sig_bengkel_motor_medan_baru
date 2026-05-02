import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/saw_logic.dart';

class SawProcessPage extends StatefulWidget {
  const SawProcessPage({super.key});

  @override
  State<SawProcessPage> createState() => _SawProcessPageState();
}

class _SawProcessPageState extends State<SawProcessPage> {
  // Bobot Kriteria
  final double wKepadatan = 0.4;
  final double wHargaSewa = 0.3;
  final double wJarak = 0.3;

  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;

  final LokasiRepository _repository = LokasiRepository();
  final SawLogic _sawLogic = SawLogic();

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate();
  }

  Future<void> _fetchAndCalculate() async {
    setState(() => _isLoading = true);
    try {
      final rawData = await _repository.fetchAllLokasi();
      final processed = _sawLogic.calculateSAW(
        rawData,
        wKepadatan: wKepadatan,
        wHargaSewa: wHargaSewa,
        wJarak: wJarak,
      );

      setState(() {
        _candidates = processed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error SAW: $e");
      if (mounted) setState(() => _isLoading = false);
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
                return [
                  (entry.key + 1).toString(),
                  entry.value['nama'],
                  entry.value['skor'].toStringAsFixed(4)
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proses & Hasil SAW"),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Text("Bobot Kriteria", style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text("Kepadatan: ${(wKepadatan * 100).toInt()}%"),
                              Text("Harga: ${(wHargaSewa * 100).toInt()}%"),
                              Text("Jarak: ${(wJarak * 100).toInt()}%"),
                            ],
                          ),
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
                      return ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(item['nama']),
                        subtitle: Text("Skor Akhir: ${item['skor'].toStringAsFixed(4)}"),
                        trailing: Icon(Icons.stars, color: index == 0 ? Colors.amber : Colors.grey),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
