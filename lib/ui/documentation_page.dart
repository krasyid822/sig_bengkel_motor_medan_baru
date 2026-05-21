import 'package:flutter/material.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText('Dokumentasi Aplikasi'),
        actions: const [
          SupabaseStatusDot(),
        ],
      ),
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
            '5. Import/Export CSV untuk data point.\n'
            '6. Import GeoJSON untuk boundary wilayah Medan Baru.\n'
            '7. Analisis Spasial Terpadu (Buffer & SAW).',
          ),
          _buildSection(
            context,
            'Konektivitas Flutter & Supabase',
            'Aplikasi terhubung ke Supabase melalui Supabase SDK dengan integrasi PostGIS:\n\n'
            '1. VEKTOR POINT (Tabel lokasi): Input via GPS/Manual disimpan sebagai geometry(Point, 4326). Digunakan untuk Bengkel, Fasum, dan Kandidat.\n'
            '2. VEKTOR LINE (View v_namajalan_utama): Data jaringan jalan wilayah Medan Baru yang sudah di-clip otomatis di dalam boundary.\n'
            '3. VEKTOR POLYGON (BOUNDARY di aturan_sig): Batas wilayah Medan Baru diunggah melalui menu GeoJSON dan disimpan sebagai koordinat boundary.\n'
            '4. SAW PERANGKINGAN: Proses normalisasi dan pembobotan dilakukan otomatis di database melalui SQL View v_rekomendasi_bengkel_saw yang menghitung jarak spasial antar objek secara realtime.',
          ),
          _buildSection(
            context,
            'Format Dataset CSV (Point)',
            'Gunakan format kolom berikut untuk impor data massal:\n\n'
            '• Untuk POINT: nama, kategori, jalan, longitude, latitude, foto_url, waktu_buka, waktu_tutup, hari_libur, is_resmi, luas_lahan\n\n'
            'Contoh baris POINT:\n'
            'Bengkel ABC, bengkel, Jl. Dr. Mansyur No. 1, 98.654321, 3.567890, https://..., 08:00, 17:00, Minggu, true, 150',
          ),
          _buildSection(
            context,
            'Format Dataset GeoJSON',
            'Gunakan menu GeoJSON untuk data vektor:\n\n'
            '• Polygon/MultiPolygon: polygon pertama akan dipakai sebagai boundary Medan Baru.',
          ),
          _buildSection(
            context,
            'Cara Mendapatkan GeoJSON Batas Wilayah',
            'Boundary Medan Baru bisa diambil dari layanan polygon OpenStreetMap:\n\n'
            '• Link langsung:\n'
            'http://polygons.openstreetmap.fr/get_geojson.py?id=9522401\n\n'
            '• Penjelasan: link tersebut menghasilkan GeoJSON boundary dari OSM relation ID 9522401.\n'
            '• Cara pakai: buka link di browser, simpan hasilnya sebagai file `.geojson` atau `.json`, lalu unggah lewat menu GeoJSON.\n'
            '• Catatan: gunakan file ini khusus untuk batas wilayah.',
          ),
          _buildSection(
            context,
            'Metode Buffer & SAW (GIS Terpadu)',
            'Sistem ini menggunakan penggabungan dua metode analisis SIG untuk menentukan lokasi bengkel terbaik:\n\n'
            '1. METODE BUFFER (Jangkauan)\n'
            '• Area Aksesibilitas (C2): Radius 200m dari garis jalan utama.\n'
            '• Area Kompetisi (C3): Radius 500m dari titik bengkel pesaing.\n\n'
            '2. METODE SAW (Perankingan)\n'
            'Menghitung skor otomatis dengan bobot dinamis dari database:\n'
            '• C2 - Aksesibilitas (Cost): Jarak ke jalan utama. Menggunakan rumus MIN/VAL (Makin dekat jalan, skor makin mendekati 1.0).\n'
            '• C3 - Jarak Pesaing (Benefit): Jarak ke kompetitor terdekat. Menggunakan rumus VAL/MAX (Makin jauh dari pesaing, skor makin tinggi untuk menghindari kejenuhan pasar).\n'
            '• C4 - Status Resmi (Benefit): Lokasi yang direncanakan sebagai bengkel resmi mendapat skor prioritas.\n'
            '• C5 - Luas Lahan (Benefit): Lokasi dengan luas lahan lebih besar mendapat preferensi lebih tinggi.\n\n'
            'PENTING: Semua perhitungan dilakukan di sisi server (PostgreSQL/PostGIS) melalui View v_rekomendasi_bengkel_saw untuk menjaga akurasi spasial.',
          ),
          _buildSection(
            context,
            'Logika SQL & Spasial (Backend)',
            'Aplikasi ini memanfaatkan fungsi engine PostGIS untuk perhitungan realtime:\n\n'
            '1. ST_Distance: Menghitung jarak Euclidean (garis lurus) presisi antara koordinat GPS kandidat dengan objek GIS lainnya.\n'
            '2. Geography Cast: Konversi koordinat (4326) ke meter agar hasil jarak akurat dalam satuan metrik.\n'
            '3. Dynamic Normalization: Skor dinormalisasi secara otomatis (0.0 - 1.0) berdasarkan nilai tertinggi/terendah dari seluruh kandidat yang ada di database.\n'
            '4. Spatial Clipping: Garis jalan dipotong otomatis tepat pada batas wilayah Medan Baru menggunakan fungsi ST_Intersection.',
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
              'v1.1.0 - SIG Bengkel Motor',
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
                    color: const Color(0xFFF97316),
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
