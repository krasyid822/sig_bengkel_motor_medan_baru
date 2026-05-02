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
kategori text CHECK (kategori IN ('bengkel', 'fasum')),
jalan text,
geom geometry(Point, 4326) NOT NULL,
created_at timestamptz DEFAULT now()
);

# Format Dataset CSV

nama,kategori,jalan,longitude,latitude,timestamp_utc

# Buffer and SAW rules

### 1. Data Core (GIS)
* **Data Lokasi:** Kandidat bengkel, bengkel eksisting (kompetitor), dan jalan utama Medan Baru.
* **Data Wilayah:** Batas wilayah Medan Baru (Polygon), data jalan, dan fasilitas umum (SPBU, pajak, kampus, permukiman).

### 2. Aturan Buffer (Jarak Jangkauan)
* **Jalan Utama:** 200 meter.
* **Permukiman:** 300 meter.
* **Bengkel Lain (Kompetitor):** 500 meter.

### 3. Kriteria SAW (Simple Additive Weighting)
| Kode | Kriteria | Bobot | Jenis |
|------|----------|-------|-------|
| C1 | Kepadatan Penduduk | 25% | Benefit |
| C2 | Jarak ke Jalan Utama | 20% | Cost |
| C3 | Jarak Pesaing | 20% | Benefit |
| C4 | Harga Sewa Tempat | 15% | Cost |
| C5 | Luas Lahan | 20% | Benefit |

### 4. Output Sistem
* Perankingan lokasi terbaik untuk pendirian bengkel baru.
* Visualisasi peta dengan layer buffer area dan marker kompetitor/fasum.

