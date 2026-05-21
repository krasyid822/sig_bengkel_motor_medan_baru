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

Untuk menghubungkan dashboard web Laravel ke database Supabase yang sama dengan aplikasi mobile, gunakan View `v_lokasi_peta` yang mengembalikan format GeoJSON siap pakai.

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