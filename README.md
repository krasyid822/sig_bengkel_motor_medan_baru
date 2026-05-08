# sig_bengkel_motor_medan_baru

Aplikasi penginputan data dan untuk penampil map. anggota kelompok; rasyid, putri, rizky, azura, kevin

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Format Database di Supabase

CREATE TABLE lokasi (
id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
nama text NOT NULL,
kategori text CHECK (kategori IN ('bengkel', 'fasum', 'kandidat')),
jalan text,
geom geometry(Point, 4326) NOT NULL,
foto_url text,
created_at timestamptz DEFAULT now()
);

-- Tabel Aturan (Buffer & SAW)
CREATE TABLE aturan_sig (
    id serial PRIMARY KEY,
    kode_kriteria text UNIQUE, -- C1, C2, C3, dll
    nama_kriteria text,
    bobot numeric, -- 0.5 (50%)
    radius_buffer integer, -- 200, 500
    tipe_kriteria text -- cost/benefit
);

INSERT INTO aturan_sig (kode_kriteria, nama_kriteria, bobot, radius_buffer, tipe_kriteria) VALUES
('C2', 'Aksesibilitas', 0.5, 200, 'cost'),
('C3', 'Jarak Pesaing', 0.5, 500, 'benefit'),
('BOUNDARY', '[[3.584883, 98.653078], [3.584095338570799, 98.66784569392829], [3.546981822889294, 98.65923996108863], [3.5469941868443997, 98.65213610608484]]', 0, 0, 'wilayah');

### Penting: Konfigurasi Row Level Security (RLS)
Agar aplikasi dapat membaca tabel `aturan_sig` melalui API/Anon Key, Anda **WAJIB** mengatur Policies di Dashboard Supabase:
1. Masuk ke **Authentication > Policies**.
2. Pilih tabel `aturan_sig`.
3. Klik **New Policy** > **Create a policy from scratch**.
4. Pilih **Allowed Operation: SELECT**.
5. Pilih **Target Roles: anon**.
6. Pada bagian **Using expression**, masukkan: `true`.
7. Klik **Save Policy**.

*Lakukan hal yang sama (SELECT & INSERT) untuk tabel `lokasi` agar data dapat tersimpan.*

# Format Dataset CSV

nama,kategori,jalan,longitude,latitude,timestamp_utc

# Buffer and SAW rules

### 1. Data Core (GIS)
* **Data Lokasi:** Kandidat bengkel, bengkel eksisting (kompetitor), dan jalan utama Medan Baru.
* **Data Wilayah:** Batas wilayah Medan Baru (Polygon), data jalan, dan fasilitas umum (SPBU, pajak, kampus, permukiman).

### 2. Aturan Buffer (Jarak Jangkauan)
* **Akses & Fasum (C2):** 200 meter.
* **Bengkel Lain/Pesaing (C3):** 500 meter.

### 3. Kriteria SAW (Simple Additive Weighting)
*Catatan: Saat ini sistem menggunakan bobot GIS Terpadu (C2 & C3) untuk kalkulasi otomatis.*

| Kode | Kriteria | Bobot (Final) | Jenis | Status |
|------|----------|---------------|-------|--------|
| C1 | Kepadatan Penduduk | - | Benefit | Placeholder |
| C2 | Aksesibilitas Lokasi | 50% | Cost | Active (GIS) |
| C3 | Jarak Pesaing | 50% | Benefit | Active (GIS) |
| C4 | Harga Sewa Tempat | - | Cost | Placeholder |
| C5 | Luas Lahan | - | Benefit | Placeholder |

*Note: C2 dihitung berdasarkan kedekatan titik kandidat dengan titik akses jalan atau fasilitas umum pendukung.*

### 4. Output Sistem
* Perankingan lokasi terbaik untuk pendirian bengkel baru.
* Visualisasi peta dengan layer buffer area dan marker kompetitor/fasum.

### 5. Catatan Pengembangan & Fitur Masa Depan
*   **Otomasi Buffer & SAW (Backend Sync):** Sistem telah diperbarui untuk membaca kriteria langsung dari tabel `aturan_sig`. Pastikan View di database menggunakan subquery ke tabel ini agar sinkronisasi 100% otomatis.
*   **Keamanan Hitungan Database:** Query View `v_rekomendasi_bengkel_saw` secara spesifik memanggil `WHERE kode_kriteria = 'C2'` dan `'C3'`. Jadi, meskipun ada banyak baris baru di tabel `aturan_sig` (seperti data `BOUNDARY`), hitungan SAW di database tidak akan berubah kecuali Anda mengubah Query SQL-nya.
*   **Optimasi Kategori Spasial:** Memisahkan input "Akses Jalan" (Line/Point Road) dengan "Fasilitas Umum" (Point Interest) agar analisis C2 lebih spesifik pada aksesibilitas transportasi.
*   **Data Dinamis C1, C4, C5:** Integrasi API kependudukan atau form input manual untuk melengkapi kriteria non-GIS.
*   **Pengembangan Layer Spasial:** Menambahkan layer buffer untuk area permukiman (target 300 meter) sebagai pendukung kriteria C1 (Kepadatan Penduduk) di masa depan.

# Web Leaflet Connection Guide (Laravel)

Untuk menghubungkan dashboard web Laravel ke database Supabase yang sama dengan aplikasi mobile, ikuti langkah berikut:

### 1. Persiapan Environment
Tambahkan kredensial Supabase ke file `.env` Laravel Anda:
```env
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

### 2. Pengambilan Data di Controller
Gunakan HTTP Client Laravel untuk mengambil data dari View `v_lokasi_peta` yang sudah disiapkan:

```php
use Illuminate\Support\Facades\Http;

public function index()
{
    $url = env('SUPABASE_URL') . '/rest/v1/v_lokasi_peta';
    
    $response = Http::withHeaders([
        'apikey' => env('SUPABASE_ANON_KEY'),
        'Authorization' => 'Bearer ' . env('SUPABASE_ANON_KEY'),
    ])->get($url);

    $lokasi = $response->json();

    return view('dashboard', compact('lokasi'));
}
```

### 3. Integrasi Leaflet di Blade Template
Di dalam file `dashboard.blade.php`, terima data JSON dan tampilkan di peta:

```html
<div id="map" style="height: 500px;"></div>

<script>
    var map = L.map('map').setView([3.5952, 98.6638], 14);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    // Data dari Laravel Controller
    var dataLokasi = @json($lokasi);

    dataLokasi.forEach(function(item) {
        if (item.geometry_json) {
            var coords = [
                item.geometry_json.coordinates[1], 
                item.geometry_json.coordinates[0]
            ];
            
            var markerColor = item.kategori === 'kandidat' ? 'gold' : 'red';
            
            L.marker(coords).addTo(map)
                .bindPopup(`<b>${item.nama}</b><br>Kategori: ${item.kategori}`);
        }
    });
</script>
```

### 4. Tips Keamanan & Performa
*   **Caching:** Karena data spasial cenderung statis, gunakan `Cache::remember` di Laravel untuk menyimpan respon Supabase selama beberapa menit guna mempercepat loading page.
*   **PostGIS:** Tetap gunakan View `v_lokasi_peta` di Supabase agar Laravel menerima koordinat dalam format JSON yang bersih, bukan string WKT yang sulit di-parse.
*   **CORS:** Jika Anda memanggil Supabase langsung dari JavaScript (Vite/Mix), pastikan domain web Anda sudah didaftarkan di dashboard Supabase (Authentication > Settings > Allow List).

