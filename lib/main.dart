import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/csv_import_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/data_collection_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/documentation_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/map_dashboard_page.dart';
import 'package:sig_bengkel_motor_medan_baru/ui/saw_process_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  String? _sharedText;

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
      
      // Di versi terbaru plugin (1.8+), teks/URL juga masuk sebagai SharedMediaFile
      // dengan type .text atau .url, dan isinya ada di properti .path
      if (sharedFile.type == SharedMediaType.text || sharedFile.type == SharedMediaType.url) {
        setState(() {
          _sharedText = sharedFile.path;
          _currentIndex = 2; // Pindah ke tab Input
        });
      } else if (sharedFile.path.toLowerCase().endsWith('.csv')) {
        setState(() {
          _currentIndex = 3; // Pindah ke tab CSV
        });
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  List<Widget> _pages(String? initialText) => [
    const MapDashboardPage(),    // Dashboard Peta (Leaflet)
    const SawProcessPage(),      // Proses SAW & Ranking
    DataCollectionPage(initialGmapsUrl: initialText),  // Manajemen Data / Input
    const CsvImportPage(),       // Import CSV
    const DocumentationPage(),   // Dokumentasi
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages(_sharedText),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Peta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'SAW',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location_alt),
            label: 'Input',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: 'CSV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}
