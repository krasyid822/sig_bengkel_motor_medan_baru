import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/data/lokasi_repository.dart';
import 'package:sig_bengkel_motor_medan_baru/logika/location_service.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/camera_screen.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/map_picker_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/loading_overlay_card.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/overflow_marquee_text.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/widgets/supabase_status_dot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataCollectionPage extends StatefulWidget {
  final LatLng? initialLocation;
  final VoidCallback? onLocationHandled;

  const DataCollectionPage({super.key, this.initialLocation, this.onLocationHandled});

  @override
  State<DataCollectionPage> createState() => _DataCollectionPageState();
}

// Global state untuk persistensi pilihan GPS (di luar class agar tidak reset saat tab switch)
bool _globalAutoCaptureGps = true;

class _DataCollectionPageState extends State<DataCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _jalanController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _bukaController = TextEditingController();
  final _tutupController = TextEditingController();
  final _hariLiburController = TextEditingController();
  final _luasLahanController = TextEditingController();
  
  String _kategori = 'kandidat';
  bool _isResmi = false;
  List<String> _selectedHariLibur = [];
  File? _imageFile;
  String? _existingFotoUrl;
  dynamic _editingLokasiId;
  bool get _isEditing => _editingLokasiId != null;
  bool _isLoading = false;
  String _loadingMsg = 'Mohon tunggu...';
  double _loadingProgress = 0.0;
  
  final LokasiRepository _repository = LokasiRepository();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();

  void _updateLoading({
    required String message,
    required double progress,
    bool isLoading = true,
  }) {
    if (!mounted) return;
    setState(() {
      _isLoading = isLoading;
      _loadingMsg = message;
      _loadingProgress = progress.clamp(0.0, 1.0).toDouble();
    });
  }

  @override
  void initState() {
    super.initState();
    _applyInitialState();
  }

  @override
  void didUpdateWidget(DataCollectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocation != null && widget.initialLocation != oldWidget.initialLocation) {
      _applyInitialState();
    }
  }

  void _applyInitialState() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      // Prioritaskan kategori 'kandidat' jika datang dari navigasi target (Auto Kandidat)
      if (widget.initialLocation != null) {
        _kategori = 'kandidat';
      } else {
        _kategori = user != null ? 'bengkel' : 'kandidat';
      }
    });

    if (widget.initialLocation != null) {
      _latController.text = widget.initialLocation!.latitude.toString();
      _lngController.text = widget.initialLocation!.longitude.toString();
      _getAddressFromLatLng(widget.initialLocation!.latitude, widget.initialLocation!.longitude);
      
      // Beritahu MainPage bahwa lokasi target sudah ditangani agar tidak diulang
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onLocationHandled?.call();
      });
    } else if (_globalAutoCaptureGps) {
      _determinePosition();
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _jalanController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _bukaController.dispose();
    _tutupController.dispose();
    _hariLiburController.dispose();
    _luasLahanController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    _updateLoading(message: 'Memeriksa layanan dan izin GPS...', progress: 0.0);
    try {
      final position = await _locationService.getCurrentPosition();
      _updateLoading(message: 'Koordinat GPS ditemukan, mengambil alamat...', progress: 0.5);
      if (position != null) {
        setState(() {
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
        await _getAddressFromLatLng(position.latitude, position.longitude);
      }
      _updateLoading(message: 'Lokasi GPS berhasil diperbarui.', progress: 1.0);
    } catch (e) {
      debugPrint("Error determine position: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _pickFromMap() async {
    final double initialLat = double.tryParse(_latController.text) ?? 3.5659;
    final double initialLng = double.tryParse(_lngController.text) ?? 98.6605;

    final LatLng? picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLocation: LatLng(initialLat, initialLng),
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _latController.text = picked.latitude.toString();
        _lngController.text = picked.longitude.toString();
      });
      await _getAddressFromLatLng(picked.latitude, picked.longitude);
    }
  }

  Future<void> _getLatLngFromAddress() async {
    final address = _jalanController.text.trim();
    if (address.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMsg = 'Mencari koordinat dari alamat...';
      _loadingProgress = 0.0;
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
          _updateLoading(message: 'Koordinat berhasil ditemukan dari alamat.', progress: 1.0);
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _resetForm({bool refreshPosition = true}) {
    _formKey.currentState?.reset();
    _namaController.clear();
    _jalanController.clear();
    _latController.clear();
    _lngController.clear();
    _bukaController.clear();
    _tutupController.clear();
    _hariLiburController.clear();
    _luasLahanController.clear();
    setState(() {
      _kategori = 'kandidat';
      _isResmi = false;
      _selectedHariLibur = [];
      _imageFile = null;
      _existingFotoUrl = null;
      _editingLokasiId = null;
    });
    if (refreshPosition) {
      _determinePosition();
    }
  }

  Future<void> _openEditPicker() async {
    _updateLoading(message: 'Mengambil data yang bisa diedit...', progress: 0.2);
    try {
      var items = await _repository.fetchAllLokasi();
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      if (!isLoggedIn) {
        items = items.where((item) => item['kategori']?.toString().toLowerCase() == 'kandidat').toList();
      }
      if (!mounted) return;
      setState(() => _isLoading = false);

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final queryController = TextEditingController();
          List<Map<String, dynamic>> filteredItems = List<Map<String, dynamic>>.from(items);

          return StatefulBuilder(
            builder: (context, setModalState) {
              void applyFilter(String query) {
                final keyword = query.trim().toLowerCase();
                setModalState(() {
                  filteredItems = items.where((item) {
                    final nama = (item['nama'] ?? '').toString().toLowerCase();
                    final jalan = (item['jalan'] ?? '').toString().toLowerCase();
                    final kategori = (item['kategori'] ?? '').toString().toLowerCase();
                    return nama.contains(keyword) ||
                        jalan.contains(keyword) ||
                        kategori.contains(keyword);
                  }).toList();
                });
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OverflowMarqueeText(
                        'Pilih Data Yang Akan Diedit',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: queryController,
                        onChanged: applyFilter,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Cari nama, alamat, atau kategori',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final title = (item['nama'] ?? 'Tanpa Nama').toString();
                            final subtitle =
                                '${(item['kategori'] ?? '-').toString().toUpperCase()} • ${(item['jalan'] ?? 'Alamat tidak tersedia').toString()}';
                            return ListTile(
                              title: OverflowMarqueeText(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: OverflowMarqueeText(
                                subtitle,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (selected != null) {
        _populateFormForEdit(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data edit: $e')),
      );
    }
  }

  void _populateFormForEdit(Map<String, dynamic> item) {
    // Ambil latitude/longitude langsung jika ada (dari View v_lokasi_peta)
    String lat = (item['latitude'] ?? '').toString();
    String lng = (item['longitude'] ?? '').toString();

    // Fallback jika latitude/longitude kosong (parsing manual dari geom)
    if (lat.isEmpty || lng.isEmpty) {
      final dynamic geomRaw = item['geom'];
      if (geomRaw != null) {
        final geomText = geomRaw.toString();
        final pointMatch = RegExp(r'POINT\(([-0-9.]+)\s+([-0-9.]+)\)', caseSensitive: false).firstMatch(geomText);
        if (pointMatch != null) {
          lng = pointMatch.group(1) ?? '';
          lat = pointMatch.group(2) ?? '';
        }
      }
    }

    setState(() {
      _editingLokasiId = item['id'];
      _namaController.text = (item['nama'] ?? '').toString();
      _jalanController.text = (item['jalan'] ?? '').toString();
      _latController.text = lat;
      _lngController.text = lng;
      _kategori = ((item['kategori'] ?? 'bengkel').toString().toLowerCase());
      _bukaController.text = (item['waktu_buka'] ?? '').toString();
      _tutupController.text = (item['waktu_tutup'] ?? '').toString();
      _hariLiburController.text = (item['hari_libur'] ?? '').toString();
      
      const allDaysOptions = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu', 'Hari Besar Libur'];
      _selectedHariLibur = (item['hari_libur'] ?? '')
          .toString()
          .replaceAll(' dan ', ', ')
          .split(',')
          .map((e) => e.trim())
          .map((e) => allDaysOptions.firstWhere((day) => day.toLowerCase() == e.toLowerCase(), orElse: () => e))
          .where((e) => e.isNotEmpty)
          .toList();

      _luasLahanController.text = (item['luas_lahan'] ?? '').toString();
      _isResmi = item['is_resmi'] == true;
      _existingFotoUrl = item['foto_url']?.toString();
      _imageFile = null;
    });
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    // Jika opsi otomatis aktif dan koordinat masih kosong, ambil GPS sekarang
    if (!_globalAutoCaptureGps && (_latController.text.isEmpty || _lngController.text.isEmpty)) {
      await _determinePosition();
    }

    final bool needsPhotoUpload = _imageFile != null;
    final int totalSteps = needsPhotoUpload ? 3 : 2;
    int completedSteps = 0;

    void advanceProgress(String message) {
      completedSteps++;
      _updateLoading(
        message: message,
        progress: completedSteps / totalSteps,
      );
    }

    _updateLoading(message: 'Memvalidasi data sebelum disimpan...', progress: 0.0);

    try {
      final double? lat = double.tryParse(_latController.text);
      final double? lng = double.tryParse(_lngController.text);

      if (lat == null || lng == null) {
        throw Exception('Format koordinat tidak valid.');
      }

      if (_kategori != 'kandidat' && _imageFile == null && _existingFotoUrl == null) {
        throw Exception('Foto bukti wajib diambil untuk kategori ini.');
      }

      String? fotoUrl = _existingFotoUrl;
      if (_imageFile != null) {
        advanceProgress('Mengunggah foto dokumentasi...');
        fotoUrl = await _repository.uploadFoto(_imageFile!);
      }

      advanceProgress(_isEditing ? 'Memperbarui data lokasi di database...' : 'Menyimpan data lokasi ke database...');
      
      // Keamanan data: Luas Lahan & Is Resmi hanya milik 'bengkel' (pesaing)
      final bool finalIsResmi = _kategori == 'bengkel' ? _isResmi : false;
      final double finalLuasLahan = _kategori == 'bengkel' ? (double.tryParse(_luasLahanController.text) ?? 0) : 0;

      final data = {
        'nama': _namaController.text,
        'kategori': _kategori,
        'jalan': _jalanController.text,
        'geom': 'POINT($lng $lat)',
        'foto_url': fotoUrl,
        'waktu_buka': _bukaController.text.isNotEmpty ? _bukaController.text : null,
        'waktu_tutup': _tutupController.text.isNotEmpty ? _tutupController.text : null,
        'hari_libur': _hariLiburController.text.isNotEmpty ? _hariLiburController.text : null,
        'is_resmi': finalIsResmi,
        'luas_lahan': finalLuasLahan,
      };
      if (_isEditing) {
        await _repository.updateLokasi(_editingLokasiId, data);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        await _repository.insertBatchLokasi([data]);
      }

      advanceProgress('Penyimpanan data selesai.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Data berhasil diperbarui!' : 'Data berhasil disimpan!')),
        );
        _resetForm();
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
      appBar: AppBar(
        title: const OverflowMarqueeText('Input Data GIS'),
        actions: [
          IconButton(
            onPressed: _openEditPicker,
            tooltip: 'Edit data yang sudah ada',
            icon: const Icon(Icons.edit_note),
          ),
          if (_isEditing)
            IconButton(
              onPressed: () => _resetForm(),
              tooltip: 'Batal edit',
              icon: const Icon(Icons.close),
            ),
          const SupabaseStatusDot(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isEditing) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: OverflowMarqueeText(
                                    'Mode edit aktif. Perubahan akan memperbarui data yang sudah diunggah.',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Builder(
                          builder: (context) {
                            final dropdownItems = [
                              {'val': 'kandidat', 'label': 'KANDIDAT LOKASI BARU (POINT)'},
                              if (Supabase.instance.client.auth.currentUser != null) ...[
                                {'val': 'bengkel', 'label': 'BENGKEL PESAING (POINT)'},
                                {'val': 'fasum', 'label': 'FASILITAS UMUM (POINT)'},
                              ],
                            ];
                            // Cek jika kategori saat ini tidak valid bagi user, reset ke kategori default
                            final bool isValid = dropdownItems.any((item) => item['val'] == _kategori);
                            final String displayKategori = isValid ? _kategori : (Supabase.instance.client.auth.currentUser != null ? 'bengkel' : 'kandidat');
                            
                            return DropdownButtonFormField<String>(
                              initialValue: displayKategori,
                              decoration: const InputDecoration(labelText: 'Kategori Data', border: OutlineInputBorder()),
                              items: dropdownItems.map((e) => DropdownMenuItem(value: e['val']!, child: Text(e['label']!))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _kategori = v!;
                                  if (_kategori != 'bengkel') {
                                    _isResmi = false;
                                    _luasLahanController.clear();
                                  }
                                });
                              },
                            );
                          }
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _pickFromMap,
                          icon: const Icon(Icons.map),
                          label: const Text('Pilih Lokasi dari Peta'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                            foregroundColor: const Color(0xFFF97316),
                            side: const BorderSide(color: Color(0xFFF97316)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _namaController,
                          decoration: const InputDecoration(labelText: 'Nama Lokasi', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _bukaController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Jam Buka', 
                                  border: OutlineInputBorder(), 
                                  prefixIcon: Icon(Icons.access_time),
                                  hintText: '--:--',
                                ),
                                onTap: () async {
                                  TimeOfDay initial = TimeOfDay.now();
                                  if (_bukaController.text.isNotEmpty) {
                                    final parts = _bukaController.text.split(':');
                                    if (parts.length >= 2) {
                                      initial = TimeOfDay(
                                        hour: int.tryParse(parts[0]) ?? 8, 
                                        minute: int.tryParse(parts[1]) ?? 0
                                      );
                                    }
                                  }
                                  TimeOfDay? picked = await showTimePicker(
                                    context: context, 
                                    initialTime: initial,
                                    helpText: 'Pilih Jam Buka',
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _bukaController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _tutupController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Jam Tutup', 
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time_filled),
                                  hintText: '--:--',
                                ),
                                onTap: () async {
                                  TimeOfDay initial = TimeOfDay.now();
                                  if (_tutupController.text.isNotEmpty) {
                                    final parts = _tutupController.text.split(':');
                                    if (parts.length >= 2) {
                                      initial = TimeOfDay(
                                        hour: int.tryParse(parts[0]) ?? 17, 
                                        minute: int.tryParse(parts[1]) ?? 0
                                      );
                                    }
                                  }
                                  TimeOfDay? picked = await showTimePicker(
                                    context: context, 
                                    initialTime: initial,
                                    helpText: 'Pilih Jam Tutup',
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _tutupController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Pemilih Hari Libur yang Lebih Rapi
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hari Libur Operasional',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event_busy, color: Color(0xFFF97316)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 0.0,
                            children: ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu', 'Hari Besar'].map((day) {
                              final isSelected = _selectedHariLibur.contains(day);
                              return FilterChip(
                                label: Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: const Color(0xFFF97316),
                                backgroundColor: Colors.grey.shade100,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade300)),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedHariLibur.add(day);
                                    } else {
                                      _selectedHariLibur.remove(day);
                                    }
                                    const allDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu', 'Hari Besar'];
                                    _selectedHariLibur.sort((a, b) => allDays.indexOf(a).compareTo(allDays.indexOf(b)));
                                    
                                    if (_selectedHariLibur.isEmpty) {
                                      _hariLiburController.text = '';
                                    } else if (_selectedHariLibur.length == 1) {
                                      _hariLiburController.text = _selectedHariLibur.first;
                                    } else {
                                      final last = _selectedHariLibur.last;
                                      final others = _selectedHariLibur.sublist(0, _selectedHariLibur.length - 1);
                                      _hariLiburController.text = "${others.join(', ')} dan ${last.toLowerCase()}";
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        if (_kategori == 'bengkel') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _luasLahanController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Luas Lahan (m2)', 
                              hintText: 'Contoh: 150',
                              border: OutlineInputBorder(), 
                              prefixIcon: Icon(Icons.straighten),
                              suffixText: 'm2',
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<bool>(
                            initialValue: _isResmi,
                            decoration: const InputDecoration(
                              labelText: 'Bengkel Resmi? (C4)', 
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.verified_user_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: true, child: Text('Ya (Bengkel Resmi)')),
                              DropdownMenuItem(value: false, child: Text('Tidak (Bengkel Umum)')),
                            ],
                            onChanged: (val) => setState(() => _isResmi = val ?? false),
                          ),
                        ],
                        const SizedBox(height: 8),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _latController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Latitude', 
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _lngController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Longitude', 
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              children: [
                                Material(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: IconButton(
                                    onPressed: _determinePosition, 
                                    icon: const Icon(Icons.my_location, color: Color(0xFF0284C7)),
                                    tooltip: 'Ambil GPS',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Ambil GPS Otomatis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(_globalAutoCaptureGps ? 'GPS diambil saat halaman dibuka' : 'GPS diambil saat tombol SIMPAN ditekan', style: const TextStyle(fontSize: 11)),
                          value: _globalAutoCaptureGps,
                          activeThumbColor: const Color(0xFFF97316),
                          activeTrackColor: const Color(0xFFF97316).withValues(alpha: 0.5),
                          onChanged: (val) {
                            setState(() {
                              _globalAutoCaptureGps = val;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),

                        const SizedBox(height: 20),
                        const Text('Foto Dokumentasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                            child: _imageFile != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imageFile!, fit: BoxFit.cover))
                                : (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(_existingFotoUrl!, fit: BoxFit.cover),
                                      )
                                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text('Ambil Foto')]),
                          ),
                        ),
                        if (_isEditing && _existingFotoUrl != null && _existingFotoUrl!.isNotEmpty && _imageFile == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Foto lama tetap dipakai jika Anda tidak mengambil foto baru.',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ),

                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _submitData, 
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15), 
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white
                          ), 
                          child: OverflowMarqueeText(
                            _isEditing
                                ? 'PERBARUI DATA POINT'
                                : (_kategori == 'kandidat' ? 'ANALISIS LOKASI' : 'SIMPAN DATA POINT'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          )
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                LoadingOverlayCard(
                  progress: _loadingProgress,
                  message: _loadingMsg,
                  color: const Color(0xFFF97316),
                ),
            ],
          );
        }
      ),
    );
  }
}
