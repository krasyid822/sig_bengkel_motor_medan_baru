class SawLogic {
  List<Map<String, dynamic>> calculateSAW(
    List<Map<String, dynamic>> rawData, {
    required double wKepadatan,
    required double wHargaSewa,
    required double wJarak,
  }) {
    if (rawData.isEmpty) return [];

    // Mocking SAW Values (c1: Kepadatan, c2: Harga Sewa, c3: Jarak)
    List<Map<String, dynamic>> processed = rawData.map((item) {
      return {
        ...item,
        'c1': 70.0 + (item['nama'].toString().length % 30),
        'c2': 500.0 + (item['jalan'].toString().length * 10),
        'c3': 1.0 + (item['id'].toString().length % 5),
      };
    }).toList();

    // Find Max for Benefit (c1), Min for Cost (c2, c3)
    double maxC1 = processed.map((e) => e['c1'] as double).reduce((a, b) => a > b ? a : b);
    double minC2 = processed.map((e) => e['c2'] as double).reduce((a, b) => a < b ? a : b);
    double minC3 = processed.map((e) => e['c3'] as double).reduce((a, b) => a < b ? a : b);

    for (var item in processed) {
      // Normalization
      double n1 = item['c1'] / maxC1;
      double n2 = minC2 / item['c2'];
      double n3 = minC3 / item['c3'];

      // Final Score
      item['skor'] = (n1 * wKepadatan) + (n2 * wHargaSewa) + (n3 * wJarak);
    }

    processed.sort((a, b) => b['skor'].compareTo(a['skor']));
    return processed;
  }
}
