import 'package:flutter/material.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumentasi Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            'Tentang Aplikasi',
            'Aplikasi SIG Bengkel Motor Medan Baru digunakan untuk penginputan data lokasi bengkel dan fasilitas umum di wilayah Medan Baru. Data yang dikumpulkan akan disimpan di Supabase dan dapat dipetakan.',
          ),
          _buildSection(
            context,
            'Format Database (Supabase)',
            'Tabel: lokasi\n'
            '- id: uuid (Primary Key)\n'
            '- nama: text\n'
            '- kategori: text (bengkel/fasum)\n'
            '- jalan: text\n'
            '- geom: geometry(Point, 4326)\n'
            '- foto_url: text (URL Bukti Foto)\n'
            '- created_at: timestamptz',
          ),
          _buildSection(
            context,
            'Fitur Unggulan',
            '1. Ambil foto lokasi sebagai bukti fisik.\n'
            '2. Deteksi lokasi via GPS otomatis.\n'
            '3. Bagikan langsung dari Google Maps: Pilih lokasi di Google Maps -> Klik Bagikan -> Pilih aplikasi ini untuk mengisi data secara otomatis.\n'
            '4. Import/Export CSV untuk manajemen data massal.\n'
            '5. Analisis Spasial Terpadu (Buffer & SAW).',
          ),
          _buildSection(
            context,
            'Metode Buffer & SAW (GIS Terpadu)',
            'Sistem ini menggunakan penggabungan dua metode analisis SIG untuk menentukan lokasi bengkel terbaik:\n\n'
            '1. METODE BUFFER (Jangkauan)\n'
            '• Area Strategis (C2): Buffer 200m dari sarana jalan utama.\n'
            '• Area Kompetisi (C3): Buffer 500m dari bengkel pesaing (area merah).\n\n'
            '2. METODE SAW (Perankingan)\n'
            'Melakukan perhitungan skor otomatis dari data GIS dengan bobot seimbang (50% - 50%):\n'
            '• C2 - Jarak ke Jalan (Cost): Makin dekat ke jalan, skor makin tinggi.\n'
            '• C3 - Jarak Pesaing (Benefit): Makin jauh dari pesaing, skor makin tinggi.\n\n'
            'Tujuan: Mencari lokasi kandidat yang memiliki aksesibilitas terbaik namun memiliki persaingan terendah.',
          ),
          _buildSection(
            context,
            'Format Dataset CSV',
            'Jika ingin mengimpor data lewat file, gunakan format berikut:\n'
            'nama,kategori,jalan,longitude,latitude,foto_url,timestamp_utc\n\n'
            'Contoh:\n'
            'Bengkel Sejahtera,bengkel,Jl. Dr. Mansyur,98.66,3.56,https://link-foto.com/a.jpg,2024-05-20T10:00:00Z',
          ),
          _buildSection(
            context,
            'Anggota Kelompok',
            '- Rasyid\n- Putri\n- Rizky\n- Azura\n- Kevin',
          ),
          const SizedBox(height: 20),
          const Divider(),
          const Center(
            child: Text(
              'v1.0.0 - SIG Bengkel Motor',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
