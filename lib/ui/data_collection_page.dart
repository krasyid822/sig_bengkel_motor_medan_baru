import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
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
  
  String _kategori = 'bengkel';
  File? _imageFile;
  bool _isLoading = false;
  String _loadingMsg = 'Mohon tunggu...';
  
  final LokasiRepository _repository = LokasiRepository();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
    
    final double? lat = double.tryParse(_latController.text);
    final double? lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format koordinat tidak valid.')));
       return;
    }
    
    if (_kategori != 'kandidat' && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto bukti wajib diambil untuk kategori ini.')));
       return;
    }

    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang menyimpan data...';
    });

    try {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan!')));
        _namaController.clear();
        _jalanController.clear();
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
      appBar: AppBar(title: const Text('Input Data & Dokumentasi')),
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
                      decoration: const InputDecoration(labelText: 'Nama Lokasi', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _kategori,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: [
                        {'val': 'kandidat', 'label': 'KANDIDAT LOKASI BARU'},
                        {'val': 'bengkel', 'label': 'BENGKEL (PESAING)'},
                        {'val': 'fasum', 'label': 'FASILITAS UMUM / JALAN'},
                      ].map((e) => DropdownMenuItem(value: e['val']!, child: Text(e['label']!))).toList(),
                      onChanged: (v) => setState(() => _kategori = v!),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib' : null,
                          ),
                        ),
                        IconButton(
                          onPressed: _determinePosition, 
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          tooltip: 'Ambil dari GPS HP',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Foto Dokumentasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)),
                        child: _imageFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imageFile!, fit: BoxFit.cover))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text('Ambil Foto')]),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _submitData, 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15), 
                        backgroundColor: Colors.deepPurple, 
                        foregroundColor: Colors.white
                      ), 
                      child: Text(
                        _kategori == 'kandidat' ? 'ANALISIS LOKASI' : 'SIMPAN DATA', 
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
