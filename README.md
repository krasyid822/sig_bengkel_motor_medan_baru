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

Web App: https://github.com/krasyid822/gis-bengkel

# Format Database di Supabase

```sql
CREATE TABLE lokasi (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nama text NOT NULL,
    kategori text CHECK (kategori IN ('bengkel', 'fasum', 'kandidat')),
    jalan text,
    geom geometry(Point, 4326) NOT NULL,
    foto_url text,
    waktu_buka time,
    waktu_tutup time,
    hari_libur text,
    is_resmi boolean DEFAULT false,
    luas_lahan numeric DEFAULT 0, -- Kriteria C5
    created_at timestamptz DEFAULT now()
);

-- Tabel Aturan (Metode SAW & Buffer)
CREATE TABLE aturan_sig (
    id serial PRIMARY KEY,
    kode_kriteria text UNIQUE, -- C2, C3, C4, C5, BOUNDARY
    nama_kriteria text,
    bobot numeric, -- 0.4 (40%)
    radius_buffer integer, -- 200, 500
    tipe_kriteria text -- cost/benefit
);

INSERT INTO aturan_sig (kode_kriteria, nama_kriteria, bobot, radius_buffer, tipe_kriteria) VALUES
('C2', 'Aksesibilitas', 0.4, 200, 'cost'),
('C3', 'Jarak Pesaing', 0.3, 500, 'benefit'),
('C4', 'Status Resmi', 0.15, 0, 'benefit'),
('C5', 'Luas Lahan', 0.15, 0, 'benefit'),
('BOUNDARY', '[]', 0, 0, 'wilayah');
```

### Penting: Konfigurasi Row Level Security (RLS)
Sistem ini menggunakan autentikasi berbasis peran (Role-Based Access) melalui Supabase RLS untuk menjamin keamanan data:

1. **Akses Publik (anon)**:
   - **Tabel `aturan_sig`**: `SELECT` diizinkan agar semua pengguna dapat melihat bobot analisis SAW.
   - **Tabel `lokasi`**: `SELECT`, `INSERT`, dan `DELETE` diizinkan. Ini memungkinkan pengguna (termasuk tamu) untuk menginput data kandidat dan menghapus analisis mereka sendiri tanpa harus login.

2. **Akses Terbatas (Admin/Authenticated)**:
   - Jika Anda ingin membatasi fitur tertentu (seperti unggah CSV/GeoJSON atau modifikasi data bengkel resmi) hanya untuk Admin, tambahkan kebijakan RLS dengan kondisi: `auth.uid() IS NOT NULL` atau `auth.jwt() ->> 'role' = 'authenticated'`.

3. **Cara Konfigurasi**:
   - Masuk ke **Authentication > Policies** di Dashboard Supabase.
   - Pilih tabel terkait, lalu buat atau sesuaikan policy untuk operasi `SELECT`, `INSERT`, atau `DELETE`.
   - Pastikan Role **anon** diberikan izin yang sesuai.

# Format Dataset CSV (Point)

`nama,kategori,jalan,longitude,latitude,foto_url,waktu_buka,waktu_tutup,hari_libur,is_resmi,luas_lahan`

# Buffer and SAW rules

### 1. Data Core (GIS)
* **Data Lokasi:** Kandidat bengkel, bengkel eksisting (kompetitor), dan Fasilitas Umum (Fasum).
* **Data Wilayah:** Batas wilayah Medan Baru (Polygon) dan data jaringan jalan (MultiLineString di view `v_namajalan_utama`).

### 2. Aturan Buffer (Jarak Jangkauan)
* **Akses & Fasum (C2):** 200 meter.
* **Bengkel Lain/Pesaing (C3):** 500 meter.

### 3. Kriteria SAW (Simple Additive Weighting)
*Catatan: Sistem menggunakan bobot GIS Terpadu untuk kalkulasi otomatis.*

| Kode | Kriteria | Bobot | Jenis | Status | Atribut Database |
|------|----------|---------------|-------|--------|------------------|
| C2 | Aksesibilitas Lokasi | 40% | Cost | Active | `ST_Distance(geom, jalan)` |
| C3 | Jarak Pesaing | 30% | Benefit | Active | `ST_Distance(geom, kompetitor)` |
| C4 | Status Resmi | 15% | Benefit | Active | `is_resmi` |
| C5 | Luas Lahan | 15% | Benefit | Active | `luas_lahan` |

### 4. Output Sistem
* Perankingan lokasi terbaik untuk pendirian bengkel baru dengan navigasi otomatis ke peta.
* Visualisasi peta dengan layer buffer area dan clipping otomatis garis jalan di dalam boundary.

# Panduan Penggunaan
1. **Menu Peta**: Visualisasi data spasial (Bengkel, Fasum, Kandidat).
2. **Menu Ranking**: Analisis kelayakan lokasi menggunakan metode SAW.
3. **Menu Input**: Pengumpulan data lapangan dengan integrasi GPS.
4. **Menu CSV/GeoJSON**: Manajemen data masal (Hanya Admin).
5. **Menu Profil**: Manajemen akun (Login/Logout).
6. **Menu Info**: Dokumentasi dan panduan proyek.
7. **Kandidat Otomatis**: Inovasi sistem yang menggunakan algoritma pemindaian spasial cerdas melalui fungsi `suggest_kandidat_otomatis` (RPC Supabase). Sistem memproses penentuan lokasi dengan tahapan:
   - **Dynamic Grid Spawning**: Menggunakan `ST_GeneratePoints` untuk memecah `BOUNDARY` wilayah menjadi koordinat sampel acak secara realtime.
   - **Conflict Detection**: Memvalidasi jarak sampel terhadap bengkel kompetitor (radius buffer C3) menggunakan `ST_DWithin`.
   - **Optimization**: Memberikan rekomendasi lokasi yang terbebas dari zona jenuh kompetisi namun tetap berada dalam cakupan administratif yang valid.

# Web Implementation Guide (Laravel + Leaflet)

Implementasi pada Laravel dapat dilakukan melalui dua cara: **Client-Side (JS)** untuk responsivitas tinggi, atau **Server-Side (PHP)** untuk keamanan dan pemrosesan data di backend.

### 1. Konfigurasi Environment (.env)
Tambahkan kredensial Supabase ke file `.env` Laravel Anda:
```env
SUPABASE_URL=https://xyz.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 2. Implementasi Backend (Controller PHP)
Gunakan Laravel `Http` Facade untuk memanggil fungsi analisis dari server:

```php
use Illuminate\Support\Facades\Http;

class GisController extends Controller
{
    public function getKandidatOtomatis()
    {
        $response = Http::withHeaders([
            'apikey' => env('SUPABASE_ANON_KEY'),
            'Authorization' => 'Bearer ' . env('SUPABASE_ANON_KEY'),
        ])->post(env('SUPABASE_URL') . '/rest/v1/rpc/suggest_kandidat_otomatis');

        return $response->json();
    }
}
```

### 3. Implementasi Frontend (Blade + Leaflet)
Tangkap data dari Controller dan plot ke peta menggunakan Leaflet:

```javascript
// Memanggil internal API Laravel Anda
fetch('/api/gis/kandidat-otomatis')
    .then(res => res.json())
    .then(data => {
        data.forEach(point => {
            L.marker([point.lat, point.lng], {
                icon: L.icon({ iconUrl: '/marker-auto.png' })
            }).addTo(map)
            .bindPopup(`<b>Kandidat Strategis</b><br>Skor: ${point.score}`);
        });
    });
```

### 4. Keunggulan Integrasi Laravel
*   **Unified Logic**: Laravel hanya bertindak sebagai jembatan; logika spasial tetap aman dan konsisten di sisi PostGIS.
*   **Security**: Anda dapat membungkus *request* Supabase di dalam *middleware* Laravel untuk memastikan hanya pengguna terautentikasi yang bisa memicu fitur analisis.
*   **Scalability**: Data hasil analisis otomatis dapat langsung digabungkan dengan data relasional lain yang ada di database MySQL/PostgreSQL lokal Laravel Anda.


# Implementasi Teknis Kandidat Otomatis (Database RPC)

Fitur **Kandidat Otomatis** tidak menggunakan tabel statis, melainkan fungsi dinamis (Stored Procedure) di level database. Berikut adalah langkah teknis implementasinya:

### 1. Script SQL (Supabase Functions)
Jalankan script ini di **SQL Editor** Supabase untuk membuat "Mesin Pencari" lokasi:

```sql
CREATE OR REPLACE FUNCTION suggest_kandidat_otomatis()
RETURNS TABLE (nama text, lat float, lng float, score float) AS $$
DECLARE
    v_boundary_json jsonb;
    v_boundary_geom geometry;
    v_radius_pesaing float;
BEGIN
    -- 1. Ambil Radius Pesaing (C3) dari tabel aturan_sig secara otomatis
    SELECT radius_buffer::float INTO v_radius_pesaing 
    FROM aturan_sig WHERE kode_kriteria = 'C3';

    -- 2. Ambil data JSON Koordinat dari tabel aturan_sig
    SELECT nama_kriteria::jsonb INTO v_boundary_json 
    FROM aturan_sig WHERE kode_kriteria = 'BOUNDARY';

    -- 3. Membangun Geometri Polygon yang valid
    SELECT ST_MakePolygon(ST_AddPoint(line, ST_StartPoint(line))) INTO v_boundary_geom
    FROM (
      SELECT ST_MakeLine(ST_SetSRID(ST_MakePoint((p->>1)::float, (p->>0)::float), 4326) ORDER BY ord) as line
      FROM jsonb_array_elements(v_boundary_json) WITH ORDINALITY AS t(p, ord)
    ) sub;

    -- 4. Pencarian Spasial (Grid Discovery)
    RETURN QUERY
    WITH random_points AS (
        SELECT (ST_Dump(ST_GeneratePoints(v_boundary_geom, 50))).geom as geom_point
    )
    SELECT 
        'Kandidat Otomatis'::text,
        ST_Y(rp.geom_point)::float, 
        ST_X(rp.geom_point)::float,
        0.85::float
    FROM random_points rp
    WHERE NOT EXISTS (
        -- Menggunakan radius yang diambil otomatis dari database
        SELECT 1 FROM lokasi 
        WHERE kategori = 'bengkel' 
        AND ST_DWithin(rp.geom_point, lokasi.geom, v_radius_pesaing / 111320.0)
    )
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;
```

### 2. Logika Pemrosesan Spasial
*   **JSON to Geometry**: Mengubah array koordinat teks menjadi objek spasial `POLYGON` yang dapat dipahami PostGIS.
*   **`ST_GeneratePoints`**: Algoritma cerdas yang menebar titik sampel di dalam poligon wilayah secara acak namun tetap di dalam batas administratif.
*   **Coordinate Reordering**: Secara otomatis menukar posisi `[Lat, Lng]` dari format aplikasi menjadi `[Lng, Lat]` (standar internasional WGS84).
*   **Degree Conversion**: Mengonversi input radius meter menjadi unit derajat (`111320.0`) agar perhitungan jarak akurat di atas koordinat bumi.

### 3. Alur Kerja Aplikasi (Workflow)
Sistem menggunakan metode **Discovery -> Preview -> Store**:
1.  **Discovery**: Pengguna memicu fungsi `rpc` dari halaman Ranking.
2.  **Preview**: Hasil koordinat ditampilkan di Peta Dashboard sebagai **Pin Biru** sementara.
3.  **Store**: Jika lokasi dianggap strategis, pengguna menekan "Konfirmasi" untuk membawa data ke **Halaman Input** guna disimpan secara permanen ke tabel `lokasi`.

# Rekomendasi Palet Warna dan Ikon

| Nama | Hex Code | Penggunaan Utama | Alasan UI/UX GIS |
| --- | --- | --- | --- |
| **Primary Accent** | `#F97316` | Tombol & Header | Oranye identik dengan industri otomotif. |
| **Road Layer** | `#1E40AF` | Garis Jalan | Biru Tua memberikan kontras tinggi pada peta. |
| **Boundary** | `#0F766E` | Batas Wilayah | Hijau Toska Tua sebagai penanda administratif wilayah. |
| **Sangat Strategis** | `#10B981` | Marker Ranking 1 | Hijau menandakan kelayakan tertinggi. |
| **Cukup Strategis** | `#F59E0B` | Marker Ranking 2-3 | Kuning sebagai alternatif strategis kedua. |
| **Kurang Strategis** | `#EF4444` | Marker Kompetitor | Merah untuk menandai area jenuh pasar. |

adminsig1
