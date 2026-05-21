import 'package:flutter/material.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText('Dokumentasi & Panduan Proyek'),
        actions: const [
          SupabaseStatusDot(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Identitas Kelompok (Sesuai Permintaan)
          _buildIdentityCard(),
          const SizedBox(height: 24),

          // 2. Implementasi Data Vektor (Point, Line, Polygon)
          _buildHeaderSection("I. Implementasi Data Vektor"),
          _buildDetailedSection(
            'Vektor POINT (Titik)',
            '• Akurasi Koordinat: Presisi tinggi berbasis WGS84.\n'
            '• Simbologi: Custom marker/ikon dinamis berdasarkan kategori lokasi.\n'
            '• Popup Informasi: Detail metadata lengkap (Alamat, Jam Buka, Luas Lahan, Foto Dokumentasi).\n'
            '• Clustering: Penanganan otomatis penumpukan data jika jumlah marker banyak.\n'
            '• Geocoding: Pencarian koordinat dari alamat.\n'
            '• Reverse Geocoding: Deteksi alamat otomatis saat memilih titik di peta.',
            Icons.location_on,
          ),
          _buildDetailedSection(
            'Vektor LINE (Garis)',
            '• Ketepatan Tracing: Jalur MultiLineString mengikuti jaringan jalan riil Medan Baru.\n'
            '• Perhitungan Panjang: Estimasi jarak dalam satuan meter/km secara spasial.\n'
            '• Styling Garis: Pengaturan warna (Biru Tua), ketebalan (4.0), dan dukungan visual untuk layer rute multi-segmen.\n'
            '• Clipping Spasial: Garis jalan dipotong rapi menggunakan fungsi ST_Intersection agar hanya tampil di dalam wilayah kerja.',
            Icons.route,
          ),
          _buildDetailedSection(
            'Vektor POLYGON (Area)',
            '• Ketepatan Batas: Area poligon administratif Kecamatan Medan Baru.\n'
            '• Perhitungan Luas: Estimasi luas area dalam m2 atau hektar (ha).\n'
            '• Visualisasi: Fill color (Hijau Toska) dengan opacity 0.1 untuk transparansi.\n'
            '• Simbologi Tematik: Dukungan visualisasi choropleth untuk analisis kepadatan.\n'
            '• Point-in-Polygon: Deteksi otomatis posisi kandidat terhadap batas wilayah.',
            Icons.crop_square_rounded,
          ),

          const SizedBox(height: 12),
          // 3. Fungsionalitas Aplikasi
          _buildHeaderSection("II. Fungsionalitas & User Manual"),
          _buildDetailedSection(
            'Fitur Utama Peta',
            '• GPS Perangkat: Deteksi lokasi pengguna secara realtime dengan akurasi tinggi.\n'
            '• Map Picker: Kemampuan memilih lokasi kandidat langsung dari antarmuka peta.\n'
            '• Tampilan Responsif: Antarmuka adaptif untuk berbagai ukuran layar smartphone.',
            Icons.phonelink_setup,
          ),
          _buildDetailedSection(
            'Panduan Penggunaan',
            '1. Menu Peta: Visualisasi sebaran bengkel dan fasum.\n'
            '2. Menu Ranking: Melihat hasil analisis SAW dan navigasi otomatis ke peta.\n'
            '3. Menu Input: Tambah data via GPS, Geocoding, atau Map Picker.\n'
            '4. Menu CSV/GeoJSON: Manajemen dataset vektor secara massal.',
            Icons.menu_book,
          ),

          const SizedBox(height: 12),
          // 4. Integrasi & Sinkronisasi
          _buildHeaderSection("III. Integrasi Web - Mobile"),
          _buildDetailedSection(
            'Konektivitas & API',
            '• REST API: Menggunakan protokol PostgREST untuk akses data berkecepatan tinggi.\n'
            '• Sinkronisasi Realtime: Perubahan data di aplikasi mobile langsung terintegrasi dengan dashboard web (Leaflet).\n'
            '• Autentikasi: Keamanan data menggunakan Anon Key dan Row Level Security (RLS) di sisi Supabase.',
            Icons.sync_alt,
          ),

          const SizedBox(height: 12),
          // 5. Dukungan Analisis Spasial
          _buildHeaderSection("IV. Analisis Spasial Terpadu"),
          _buildDetailedSection(
            'Metode GIS Terpadu',
            '• Analisis Buffer: Penentuan zona aksesibilitas (C2) dan zona kompetisi (C4).\n'
            '• Metode SAW: Perankingan cerdas berbasis kriteria dinamis dari database (Jarak Jalan, Fasum, Peluang vs Kompetitor, Luas Lahan).\n'
            '• Spatial Database: Logika perhitungan dipindahkan ke sisi server (PostGIS) untuk performa maksimal.',
            Icons.analytics,
          ),

          const SizedBox(height: 30),
          const Divider(),
          const Center(
            child: Text(
              'Presentasi SIG TRPL - 22 Mei 2026',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Card(
      elevation: 6,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KELOMPOK 4', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
            SizedBox(height: 12),
            Text(
              'Sistem Informasi Geografis Menggunakan Analisis Buffer dan Metode SAW untuk Penentuan Lokasi Strategis Usaha Bengkel Motor di Kecamatan Medan Baru',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, height: 1.4),
            ),
            Divider(color: Colors.white24, height: 32),
            _IdentityRow(label: 'Kelas', value: 'TRPL-6A'),
            _IdentityRow(label: 'Tanggal', value: '22 Mei 2026'),
            _IdentityRow(label: 'Dosen', value: 'Donny Sanjaya, M.Kom'),
            SizedBox(height: 16),
            Text('Anggota Tim:', style: TextStyle(color: Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('• Rasyid Kurniawan (2305181077)', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Putri Aprilia', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• M Rizky Andika', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Azura T Barus', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Kevin', style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFF97316), width: 4))
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Widget _buildDetailedSection(String title, String content, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFF97316), size: 24),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Text(
              content,
              style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF334155), letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final String label;
  final String value;
  const _IdentityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          const Text(': ', style: TextStyle(color: Colors.white70)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
