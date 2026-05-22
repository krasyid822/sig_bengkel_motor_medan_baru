import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:latlong2/latlong.dart';
import 'package:sig_bengkel_motor_medan_baru/services/supabase_connection_service.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/csv_import_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/data_collection_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/documentation_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/geojson_import_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/map_dashboard_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/profile_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/saw_process_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  SupabaseConnectionService.instance.startMonitoring();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GIS Bengkel Buffer+SAW',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          primary: const Color(0xFFF97316),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFE2E8F0), // Slate 200 - Definitely not white
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF97316),
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // Default ke Peta
  late StreamSubscription<AuthState> _authSubscription;
  User? _user;
  
  // State untuk navigasi ke lokasi spesifik di peta
  LatLng? _targetLocation;
  String? _targetLocationId;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    // Jika sudah login saat start, default ke halaman Input (2)
    if (_user != null) {
      _currentIndex = 2;
    }
    _setupAuthListener();
    _setupSharingIntentListener();
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final newUser = data.session?.user;
      setState(() {
        // Jika baru login (dari null ke user), pindah ke halaman Input (2)
        if (_user == null && newUser != null) {
          _currentIndex = 2;
        }
        
        _user = newUser;

        // Jika logout dan sedang di halaman terlarang (CSV & GeoJSON), pindah ke peta
        if (_user == null && [3, 4].contains(_currentIndex)) {
          _currentIndex = 0;
        }
      });
    });
  }

  void _setupSharingIntentListener() {
    // 1. Menangani Share saat aplikasi di foreground/background
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (_user != null) _handleSharedMedia(value);
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // 2. Menangani Share saat aplikasi cold start
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (_user != null) _handleSharedMedia(value);
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> value) {
    if (value.isNotEmpty) {
      final sharedFile = value.first;
      if (sharedFile.path.toLowerCase().endsWith('.csv')) {
        setState(() => _currentIndex = 3);
      } else if (sharedFile.path.toLowerCase().endsWith('.geojson') ||
          sharedFile.path.toLowerCase().endsWith('.json')) {
        setState(() => _currentIndex = 4);
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _onJumpToLocation(LatLng location, String id) {
    setState(() {
      _targetLocation = location;
      _targetLocationId = id;
      _currentIndex = 0; 
    });
  }

  // Fungsi baru untuk mengirim koordinat dari Peta ke halaman Input
  void _onConfirmLocationToInput(LatLng location) {
    setState(() {
      _targetLocation = location;
      _currentIndex = 2; // Pindah ke tab Input
    });
  }

  // Definisi semua halaman
  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return MapDashboardPage(
          targetLocation: _targetLocation, 
          targetId: _targetLocationId,
          onLocationHandled: () {
            setState(() {
              _targetLocation = null;
              _targetLocationId = null;
            });
          },
          // Callback saat user menekan "KONFIRMASI LOKASI" di peta
          onConfirmSelection: _onConfirmLocationToInput,
        );
      case 1: return SawProcessPage(onLocationTap: _onJumpToLocation);
      case 2: 
        return DataCollectionPage(
          initialLocation: _targetLocation,
          onLocationHandled: () {
            setState(() {
              _targetLocation = null;
            });
          },
        );
      case 3: return const CsvImportPage();
      case 4: return const GeoJsonImportPage();
      case 5: return const ProfilePage();
      case 6: return const DocumentationPage();
      default: return const MapDashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = _user != null;

    // Filter menu berdasarkan role
    final List<Map<String, dynamic>> menuItems = [
      {'index': 0, 'icon': Icons.map, 'label': 'Peta'},
      {'index': 1, 'icon': Icons.format_list_numbered, 'label': 'Ranking'},
      {'index': 2, 'icon': Icons.add_location_alt, 'label': 'Input'},
      if (isLoggedIn) {'index': 3, 'icon': Icons.upload_file, 'label': 'CSV'},
      if (isLoggedIn) {'index': 4, 'icon': Icons.polyline, 'label': 'GeoJSON'},
      {'index': 5, 'icon': Icons.person, 'label': 'Profil'},
      {'index': 6, 'icon': Icons.menu_book, 'label': 'Info'},
    ];

    return Scaffold(
      body: _getPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: menuItems.indexWhere((m) => m['index'] == _currentIndex),
        onTap: (displayIndex) {
          setState(() {
            _currentIndex = menuItems[displayIndex]['index'];
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF97316),
        unselectedItemColor: Colors.blueGrey,
        items: menuItems.map((m) => BottomNavigationBarItem(
          icon: Icon(m['icon']),
          label: m['label'],
        )).toList(),
      ),
    );
  }
}
