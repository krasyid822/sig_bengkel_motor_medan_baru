import 'package:flutter/material.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  // Fungsi login dialihkan ke ProfilePage

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const OverflowMarqueeText('Dokumentasi & Panduan Proyek'),
        actions: [
          const SupabaseStatusDot(),
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
            '2. Menu Ranking: Melihat hasil analisis SAW dan navigasi otomatis ke peta. Tersedia fitur "Kandidat Otomatis" untuk menemukan lokasi potensial baru.\n'
            '3. Menu Input: Tambah data via GPS, Geocoding, atau Map Picker.\n'
            '4. Menu CSV/GeoJSON: Manajemen dataset vektor (Admin Only).\n'
            '5. Menu Profil: Login untuk akses fitur Admin & Logout.\n'
            '6. Menu Info: Dokumentasi dan panduan proyek.',
            Icons.menu_book,
          ),

          const SizedBox(height: 12),
          // 4. Integrasi & Sinkronisasi
          _buildHeaderSection("III. Integrasi Web - Mobile"),
          _buildDetailedSection(
            'Konektivitas & API',
            '• REST API: Menggunakan protokol PostgREST untuk akses data berkecepatan tinggi.\n'
            '• Sinkronisasi Realtime: Perubahan data langsung terintegrasi.\n'
            '• Autentikasi RBAC: Sistem berbasis peran menggunakan Supabase Row Level Security (RLS) untuk membedakan hak akses antara pengguna tamu (anon) dan admin (authenticated).',
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
          _buildDetailedSection(
            'Inovasi: Auto-Candidate Discovery',
            'Sistem mengintegrasikan algoritma pemindaian spasial otomatis untuk memitigasi human error dalam penentuan lokasi:\n'
            '• Dynamic Grid Spawning: Mesin PostGIS memecah poligon batas wilayah (Boundary) menjadi ratusan koordinat sampel secara realtime menggunakan fungsi ST_GeneratePoints.\n'
            '• Competitive Conflict Detection: Setiap sampel divalidasi silang terhadap radius buffer bengkel kompetitor (C3). Sampel dalam zona jenuh otomatis dieliminasi.\n'
            '• Infrastructure Proximity Logic: Lokasi yang lolos seleksi diprioritaskan berdasarkan kedekatan akses terhadap jaringan jalan utama (C2).',
            Icons.auto_awesome,
          ),
          _buildDetailedSection(
            'Implementasi pada Dashboard Web',
            'Logika analisis otomatis ini dirancang secara agnostic sehingga dapat diterapkan pada dashboard berbasis web (misalnya Laravel + Leaflet):\n'
            '• Server-Side Logic: Seluruh pemrosesan tetap berada di level Database (PostgreSQL/PostGIS), memastikan hasil yang konsisten antara Mobile dan Web.\n'
            '• API Integration: Web dapat memanggil fungsi RPC "suggest_kandidat_otomatis" yang sama melalui client library Supabase atau REST API.\n'
            '• Visualisasi GeoJSON: Hasil koordinat dari SQL dikonversi menjadi layer GeoJSON dinamis di atas peta Leaflet untuk verifikasi administratif di layar lebar.',
            Icons.web,
          ),

          const SizedBox(height: 12),
          // 6. Penjelasan Teknis & Algoritma (Q&A)
          _buildHeaderSection("V. Tanya Jawab Teknis & Algoritma Spasial"),
          _buildDetailedSection(
            'Bagaimana perhitungan jarak dan pembentukan rekomendasi SAW?',
            '• Perhitungan Jarak Spasial:\n'
            '  Jarak dihitung langsung di level database (server-side) menggunakan fungsi spasial PostGIS ST_Distance(geom1, geom2). Unit derajat secara akurat dipetakan ke satuan meter bumi berdasarkan ellipsoid WGS84.\n\n'
            '• Pembentukan Rekomendasi (Metode SAW):\n'
            '  1. Kriteria C2 (Aksesibilitas): Diukur dari ST_Distance(kandidat, jalan). Bertipe "Cost" (semakin dekat dengan jalan utama semakin optimal).\n'
            '  2. Kriteria C3 (Jarak Pesaing): Diukur dari ST_Distance(kandidat, bengkel_kompetitor). Bertipe "Benefit" (semakin jauh dari kompetitor terdekat semakin optimal untuk meminimalkan persaingan).\n'
            '  3. Kriteria C4 (Status Kemitraan): Berdasarkan boolean is_resmi bengkel (Benefit).\n'
            '  4. Kriteria C5 (Luas Lahan): Berdasarkan luas_lahan fisik kandidat (Benefit).\n\n'
            '• Normalisasi & Skor Akhir:\n'
            '  Seluruh nilai kriteria dinormalisasi otomatis di database sesuai tipenya (cost/benefit) ke rentang 0.0 - 1.0. Skor akhir dihitung dengan menjumlahkan perkalian nilai kriteria yang ternormalisasi dengan bobot masing-masing (C2=40%, C3=30%, C4=15%, C5=15%). Peringkat kelayakan tertinggi diurutkan berdasarkan skor akhir terbesar.',
            Icons.help_outline,
          ),
          _buildDetailedSection(
            'Bagaimana implementasi filter Point-in-Line dan Point-in-Polygon?',
            '• Filter Point-in-Polygon (Titik di dalam Area):\n'
            '  1. Batas Wilayah Administratif: Digunakan untuk menyaring agar lokasi kandidat mutlak berada di dalam area Kecamatan Medan Baru menggunakan fungsi spasial ST_Contains atau ST_Within antara geometri Polygon batas wilayah dengan Point kandidat.\n'
            '  2. Grid Discovery pada Pencarian Otomatis: Fungsi database RPC "suggest_kandidat_otomatis" menggunakan ST_GeneratePoints(polygon, 50) untuk secara cerdas menaburkan titik sampel acak yang dijamin berada di dalam batas administratif poligon.\n\n'
            '• Filter Point-in-Line (Titik ke Garis):\n'
            '  Digunakan dalam perhitungan kriteria C2 (Aksesibilitas) untuk mengukur jarak tegak lurus terpendek dari Point (lokasi kandidat) ke LineString/MultiLineString (jaringan jalan utama) menggunakan fungsi ST_Distance di PostgreSQL.',
            Icons.filter_alt,
          ),
          _buildDetailedSection(
            'Bagaimana penerapan legenda, marker, dan simbologi di peta?',
            '• Simbologi Marker Dinamis (Sesuai Rank & Kategori):\n'
            '  1. Bengkel Kompetitor: Ikon kunci inggris (Icons.build) merah kontras (#EF4444) menandai area persaingan tinggi.\n'
            '  2. Fasilitas Umum (Fasum): Ikon radar (Icons.radar) biru muda (#38BDF8).\n'
            '  3. Kandidat Strategis (Hasil SAW):\n'
            '     - Peringkat 1 (Sangat Strategis): Ikon bintang hijau zamrud (#10B981) + Lencana "RANK 1".\n'
            '     - Peringkat 2-3 (Potensial): Ikon bintang emas (#F59E0B) + Lencana peringkat.\n'
            '     - Peringkat >3 (Kurang Strategis): Ikon bintang oranye (#F97316) + Lencana peringkat.\n\n'
            '• Simbologi Buffer & Vektor:\n'
            '  - Area Buffer: Layer lingkaran transparan di sekitar bengkel kompetitor (radius 500m) dan fasum (radius 200m) untuk menggambarkan jangkauan pasar secara spasial.\n'
            '  - Batas Wilayah: Poligon berwarna hijau toska transparan dengan batas garis luar tegas.\n\n'
            '• Legenda Peta:\n'
            '  Panel legenda apung (Floating Legend) interaktif disematkan di pojok kiri bawah peta untuk memandu pengguna mengenali makna visual dari setiap marker, buffer, jalan utama, dan poligon wilayah.',
            Icons.legend_toggle,
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
            SizedBox(height: 12),
            _TeamMemberRow(name: 'Rasyid Kurniawan', nim: '2305181077', imagePath: 'assets/images/rasyid.jpeg'),
            _TeamMemberRow(name: 'Putri Aprilia', nim: '2305181009', imagePath: ''),
            _TeamMemberRow(name: 'M Rizky Andika', nim: '2305181101', imagePath: ''),
            _TeamMemberRow(name: 'Azura T Barus', nim: '2305181021', imagePath: ''),
            _TeamMemberRow(name: 'Kevin', nim: '2305181097', imagePath: ''),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                ),
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

class _TeamMemberRow extends StatelessWidget {
  final String name;
  final String nim;
  final String? imagePath;

  const _TeamMemberRow({
    required this.name,
    required this.nim,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
            backgroundImage: imagePath != null && imagePath!.isNotEmpty
                ? AssetImage(imagePath!)
                : null,
            child: imagePath == null || imagePath!.isEmpty
                ? const Icon(Icons.person, color: Color(0xFFF97316), size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  nim.isNotEmpty ? nim : 'NIM tidak tersedia',
                  style: TextStyle(
                    color: nim.isNotEmpty ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
