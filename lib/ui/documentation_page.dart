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
            'Fitur Unggulan',
            '1. Ambil foto lokasi sebagai bukti fisik.\n'
            '2. Deteksi lokasi via GPS otomatis dengan akurasi tinggi.\n'
            '3. Pencarian Koordinat otomatis berdasarkan Alamat Lengkap (Geocoding).\n'
            '4. Input Koordinat Manual (Latitude & Longitude) untuk fleksibilitas data.\n'
            '5. Import/Export CSV untuk manajemen data massal.\n'
            '6. Analisis Spasial Terpadu (Buffer & SAW).',
          ),
          _buildSection(
            context,
            'Konektivitas Flutter & Supabase',
            'Aplikasi terhubung ke Supabase melalui Supabase SDK dengan integrasi PostGIS:\n\n'
            '1. VEKTOR POINT (Tabel lokasi): Input via GPS/Manual disimpan sebagai geometry(Point, 4326). Digunakan untuk Bengkel, Fasum, dan Kandidat.\n'
            '2. VEKTOR LINE (Tabel jalan_utama): Input via GPS Auto-Tracking atau Manual Vertex disimpan sebagai geometry(LineString, 4326).\n'
            '3. VEKTOR POLYGON (Tabel wilayah_kecamatan): Batas wilayah disimpan sebagai geometry(Polygon, 4326) dan diambil via RPC get_wilayah_geojson.\n'
            '4. BUFFER OTOMATIS: Dihitung di sisi database melalui SQL View v_lokasi_buffer menggunakan referensi radius dinamis dari tabel aturan_sig.\n'
            '5. SAW PERANGKINGAN: Proses normalisasi dan pembobotan dilakukan otomatis di database melalui SQL View v_rekomendasi_bengkel_saw yang menghitung jarak spasial antar objek secara realtime.',
          ),
          _buildSection(
            context,
            'Format Dataset CSV (GIS Full Vector)',
            'Gunakan format kolom berikut untuk impor data massal:\n\n'
            '• Untuk POINT: nama, kategori, jalan, longitude, latitude, foto_url\n'
            '• Untuk LINE: nama, kategori, geom (Isi dengan format WKT: LINESTRING(lng lat, lng lat, ...))\n\n'
            'Contoh baris JALAN:\n'
            'Jl. Jamin Ginting, jalan, "LINESTRING(98.66 3.56, 98.67 3.57)"',
          ),
          _buildSection(
            context,
            'Metode Buffer & SAW (GIS Terpadu)',
            'Sistem ini menggunakan penggabungan dua metode analisis SIG untuk menentukan lokasi bengkel terbaik:\n\n'
            '1. METODE BUFFER (Jangkauan)\n'
            '• Area Aksesibilitas (C2): Radius dinamis dari LineString jalan utama.\n'
            '• Area Kompetisi (C3): Radius dinamis dari Point bengkel pesaing.\n\n'
            '2. METODE SAW (Perankingan)\n'
            'Melakukan perhitungan skor otomatis dari data GIS dengan bobot dinamis sesuai database:\n'
            '• C2 - Aksesibilitas (Cost): Jarak ke garis jalan (makin dekat makin baik).\n'
            '• C3 - Jarak Pesaing (Benefit): Jarak antar titik bengkel (makin jauh makin baik).\n\n'
            'PENTING: Bobot dan radius diambil secara realtime dari tabel aturan_sig. Jika aturan di database diubah, hasil ranking dan visualisasi peta akan otomatis menyesuaikan (Dynamic GIS).',
          ),
          _buildSection(
            context,
            'Kemampuan Analisis Spasial (SDSS)',
            'Aplikasi ini berfungsi sebagai Spatial Decision Support System (SDSS) dengan kemampuan:\n\n'
            '1. Proximity Analysis: Perhitungan jarak presisi menggunakan engine PostGIS (ST_Distance) antara Point-to-Line dan Point-to-Point.\n'
            '2. Spatial Multi-Criteria Decision Making: Integrasi hasil analisis spasial ke dalam algoritma SAW untuk pengambilan keputusan lokasi.\n'
            '3. Spatial Overlay: Visualisasi tumpang susun layer Polygon, Line, dan Point untuk analisis visual area strategis.\n'
            '4. Automated GIS: Pemrosesan data spasial otomatis melalui SQL Views setiap kali ada pembaruan data lokasi.',
          ),
          _buildSection(
            context,
            'Format Dataset CSV (GIS Full Vector)',
            'Gunakan format kolom berikut untuk impor data massal:\n\n'
            '• Untuk POINT: nama, kategori, jalan, longitude, latitude, foto_url\n'
            '• Untuk LINE: nama, kategori, geom (Isi dengan format WKT: LINESTRING(lng lat, lng lat, ...))\n\n'
            'Contoh baris JALAN:\n'
            'Jl. Jamin Ginting, jalan, "LINESTRING(98.66 3.56, 98.67 3.57)"',
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
