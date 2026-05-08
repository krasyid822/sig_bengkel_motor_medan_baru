import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/location_service.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/camera_screen.dart';

class DataCollectionPage extends StatefulWidget {
  const DataCollectionPage({super.key});

  @override
  State<DataCollectionPage> createState() => _DataCollectionPageState();
}

class _DataCollectionPageState extends State<DataCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _jalanController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _verticesController = TextEditingController(); 
  
  String _kategori = 'bengkel';
  File? _imageFile;
  bool _isLoading = false;
  String _loadingMsg = 'Mohon tunggu...';

  // Tracking State
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  Position? _lastRecordedPosition;
  
  final LokasiRepository _repository = LokasiRepository();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _stopTracking(); // Pastikan stream ditutup saat keluar halaman
    _namaController.dispose();
    _jalanController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _verticesController.dispose();
    super.dispose();
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS tidak aktif.")));
      }
      return;
    }

    setState(() {
      _isTracking = true;
      _verticesController.clear(); // Mulai dari awal saat tracking baru
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Tambah titik setiap berpindah 5 meter
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _addPositionToVertices(position);
      },
    );
  }

  void _stopTracking() {
    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
      _positionStream = null;
    });
  }

  void _addPositionToVertices(Position pos) {
    final point = "${pos.longitude} ${pos.latitude}";
    setState(() {
      if (_verticesController.text.isEmpty) {
        _verticesController.text = point;
      } else {
        // Hindari duplikasi jika posisi sama persis dengan yang terakhir
        if (_lastRecordedPosition?.latitude != pos.latitude || _lastRecordedPosition?.longitude != pos.longitude) {
           _verticesController.text += ", $point";
        }
      }
      _lastRecordedPosition = pos;
      // Update juga field lat/lng utama untuk feedback visual
      _latController.text = pos.latitude.toString();
      _lngController.text = pos.longitude.toString();
    });
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang mencari lokasi GPS...';
    });
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
        await _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error determine position: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk menambah koordinat saat ini ke daftar vertices (LineString)
  void _addCurrentToVertices() {
    if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty) {
      final point = "${_lngController.text} ${_latController.text}";
      setState(() {
        if (_verticesController.text.isEmpty) {
          _verticesController.text = point;
        } else {
          _verticesController.text += ", $point";
        }
      });
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final address = await _locationService.getAddressFromLatLng(lat, lng);
      if (address != null) {
        setState(() {
          _jalanController.text = address;
        });
      }
    } catch (e) {
      debugPrint("Error get address: $e");
    }
  }

  Future<void> _getLatLngFromAddress() async {
    final address = _jalanController.text.trim();
    if (address.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMsg = 'Mencari koordinat dari alamat...';
    });

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _latController.text = loc.latitude.toString();
          _lngController.text = loc.longitude.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koordinat berhasil diperbarui berdasarkan alamat.'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alamat tidak ditemukan: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Pilih Sumber Foto', style: TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera Internal'),
                onTap: () => Navigator.pop(context, 'internal'),
              ),
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Kamera Sistem'),
                onTap: () => Navigator.pop(context, 'system'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri HP'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        ),
      );

      if (choice == null) return;

      File? resultFile;
      if (choice == 'internal') {
        if (!mounted) return;
        final File? file = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraScreen()));
        resultFile = file;
      } else {
        final XFile? pickedFile = await _picker.pickImage(
          source: choice == 'system' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 50,
        );
        if (pickedFile != null) resultFile = File(pickedFile.path);
      }

      if (resultFile != null) setState(() => _imageFile = resultFile);
    } catch (e) {
      debugPrint("Error take photo: $e");
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang menyimpan data...';
    });

    try {
      if (_kategori == 'jalan') {
        // Logika Simpan LineString
        final wkt = "LINESTRING(${_verticesController.text})";
        await _repository.insertJalan(_namaController.text, wkt);
      } else {
        // Logika Simpan Point
        final double? lat = double.tryParse(_latController.text);
        final double? lng = double.tryParse(_lngController.text);

        if (lat == null || lng == null) {
          throw Exception('Format koordinat tidak valid.');
        }

        if (_kategori != 'kandidat' && _imageFile == null) {
          throw Exception('Foto bukti wajib diambil untuk kategori ini.');
        }

        String? fotoUrl;
        if (_imageFile != null) {
          fotoUrl = await _repository.uploadFoto(_imageFile!);
        }

        final data = {
          'nama': _namaController.text,
          'kategori': _kategori,
          'jalan': _jalanController.text,
          'geom': 'POINT($lng $lat)',
          'created_at': DateTime.now().toIso8601String(),
          'foto_url': fotoUrl,
        };
        await _repository.insertBatchLokasi([data]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan!')));
        _namaController.clear();
        _jalanController.clear();
        _verticesController.clear();
        setState(() {
          _imageFile = null;
        });
        _determinePosition();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Data GIS')),
      body: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_loadingMsg)]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _namaController,
                      decoration: const InputDecoration(labelText: 'Nama Lokasi / Nama Jalan', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _kategori,
                      decoration: const InputDecoration(labelText: 'Kategori Data', border: OutlineInputBorder()),
                      items: [
                        {'val': 'kandidat', 'label': 'KANDIDAT LOKASI BARU (POINT)'},
                        {'val': 'bengkel', 'label': 'BENGKEL PESAING (POINT)'},
                        {'val': 'fasum', 'label': 'FASILITAS UMUM (POINT)'},
                        {'val': 'jalan', 'label': 'JALAN UTAMA (VEKTOR LINE)'},
                      ].map((e) => DropdownMenuItem(value: e['val']!, child: Text(e['label']!))).toList(),
                      onChanged: (v) => setState(() => _kategori = v!),
                    ),
                    const SizedBox(height: 16),
                    if (_kategori != 'jalan') ...[
                      TextFormField(
                        controller: _jalanController,
                        decoration: InputDecoration(
                          labelText: 'Alamat Lengkap', 
                          hintText: 'Masukkan alamat untuk mencari koordinat',
                          border: const OutlineInputBorder(), 
                          prefixIcon: const Icon(Icons.map), 
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.location_searching), 
                            onPressed: _getLatLngFromAddress,
                            tooltip: 'Cari Koordinat dari Alamat',
                          )
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    if (_kategori == 'jalan') ...[
                      const Text('Daftar Titik Koordinat Jalan (Vektor Line):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _verticesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Vertices (lng lat, lng lat, ...)', 
                          hintText: 'Contoh: 98.66 3.56, 98.67 3.57',
                          border: OutlineInputBorder(),
                          helperText: 'Gunakan tombol di bawah untuk menambah titik dari GPS HP.'
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Minimal harus ada 2 titik untuk sebuah jalan' : null,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addCurrentToVertices, 
                        icon: const Icon(Icons.add_location_alt), 
                        label: const Text('TAMBAH TITIK MANUAL'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _toggleTracking, 
                        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow), 
                        label: Text(_isTracking ? 'BERHENTI AUTO-TRACKING' : 'MULAI AUTO-TRACKING'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red.shade100 : Colors.green.shade100,
                          foregroundColor: _isTracking ? Colors.red : Colors.green,
                        ),
                      ),
                      if (_isTracking)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                              SizedBox(width: 8),
                              Text("Sistem sedang merekam jejak GPS...", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                          ),
                        ),
                        IconButton(
                          onPressed: _determinePosition, 
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          tooltip: 'Ambil GPS',
                        ),
                      ],
                    ),

                    if (_kategori != 'jalan') ...[
                      const SizedBox(height: 20),
                      const Text('Foto Dokumentasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)),
                          child: _imageFile != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imageFile!, fit: BoxFit.cover))
                              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text('Ambil Foto')]),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _submitData, 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15), 
                        backgroundColor: Colors.deepPurple, 
                        foregroundColor: Colors.white
                      ), 
                      child: Text(
                        _kategori == 'jalan' ? 'SIMPAN JALAN (LINE)' : (_kategori == 'kandidat' ? 'ANALISIS LOKASI' : 'SIMPAN DATA POINT'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      )
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
