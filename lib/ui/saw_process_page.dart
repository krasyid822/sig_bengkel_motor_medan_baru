import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';

class SawProcessPage extends StatefulWidget {
  const SawProcessPage({super.key});

  @override
  State<SawProcessPage> createState() => _SawProcessPageState();
}

class _SawProcessPageState extends State<SawProcessPage> {
  List<Map<String, dynamic>> _candidates = [];
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
      // Sekarang mengambil data yang sudah dihitung oleh Supabase (View SAW)
      final processed = await _repository.fetchSawRanking();

      setState(() {
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
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text("Bobot Kriteria SAW",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const Divider(),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: const [
                              _WeightChip(label: "C1 Kepadatan", weight: "25%"),
                              _WeightChip(label: "C2 Jarak Jalan", weight: "20%"),
                              _WeightChip(label: "C3 Pesaing", weight: "20%"),
                              _WeightChip(label: "C4 Harga", weight: "15%"),
                              _WeightChip(label: "C5 Luas", weight: "20%"),
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
                      // Pastikan field skor_akhir ada (sesuai View di Supabase)
                      final double score = (item['skor_akhir'] ?? 0.0).toDouble();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0 ? Colors.amber : Colors.deepPurple[100],
                          child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Skor Akhir: ${score.toStringAsFixed(4)}"),
                        trailing: index == 0 
                          ? const Icon(Icons.stars, color: Colors.amber) 
                          : const Icon(Icons.location_on_outlined),
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
