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
  int _currentIndex = 2; // Default ke menu Input (index 2)
  late StreamSubscription _intentDataStreamSubscription;
  
  // State untuk navigasi ke lokasi spesifik di peta
  LatLng? _targetLocation;
  String? _targetLocationId;

  @override
  void initState() {
    super.initState();
    _setupSharingIntentListener();
  }

  void _setupSharingIntentListener() {
    // 1. Menangani Share (Media, URL, Text) saat aplikasi di foreground/background
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // 2. Menangani Share saat aplikasi cold start
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> value) {
    if (value.isNotEmpty) {
      final sharedFile = value.first;
      
      if (sharedFile.path.toLowerCase().endsWith('.csv')) {
        setState(() {
          _currentIndex = 3; // Pindah ke tab CSV
        });
      } else if (sharedFile.path.toLowerCase().endsWith('.geojson') ||
          sharedFile.path.toLowerCase().endsWith('.json')) {
        setState(() {
          _currentIndex = 4; // Pindah ke tab GeoJSON
        });
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  void _onJumpToLocation(LatLng location, String id) {
    setState(() {
      _targetLocation = location;
      _targetLocationId = id;
      _currentIndex = 0; // Pindah ke tab Peta (index 0)
    });
  }

  List<Widget> _pages() => [
    MapDashboardPage(
      targetLocation: _targetLocation, 
      targetId: _targetLocationId,
      onLocationHandled: () {
        setState(() {
          _targetLocation = null;
          _targetLocationId = null;
        });
      },
    ),
    SawProcessPage(onLocationTap: _onJumpToLocation),
    const DataCollectionPage(),
    const CsvImportPage(),
    const GeoJsonImportPage(),
    const DocumentationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages()[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF97316),
        unselectedItemColor: Colors.blueGrey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Peta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered_outlined),
            activeIcon: Icon(Icons.format_list_numbered),
            label: 'Ranking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location_alt_outlined),
            activeIcon: Icon(Icons.add_location_alt),
            label: 'Input',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file_outlined),
            activeIcon: Icon(Icons.upload_file),
            label: 'CSV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.polyline_outlined),
            activeIcon: Icon(Icons.polyline),
            label: 'GeoJSON',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}
