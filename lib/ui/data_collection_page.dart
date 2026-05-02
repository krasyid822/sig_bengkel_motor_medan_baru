import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/gmaps_logic.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/location_service.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/camera_screen.dart';

class DataCollectionPage extends StatefulWidget {
  final String? initialGmapsUrl;
  const DataCollectionPage({super.key, this.initialGmapsUrl});

  @override
  State<DataCollectionPage> createState() => _DataCollectionPageState();
}

class _DataCollectionPageState extends State<DataCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _jalanController = TextEditingController();
  final _gmapsUrlController = TextEditingController();
  String _kategori = 'bengkel';
  Position? _currentPosition;
  File? _imageFile;
  bool _isLoading = false;
  String _loadingMsg = 'Mohon tunggu...';
  
  final LokasiRepository _repository = LokasiRepository();
  final GmapsLogic _gmapsLogic = GmapsLogic();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();
  
  bool _useGmapsUrl = false;
  String _coordsSource = 'GPS HP';

  @override
  void initState() {
    super.initState();
    _determinePosition();
    
    if (widget.initialGmapsUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gmapsUrlController.text = widget.initialGmapsUrl!;
        _useGmapsUrl = true;
        _parseGmapsUrl(widget.initialGmapsUrl!);
      });
    }
  }

  @override
  void didUpdateWidget(DataCollectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGmapsUrl != null && widget.initialGmapsUrl != oldWidget.initialGmapsUrl) {
      _gmapsUrlController.text = widget.initialGmapsUrl!;
      _useGmapsUrl = true;
      _parseGmapsUrl(widget.initialGmapsUrl!);
    }
  }

  Future<void> _parseGmapsUrl(String rawText) async {
    if (rawText.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang mengekstrak lokasi dari teks/URL...';
    });

    try {
      final result = await _gmapsLogic.parseUrl(rawText);

      setState(() {
        if (result.name != null && result.name!.isNotEmpty) {
          _namaController.text = result.name!;
        }
        
        if (result.latitude != null && result.longitude != null) {
          _coordsSource = 'Google Maps URL';
          _currentPosition = Position(
            latitude: result.latitude!,
            longitude: result.longitude!,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }

        if (result.photoFile != null) {
          _imageFile = result.photoFile;
        }
      });

      if (_currentPosition != null) {
        await _getAddressFromLatLng();
      }

      if (mounted) {
        final photoMsg = _imageFile == null 
            ? '(Foto tidak ditemukan, silakan ambil foto manual)' 
            : '(Foto berhasil dimuat)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data lokasi & nama berhasil diambil! $photoMsg'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca URL: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang mencari lokasi GPS...';
    });
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _coordsSource = 'GPS HP (Live)';
      });
    } catch (e) {
      debugPrint("Error determine position: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
      _loadingMsg = 'Sedang mendapatkan alamat...';
    });
    try {
      final address = await _locationService.getAddressFromLatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (address != null) {
        setState(() {
          _jalanController.text = address;
        });
      }
    } catch (e) {
      debugPrint("Error get address: $e");
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
    if (_currentPosition == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi belum didapatkan.')));
       return;
    }
    
    // Dokumentasi hanya wajib untuk kategori selain 'kandidat'
    if (_kategori != 'kandidat' && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto bukti wajib diambil untuk kategori ini.')));
       return;
    }

    setState(() {
      _isLoading = true;
      _loadingMsg = _kategori == 'kandidat' ? 'Sedang menganalisis data...' : 'Sedang mengunggah data...';
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
        'geom': 'POINT(${_currentPosition!.longitude} ${_currentPosition!.latitude})',
        'created_at': DateTime.now().toIso8601String(),
        'foto_url': fotoUrl,
      };
      await _repository.insertBatchLokasi([data]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analisis berhasil! Data telah ditambahkan ke sistem ranking.')));
        _namaController.clear();
        _jalanController.clear();
        setState(() {
          _imageFile = null;
          _useGmapsUrl = false;
          _gmapsUrlController.clear();
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
                    Row(
                      children: [
                        Expanded(child: ChoiceChip(label: const Text('GPS HP'), selected: !_useGmapsUrl, onSelected: (val) { setState(() => _useGmapsUrl = !val); if (val) _determinePosition(); })),
                        const SizedBox(width: 8),
                        Expanded(child: ChoiceChip(label: const Text('URL Gmaps'), selected: _useGmapsUrl, onSelected: (val) => setState(() => _useGmapsUrl = val))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_useGmapsUrl)
                      TextFormField(
                        controller: _gmapsUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL Google Maps',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _parseGmapsUrl(_gmapsUrlController.text)),
                        ),
                        onChanged: (val) { if (val.length > 20) _parseGmapsUrl(val); },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _jalanController,
                      decoration: InputDecoration(labelText: 'Alamat', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.map), suffixIcon: IconButton(icon: const Icon(Icons.auto_fix_high), onPressed: _getAddressFromLatLng)),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                    const SizedBox(height: 20),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Koordinat:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _coordsSource.contains('GPS') ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(4)), child: Text('Sumber: $_coordsSource', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                              ]),
                              IconButton(onPressed: _determinePosition, icon: const Icon(Icons.refresh, color: Colors.blue)),
                            ]),
                            const SizedBox(height: 8),
                            _currentPosition == null ? const Text('Mencari lokasi...') : Text('Lat: ${_currentPosition!.latitude}\nLong: ${_currentPosition!.longitude}'),
                          ],
                        ),
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
