import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Ajout pour le support Web
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/sobriety_test_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// On n'importe dart:io que si on n'est PAS sur le web pour éviter les crashs de compilation
import 'dart:io' if (dart.library.html) 'utils/web_stubs.dart' as io;

import 'models/models.dart';
import 'utils/helpers.dart';
import 'widgets/glass_widgets.dart';
import 'utils/storage_service.dart';
import 'screens/auth_screen.dart'; // Ajout de l'écran auth
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'utils/l10n_service.dart'; // Import L10n
import 'utils/supabase_service.dart'; // Ajout import manquant

typedef File = io.File;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Chargement des langues
  await L10n.load();

  // On lance l'uninitialisation en arrière-plan
  Supabase.initialize(
    url: 'https://aswxkjibvcadnwujzwcm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro',
  ).then((_) => debugPrint("✅ Supabase initialisé"))
   .catchError((e) => debugPrint("⚠️ Erreur Supabase : $e"));

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('fr_FR', null); // On réactive les dates
  runApp(const AlcoholTrackerApp());
}

// --- MODÈLES ET UTILITAIRES DÉPLACÉS ---


class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class AlcoholTrackerApp extends StatefulWidget {
  const AlcoholTrackerApp({super.key});
  @override
  State<AlcoholTrackerApp> createState() => _AlcoholTrackerAppState();
}

class _AlcoholTrackerAppState extends State<AlcoholTrackerApp> {
  bool _isDarkMode = true;
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final data = await StorageService.loadAppData();
    setState(() => _isDarkMode = data['isDarkMode']);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isDarkMode
        ? const Color(0xFFEA9216)
        : const Color(0xFF1A3A5F);
    return MaterialApp(
      title: L10n.s('app.title'),
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F3F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await StorageService.loadAppData();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/images/splash.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              const CircularProgressIndicator(color: Color(0xFFEA9216)),
        ),
      ),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});
  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  bool _isDarkMode = true;
  bool _isYoungDriver = false;
  bool _unitMl = false;
  bool _isOfflineMode = false;
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        _isOfflineMode = false;
        await StorageService.savePref('isOfflineMode', false);
      }
      if (data.event == AuthChangeEvent.signedOut) {
        await StorageService.clearAll();
        _isOfflineMode = false;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final data = await StorageService.loadAppData();
    setState(() {
      _isDarkMode = data['isDarkMode'] ?? true;
      _isYoungDriver = data['isYoungDriver'] ?? false;
      _unitMl = data['unitMl'] ?? false;
      _isOfflineMode = data['isOfflineMode'] ?? false;
    });
  }

  void _updateTheme(bool dark) {
    setState(() => _isDarkMode = dark);
    StorageService.savePref('isDarkMode', dark);
  }

  void _updateYoungDriver(bool val) {
    setState(() => _isYoungDriver = val);
    StorageService.savePref('isYoungDriver', val);
  }

  void _updateUnitMl(bool val) {
    setState(() => _unitMl = val);
    StorageService.savePref('unitMl', val);
  }

  @override
  Widget build(BuildContext context) {
    // Vérification de la session Supabase
    final Session? session = Supabase.instance.client.auth.currentSession;

    final accentColor = _isDarkMode
        ? const Color(0xFFEA9216)
        : const Color(0xFF1A3A5F);

    if (session == null && !_isOfflineMode) {
      return AuthScreen(
        onAuthSuccess: () => setState(() {
          // On recharge les données au succès de l'auth
          _loadTheme();
        }),
        onOfflineSelected: () async {
          await StorageService.savePref('isOfflineMode', true);
          setState(() {
            _isOfflineMode = true;
          });
        },
        accentColor: accentColor,
        isDarkMode: _isDarkMode,
      );
    }

    return MainNavigationScreen(
      isDarkMode: _isDarkMode,
      onThemeChanged: _updateTheme,
      accentColor: accentColor,
      isYoungDriver: _isYoungDriver,
      onYoungDriverChanged: _updateYoungDriver,
      unitMl: _unitMl,
      onUnitMlChanged: _updateUnitMl,
      onOfflineLogout: () async {
        await StorageService.savePref('isOfflineMode', false);
        setState(() => _isOfflineMode = false);
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Color accentColor;
  final bool isYoungDriver;
  final Function(bool) onYoungDriverChanged;
  final bool unitMl;
  final Function(bool) onUnitMlChanged;
  final VoidCallback onOfflineLogout;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.accentColor,
    required this.isYoungDriver,
    required this.onYoungDriverChanged,
    required this.unitMl,
    required this.onUnitMlChanged,
    required this.onOfflineLogout,
  });
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  List<Consumption> _allConsumptions = [];
  List<UserProfile> _profiles = [];
  Map<String, String> _contexts = {};
  String _activeUserId = '';
  // On n'a plus besoin du _syncId manuel car on utilise l'ID Supabase
  late DateTime _currentJournalDate;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _currentJournalDate = now.hour < 6
        ? now.subtract(const Duration(days: 1))
        : now;
    _initApp();
    
    // Timer de synchro auto toutes les 30 min (plus économe)
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) => _pushToCloud(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On resynchronise quand l'utilisateur revient sur l'app
      _pullFromCloud();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Sauvegarde vers le cloud uniquement quand l'app passe en arrière-plan
      _pushToCloud(silent: true);
    }
  }

  Future<void> _initApp() async {
    final user = Supabase.instance.client.auth.currentUser;
    final storedUserId = await StorageService.getSupabaseUserId();

    // SECURITE CRITIQUE : Si on détecte un changement de compte, on vide tout le cache local
    if (user != null && storedUserId != null && storedUserId != user.id) {
      debugPrint("Changement de compte détecté : purge du cache local.");
      await StorageService.clearAll();
    }
    
    // On enregistre l'ID actuel pour la prochaine fois
    if (user != null) {
      await StorageService.setSupabaseUserId(user.id);
    }

    final data = await StorageService.loadAppData();

    setState(() {
      _profiles = data['profiles'];
      
      // Si on n'a pas de profil local mais qu'on a des infos d'inscription
      if (_profiles.isEmpty && user != null && user.userMetadata != null) {
        final meta = user.userMetadata!;
        _profiles = [
          UserProfile(
            id: '1',
            name: meta['display_name'] ?? 'Moi',
            gender: meta['gender'] ?? 'Homme',
            age: (meta['age'] as num?)?.toInt() ?? 35,
            weight: (meta['weight'] as num?)?.toInt() ?? 70,
            imagePath: meta['image_path'],
          )
        ];
      } else if (_profiles.isEmpty) {
        _profiles = [UserProfile(id: '1', name: 'Moi', gender: 'Homme', age: 35)];
      }

      _activeUserId = data['activeUserId'];
      _contexts = data['contexts'];
      _allConsumptions = data['consumptions'];
    });
    // On lance une synchro Cloud au démarrage pour être certain d'avoir le dernier état (silencieuse)
    _pullFromCloud(silent: true);
  }

  Future<void> _saveAll({bool silent = true}) async {
    // 1. Mise à jour de l'UI IMMÉDIATE
    if (mounted) setState(() {});

    // 2. Sauvegarde en local (Offline / Cache) en arrière-plan
    StorageService.saveAll(
      profiles: _profiles,
      contexts: _contexts,
      consumptions: _allConsumptions,
      activeUserId: _activeUserId,
    );
  }

  Future<void> _exportFullProject() async {
    final data = {
      'profiles': _profiles.map((e) => e.toJson()).toList(),
      'consumptions': _allConsumptions.map((e) => e.toJson()).toList(),
      'momentsContexts': _contexts,
      'activeUserId': _activeUserId,
    };
    final jsonStr = jsonEncode(data);
    
    if (kIsWeb) {
      final bytes = utf8.encode(jsonStr);
      final xfile = XFile.fromData(bytes, mimeType: 'application/json', name: 'alcohol_tracker_full_backup.json');
      await Share.shareXFiles([xfile], text: 'Sauvegarde complète Alcohol Tracker');
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/alcohol_tracker_full_backup.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Sauvegarde complète Alcohol Tracker');
    }
  }

  Future<void> _deleteProfile(String id) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.s('common.error_last_profile')),
        ),
      );
      return;
    }
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Suppression immédiate sur le cloud
      await SupabaseService.deleteProfile(id, user.id);
    }

    setState(() {
      _profiles.removeWhere((p) => p.id == id);
      _allConsumptions.removeWhere((c) => c.userId == id);
      _contexts.removeWhere((key, value) => key.startsWith("${id}_"));
      if (_activeUserId == id) _activeUserId = _profiles.first.id;
    });
    _saveAll();
  }
  
  void _showAuraSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (isError ? Colors.red : widget.accentColor).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: (isError ? Colors.red : widget.accentColor).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                   Icon(isError ? Icons.error_outline : Icons.cloud_done_rounded, color: isError ? Colors.redAccent : widget.accentColor),
                   const SizedBox(width: 12),
                   Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pushToCloud({bool silent = true}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!silent) _showAuraSnackBar("Veuillez vous connecter pour sauvegarder", isError: true);
      return;
    }
    if (!silent) _showAuraSnackBar("Sauvegarde vers le Cloud...");
    try {
      await SupabaseService.syncProfiles(_profiles, user.id);
      await SupabaseService.syncConsumptions(_allConsumptions, user.id);
      if (!silent) {
        _showAuraSnackBar(L10n.s('sync.success', args: {
          'profiles': _profiles.length.toString(),
          'consos': _allConsumptions.length.toString(),
        }));
      }
    } catch (e) {
      if (!silent) _showAuraSnackBar(L10n.s('sync.error', args: {'message': e.toString()}), isError: true);
    }
  }

  Future<void> _deleteOnlineAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Suppression des données sur le serveur
      await SupabaseService.deleteAllUserData(user.id);
      
      // 2. Déconnexion
      await Supabase.instance.client.auth.signOut();
      
      // 3. Réinitialisation locale pour un nouveau départ propre
      setState(() {
        _profiles = [UserProfile(id: '1', name: 'Moi', gender: 'Homme', age: 35)];
        _allConsumptions.clear();
        _contexts.clear();
        _activeUserId = '1';
      });
      await _saveAll();
      
      _showAuraSnackBar("Compte et données cloud supprimés avec succès.");
    } catch (e) {
      _showAuraSnackBar("Erreur lors de la suppression: $e", isError: true);
    }
  }

  Future<void> _pullFromCloud({bool silent = true}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!silent) _showAuraSnackBar("Veuillez vous connecter pour synchroniser", isError: true);
      return;
    }
    if (!silent) _showAuraSnackBar("Récupération de vos données...");
    try {
      final data = await SupabaseService.fetchAllData(user.id);
      final List<UserProfile> cloudProfiles = data['profiles'] != null ? List<UserProfile>.from(data['profiles']) : [];
      final List<Consumption> cloudConsos = data['consumptions'] != null ? List<Consumption>.from(data['consumptions']) : [];
      
      if (cloudProfiles.isNotEmpty) {
        setState(() {
          _profiles = cloudProfiles;
          _allConsumptions = cloudConsos;
          if (!_profiles.any((p) => p.id == _activeUserId)) {
            _activeUserId = _profiles.first.id;
          }
        });
        await StorageService.saveAll(
          profiles: _profiles,
          contexts: _contexts,
          consumptions: _allConsumptions,
          activeUserId: _activeUserId,
        );
        if (!silent) _showAuraSnackBar(L10n.s('sync.fetch_success', args: {
          'profiles': cloudProfiles.length.toString(),
          'consos': cloudConsos.length.toString(),
        }));
      } else {
        if (!silent) _showAuraSnackBar(L10n.s('sync.no_data', args: {
          'profiles': cloudProfiles.length.toString(),
          'consos': cloudConsos.length.toString(),
        }));
      }
    } catch (e) {
      if (!silent) _showAuraSnackBar(L10n.s('sync.error', args: {'message': e.toString()}), isError: true);
    }
  }

  Future<void> _exportProfile(UserProfile p) async {
    final userConsos = _allConsumptions.where((c) => c.userId == p.id).toList();
    final data = {
      'profile': p.toJson(),
      'consumptions': userConsos.map((e) => e.toJson()).toList(),
    };
    final String jsonString = jsonEncode(data);

    if (kIsWeb) {
      final bytes = utf8.encode(jsonString);
      final xfile = XFile.fromData(bytes, mimeType: 'application/json', name: 'export_${p.name}.json');
      await Share.shareXFiles([xfile], text: 'Export du profil ${p.name}');
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/export_${p.name}.json');
      await file.writeAsString(jsonString);
      await Share.shareXFiles([XFile(file.path)], text: 'Export du profil ${p.name}');
    }
  }

  Future<void> _importToProfile(UserProfile p) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        File file = File(result.files.single.path!);
        content = await file.readAsString();
      }
      final data = jsonDecode(content);
      setState(() {
        // Supporte 'profiles' ou 'Profiles'
        final profilesData = data['profiles'] ?? data['Profiles'];
        if (profilesData != null && (profilesData as List).isNotEmpty) {
          final impP = UserProfile.fromJson(profilesData[0]);
          p.name = impP.name;
          p.age = impP.age;
          p.weight = impP.weight;
          p.gender = impP.gender;
          p.colorValue = impP.colorValue;
        }

        _allConsumptions.removeWhere((c) => c.userId == p.id);
        final importedConsos = (data['consumptions'] as List).map((i) {
          final c = Consumption.fromJson(i);
          c.userId = p.id;
          return c;
        }).toList();
        _allConsumptions.addAll(importedConsos);
      });
      await _saveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profil et données importés pour ${p.name}")),
        );
      }
    }
  }

  Future<void> _importFullProject() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        File file = File(result.files.single.path!);
        content = await file.readAsString();
      }
      final data = jsonDecode(content);
      
      setState(() {
        // Recherche souple des profils
        final profilesData = data['profiles'] ?? data['Profiles'] ?? data['userProfiles'];
        if (profilesData != null) {
          _profiles = (profilesData as List)
              .map((i) => UserProfile.fromJson(i))
              .toList();
        }
        
        // Recherche souple des consommations
        final consosData = data['consumptions'] ?? data['Consumptions'] ?? data['history'] ?? data['consumoires'];
        if (consosData != null) {
          _allConsumptions = (consosData as List)
              .map((i) => Consumption.fromJson(i))
              .toList();
        } else {
          _allConsumptions = [];
        }
        
        _contexts = Map<String, String>.from(data['momentsContexts'] ?? data['contexts'] ?? {});
        
        if (_profiles.isNotEmpty) {
          _activeUserId = _profiles.first.id;
        }
      });
      
      await _saveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.s('sync.restoration_success', args: {
              'profiles': _profiles.length.toString(),
              'consos': _allConsumptions.length.toString(),
            })),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _importAsNewProfile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        File file = File(result.files.single.path!);
        content = await file.readAsString();
      }
      final data = jsonDecode(content);
      
      setState(() {
        dynamic profilesData = data['profiles'] ?? data['profile'] ?? data['Profiles'] ?? data['userProfiles'] ?? data['users'];
        
        if (profilesData == null) {
          try {
            profilesData = data.values.firstWhere((v) => v is List && v.isNotEmpty && v.first['name'] != null);
          } catch (_) { profilesData = null; }
        }

        if (profilesData == null) throw L10n.s('settings.unknown_format');
        if (profilesData is Map) profilesData = [profilesData];
        if ((profilesData as List).isEmpty) throw L10n.s('settings.no_profile_found');

        final newP = UserProfile.fromJson(profilesData[0]);
        newP.id = DateTime.now().millisecondsSinceEpoch.toString();
        _profiles.add(newP);
        
        final importedConsos = (data['consumptions'] as List).map((i) {
          final c = Consumption.fromJson(i);
          c.userId = newP.id;
          return c;
        }).toList();
        _allConsumptions.addAll(importedConsos);
        _activeUserId = newP.id;
      });
      
      await _saveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.s('settings.import_success')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.s('settings.import_failed', args: {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _printProfile(UserProfile p, {DateTime? specificMonth}) async {
    final pdf = pw.Document();
    final userConsos = _allConsumptions.where((c) => c.userId == p.id).toList();

    List<String> monthsToPrint = [];
    if (specificMonth != null) {
      monthsToPrint = [DateFormat('yyyy-MM').format(specificMonth)];
    } else {
      Set<String> activeMonths = {};
      for (var c in userConsos) {
        if (c.date.year <= DateTime.now().year + 1) {
          activeMonths.add(DateFormat('yyyy-MM').format(c.date));
        }
      }
      monthsToPrint = activeMonths.toList()..sort((a, b) => b.compareTo(a));
    }

    for (String monthStr in monthsToPrint) {
      DateTime firstOfMonth = DateTime.parse("$monthStr-01");
      int daysInMonth = DateTime(
        firstOfMonth.year,
        firstOfMonth.month + 1,
        0,
      ).day;
      int firstWeekday = firstOfMonth.weekday - 1;

      var monthConsosTotal = userConsos
          .where((c) => DateFormat('yyyy-MM').format(c.date) == monthStr)
          .toList();
      int totalB = monthConsosTotal.where((c) => c.type == 'Bière').length;
      int totalV = monthConsosTotal.where((c) => c.type == 'Vin').length;
      int totalS = monthConsosTotal.where((c) => c.type == 'Spiritueux').length;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          L10n.s('pdf.journal_title', args: {'name': p.name}),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          DateFormat(
                            'MMMM yyyy',
                            'fr_FR',
                          ).format(firstOfMonth).toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      L10n.s('pdf.summary', args: {'b': '$totalB', 'v': '$totalV', 's': '$totalS'}),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      children:
                          [
                            L10n.s('pdf.days.mon'),
                            L10n.s('pdf.days.tue'),
                            L10n.s('pdf.days.wed'),
                            L10n.s('pdf.days.thu'),
                            L10n.s('pdf.days.fri'),
                            L10n.s('pdf.days.sat'),
                            L10n.s('pdf.days.sun'),
                          ]
                              .map(
                                (d) => pw.Container(
                                  alignment: pw.Alignment.center,
                                  padding: const pw.EdgeInsets.all(4),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                  ),
                                  child: pw.Text(
                                    d,
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    ...List.generate(6, (weekIndex) {
                      return pw.TableRow(
                        children: List.generate(7, (dayIndex) {
                          int currentDay =
                              (weekIndex * 7) + dayIndex - firstWeekday + 1;
                          if (currentDay <= 0 || currentDay > daysInMonth) {
                            return pw.Container();
                          }

                          String dayKey = DateFormat('yyyyMMdd').format(
                            DateTime(
                              firstOfMonth.year,
                              firstOfMonth.month,
                              currentDay,
                            ),
                          );
                          var dayConsos = userConsos
                              .where(
                                (c) =>
                                    DateFormat('yyyyMMdd').format(c.date) ==
                                    dayKey,
                              )
                              .toList();

                          List<String> contextsOfDay = [];
                          for (var m in [
                            L10n.s('moments.morning'),
                            L10n.s('moments.noon'),
                            L10n.s('moments.afternoon'),
                            L10n.s('moments.evening'),
                            L10n.s('moments.night'),
                          ]) {
                            String cKey = "${p.id}_${dayKey}_$m";
                            if (_contexts.containsKey(cKey) &&
                                _contexts[cKey]!.isNotEmpty) {
                              contextsOfDay.add("${m[0]}: ${_contexts[cKey]}");
                            }
                          }

                          return pw.Container(
                            padding: const pw.EdgeInsets.all(3),
                            color:
                                (dayConsos.isNotEmpty ||
                                    contextsOfDay.isNotEmpty)
                                ? PdfColors.orange50
                                : null,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "$currentDay",
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 8,
                                  ),
                                ),
                                ...dayConsos.map(
                                  (c) => pw.Text(
                                    "${c.type[0]} ${c.volume}",
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      color: c.type == L10n.s('common.beer')
                                          ? PdfColors.orange800
                                          : c.type == L10n.s('common.wine')
                                          ? PdfColors.red800
                                          : PdfColors.blue800,
                                    ),
                                  ),
                                ),
                                if (contextsOfDay.isNotEmpty)
                                  pw.Text(
                                    cleanDisplay(contextsOfDay.join("/")),
                                    style: pw.TextStyle(
                                      fontSize: 5,
                                      fontStyle: pw.FontStyle.italic,
                                    ),
                                    maxLines: 3,
                                  ),
                              ],
                            ),
                          );
                        }),
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Journal_${p.name}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeUser = _profiles.firstWhere(
      (p) => p.id == _activeUserId,
      orElse: () => _profiles.first,
    );
    final userConsos = _allConsumptions
        .where((c) => c.userId == _activeUserId)
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              widget.isDarkMode
                  ? 'assets/images/background.jpg'
                  : 'assets/images/light_background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: widget.isDarkMode
                    ? Colors.black
                    : const Color(0xFFF7F3F0),
              ),
            ),
          ),
          Container(
            color: widget.isDarkMode
                ? Colors.transparent 
                : Colors.black.withValues(alpha: 0.15), // Voile léger pour protéger les yeux en Light Mode
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.isDarkMode
                      ? [Colors.black87, Colors.transparent]
                      : [Colors.white.withValues(alpha: 0.9), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 600,
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: glassModule(
                    isDarkMode: widget.isDarkMode,
                    showHalo: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(activeUser.colorValue),
                          radius: 16,
                          backgroundImage: getProfileImage(activeUser.imagePath),
                          child: (activeUser.imagePath == null || activeUser.imagePath!.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "PROFIL",
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode
                                      ? Colors.white38
                                      : Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    activeUser.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode
                                ? Colors.white54
                                : Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 5),
                        PopupMenuButton<String>(
                          tooltip: "Changer de profil",
                          offset: const Offset(0, 40),
                          color: widget.isDarkMode
                              ? const Color(0xFF1A1F26)
                              : Colors.white,
                          icon: Icon(
                            Icons.swap_horiz_rounded,
                            color: widget.accentColor,
                            size: 20,
                          ),
                          onSelected: (id) {
                            setState(() => _activeUserId = id);
                            _saveAll();
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: widget.isDarkMode
                                  ? Colors.white10
                                  : Colors.black12,
                            ),
                          ),
                          itemBuilder: (context) => _profiles
                              .map(
                                (p) => PopupMenuItem(
                                  value: p.id,
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width - 120,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Color(p.colorValue),
                                          radius: 12,
                                          backgroundImage: getProfileImage(p.imagePath),
                                          child: (p.imagePath == null || p.imagePath!.isEmpty)
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: p.id == _activeUserId
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: p.id == _activeUserId
                                                ? widget.accentColor
                                                : null,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (p.id == _activeUserId)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _selectedIndex = index),
                  children: [
                    HomeScreen(
                      consumptions: userConsos,
                      activeUserId: _activeUserId,
                      contexts: _contexts,
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      activeUser: activeUser,
                      onDateSelected: (date) =>
                          setState(() => _currentJournalDate = date),
                      onAddOrUpdate: (c) {
                        final i = _allConsumptions.indexWhere(
                          (item) => item.id == c.id,
                        );
                        if (i != -1) {
                          _allConsumptions[i] = c;
                        } else {
                          _allConsumptions.add(c);
                        }
                        _saveAll();
                      },
                      onDelete: (id) async {
                        setState(() => _allConsumptions.removeWhere((c) => c.id == id));
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          await SupabaseService.deleteConsumption(id, user.id);
                        }
                        _saveAll();
                      },
                      onUpdateContext: (key, val) {
                        setState(() {
                          if (val.trim().isEmpty) {
                            _contexts.remove(key);
                          } else {
                            _contexts[key] = val;
                          }
                        });
                        _saveAll();
                      },
                      onPrint: (m) =>
                          _printProfile(activeUser, specificMonth: m),
                      unitMl: widget.unitMl,
                    ),
                    StatsScreen(
                      consumptions: userConsos,
                      contexts: _contexts,
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      activeUser: activeUser,
                      isYoungDriver: widget.isYoungDriver,
                    ),
                    OptionsScreen(
                      key: ValueKey('opt_${_profiles.length}_$_activeUserId'),
                      profiles: _profiles,
                      onProfilesChanged: _saveAll,
                      onReset: () {
                        setState(() {
                          _allConsumptions.clear();
                          _contexts.clear();
                        });
                        _saveAll();
                      },
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      onThemeChanged: widget.onThemeChanged,
                      onDeleteProfile: _deleteProfile,
                      onExportProfile: _exportProfile,
                      onImportProfile: _importToProfile,
                      onPrintProfile: _printProfile,
                      onImportFullProject: _importFullProject,
                      onImportAsNew: _importAsNewProfile,
                      onExportFullProject: _exportFullProject,
                      isYoungDriver: widget.isYoungDriver,
                      onYoungDriverChanged: widget.onYoungDriverChanged,
                      unitMl: widget.unitMl,
                      onUnitMlChanged: widget.onUnitMlChanged,
                      onSyncCloud: () => _pullFromCloud(silent: false),
                      onPushCloud: () => _pushToCloud(silent: false),
                      onDeleteAccount: _deleteOnlineAccount,
                      onLogout: () async {
                        final session = Supabase.instance.client.auth.currentSession;
                        if (session != null) {
                          await Supabase.instance.client.auth.signOut();
                        } else {
                          widget.onOfflineLogout();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? LiquidGlassFAB(
              accentColor: widget.accentColor,
              onPressed: () {
                final now = DateTime.now();
                String moment = 'Soir';

                // On garde l'heure actuelle mais sur la date sélectionnée
                if (now.hour >= 6 && now.hour < 11) {
                  moment = L10n.s('moments.morning');
                } else if (now.hour >= 11 && now.hour < 15) {
                  moment = L10n.s('moments.noon');
                } else if (now.hour >= 15 && now.hour < 18) {
                  moment = L10n.s('moments.afternoon');
                } else if (now.hour >= 18 && now.hour < 21) {
                  moment = L10n.s('moments.evening');
                } else {
                  moment = L10n.s('moments.night');
                }

                // Utiliser la date du journal, mais avec l'heure actuelle si c'est aujourd'hui
                DateTime finalDate = DateTime(
                  _currentJournalDate.year,
                  _currentJournalDate.month,
                  _currentJournalDate.day,
                  now.hour,
                  now.minute,
                );

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _SaisieSheet(
                    moment: moment,
                    date: finalDate,
                    activeUserId: _activeUserId,
                    onSave: (conso) async {
                      setState(() {
                        _allConsumptions.add(conso);
                      });
                      await _saveAll();
                    },
                    isDarkMode: widget.isDarkMode,
                    accentColor: widget.accentColor,
                    unitMl: widget.unitMl,
                  ),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: widget.isDarkMode
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white,
        selectedItemColor: widget.accentColor,
        unselectedItemColor: widget.isDarkMode
            ? Colors.white24
            : Colors.black26,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: L10n.s('navigation.journal'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: L10n.s('navigation.stats'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: L10n.s('navigation.settings'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Consumption> consumptions;
  final String activeUserId;
  final Map<String, String> contexts;
  final Function(Consumption) onAddOrUpdate;
  final Function(String) onDelete;
  final Function(String, String) onUpdateContext;
  final Function(DateTime) onPrint;
  final bool isDarkMode;
  final Color accentColor;
  final UserProfile activeUser;
  final Function(DateTime)? onDateSelected;
  final bool unitMl;
  const HomeScreen({
    super.key,
    required this.consumptions,
    required this.activeUserId,
    required this.contexts,
    required this.onAddOrUpdate,
    required this.onDelete,
    required this.onUpdateContext,
    required this.onPrint,
    required this.isDarkMode,
    required this.accentColor,
    required this.activeUser,
    this.onDateSelected,
    required this.unitMl,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1200);
  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedDate = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _showSetPartyGoalDialog() {
    String logicalKeyDate = DateFormat('yyyyMMdd').format(_selectedDate);
    String partyKey = "${widget.activeUserId}_${logicalKeyDate}_partyGoal";
    int currentVal = 3;
    if (widget.contexts.containsKey(partyKey)) {
      currentVal = int.tryParse(widget.contexts[partyKey]!) ?? 3;
    }

    int selectedVal = currentVal;

    showDialog(
      context: context,
      barrierColor: Colors.black26, // Plus clair pour mieux voir le flou
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20), // Réduit de 24 à 20
                      decoration: BoxDecoration(
                        color: widget.isDarkMode 
                            ? Colors.white.withValues(alpha: 0.08) // Beaucoup plus transparent
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Material( // Nécessaire pour les InkWells/Buttons
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.nightlife, color: widget.accentColor, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    L10n.s('home.party_goal_title'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15), // Réduit
                            Text(
                              L10n.s('home.party_goal_desc'),
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20), // Réduit
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, size: 40),
                                  color: selectedVal > 1 ? widget.accentColor : Colors.white24,
                                  onPressed: selectedVal > 1 ? () => setStateSB(() => selectedVal--) : null,
                                ),
                                const SizedBox(width: 20),
                                Text(
                                  "$selectedVal",
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: widget.isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, size: 40),
                                  color: selectedVal < 20 ? widget.accentColor : Colors.white24,
                                  onPressed: selectedVal < 20 ? () => setStateSB(() => selectedVal++) : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 25), // Réduit
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: Text(
                                    L10n.s('common.cancel'),
                                    style: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.black54),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    widget.onUpdateContext(partyKey, selectedVal.toString());
                                    Navigator.pop(c);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: Text(L10n.s('home.activate_limit'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildPartyModeWidget() {
    String logicalKeyDate = DateFormat('yyyyMMdd').format(_selectedDate);
    String partyKey = "${widget.activeUserId}_${logicalKeyDate}_partyGoal";
    int? currentGoal;
    
    if (widget.contexts.containsKey(partyKey)) {
      currentGoal = int.tryParse(widget.contexts[partyKey]!);
    }
    
    int currentDrinks = widget.consumptions.where((c) => DateFormat('yyyyMMdd').format(c.date) == logicalKeyDate).length;

    if (currentGoal == null) {
      return GestureDetector(
        onTap: _showSetPartyGoalDialog,
        child: glassModule(
          isDarkMode: widget.isDarkMode,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.nightlife, color: widget.accentColor, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.s('home.activate_goal'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      L10n.s('home.fix_limit'),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: widget.accentColor),
            ],
          ),
        ),
      );
    } else {
      double progress = (currentDrinks / currentGoal).clamp(0.0, 1.0);
      Color progressColor = Colors.green;
      if (progress >= 1.0) {
        progressColor = Colors.redAccent;
      } else if (progress >= 0.7) {
        progressColor = Colors.orange;
      }

      return GestureDetector(
         onTap: _showSetPartyGoalDialog,
         child: glassModule(
          isDarkMode: widget.isDarkMode,
          borderColor: progressColor.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          L10n.s('home.party_goal_title'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          L10n.s('home.drinks_count', args: {
                            'current': currentDrinks.toString(),
                            'goal': currentGoal.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    if (progress >= 1.0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          L10n.s('home.objective_reached'),
                          style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                onPressed: () => widget.onUpdateContext(partyKey, ""),
                tooltip: L10n.s('home.cancel_objective'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.s('home.hello', args: {'name': widget.activeUser.name}),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 15),
          _buildPartyModeWidget(),
          const SizedBox(height: 15),
          glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat(
                        'MMMM yyyy',
                        'fr_FR',
                      ).format(_focusedMonth).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: widget.accentColor,
                          ),
                          onPressed: () => _pageController.animateToPage(
                            _pageController.page!.toInt() - 1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: widget.accentColor,
                          ),
                          onPressed: () => _pageController.animateToPage(
                            _pageController.page!.toInt() + 1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 280,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(
                      () => _focusedMonth = DateTime(
                        DateTime.now().year,
                        DateTime.now().month + (index - 1200),
                      ),
                    ),
                    itemBuilder: (context, index) => _buildHeatmap(
                      DateTime(
                        DateTime.now().year,
                        DateTime.now().month + (index - 1200),
                      ),
                    ),
                  ),
                ),
                _buildMonthlySummary(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => widget.onPrint(_focusedMonth),
                    icon: Icon(
                      Icons.print,
                      size: 16,
                      color: widget.accentColor,
                    ),
                    label: Text(
                      "IMPRIMER CE MOIS (${DateFormat('MMMM', 'fr_FR').format(_focusedMonth).toUpperCase()})",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat(
                'EEEE d MMMM',
                'fr_FR',
              ).format(_selectedDate).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...[
            'Matin',
            'Midi',
            'Après-midi',
            'Soir',
            'Soirée',
          ].map((m) => _momentTile(m)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeatmap(DateTime monthDate) {
    final now = DateTime.now();
    final todayLogical = now.hour < 6
        ? now.subtract(const Duration(days: 1))
        : now;
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstDay = DateTime(monthDate.year, monthDate.month, 1).weekday - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final dayNum = index - firstDay + 1;
        if (dayNum <= 0 || dayNum > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(monthDate.year, monthDate.month, dayNum);

        final isSel =
            date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        final isFuture = date.isAfter(
          DateTime(todayLogical.year, todayLogical.month, todayLogical.day),
        );
        final hasC = widget.consumptions.any(
          (c) => belongsToLogicalDay(c.date, date),
        );

        return GestureDetector(
          onTap: isFuture
              ? null
              : () {
                  setState(() => _selectedDate = date);
                  widget.onDateSelected?.call(date);
                },
          child: Opacity(
            opacity: isFuture ? 0.25 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSel
                  ? widget.accentColor
                  : (hasC
                        ? widget.accentColor.withValues(alpha: 0.4)
                        : (widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03))),
              border: Border.all(
                color: isSel
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  if (isSel)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  if (isSel)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 0.41, 1.0],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      dayNum.toString(),
                      style: TextStyle(
                        fontSize: isSel ? 13 : 10,
                        color: (isSel || hasC)
                            ? Colors.white
                            : (widget.isDarkMode
                                  ? Colors.white38
                                  : Colors.black38),
                        fontWeight: (isSel || hasC)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildMonthlySummary() {
    var monthConsos = widget.consumptions
        .where(
          (c) =>
              c.date.year == _focusedMonth.year &&
              c.date.month == _focusedMonth.month,
        )
        .toList();
    if (monthConsos.isEmpty) return const SizedBox.shrink();

    int totalB = monthConsos.where((c) => c.type == L10n.s('common.beer')).length;
    int totalV = monthConsos.where((c) => c.type == L10n.s('common.wine')).length;
    int totalS = monthConsos.where((c) => c.type == L10n.s('common.spirits')).length;

    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5),
      child: Center(
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _summaryBadge(L10n.s('common.beer'), totalB, Colors.orange),
              _verticalDivider(),
              _summaryBadge(L10n.s('common.wine'), totalV, Colors.redAccent),
              _verticalDivider(),
              _summaryBadge(L10n.s('common.spirits'), totalS, Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBadge(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return VerticalDivider(
      color: (widget.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
      thickness: 1,
      width: 1,
      indent: 4,
      endIndent: 4,
    );
  }

  Widget _momentTile(String moment) {
    String logicalKeyDate = DateFormat('yyyyMMdd').format(_selectedDate);
    final key = "${widget.activeUserId}_${logicalKeyDate}_$moment";
    final momentContext = widget.contexts[key];
    final momentConsos = widget.consumptions
        .where(
          (c) =>
              c.moment == moment && belongsToLogicalDay(c.date, _selectedDate),
        )
        .toList();
    IconData icon = (moment == 'Matin')
        ? Icons.coffee_outlined
        : (moment == 'Midi')
        ? Icons.wb_sunny_outlined
        : (moment == 'Après-midi')
        ? Icons.wb_cloudy_outlined
        : (moment == 'Soir')
        ? Icons.nightlight_round_outlined
        : Icons.local_bar;

    return DragTarget<Consumption>(
      onWillAcceptWithDetails: (details) => details.data.moment != moment,
      onAcceptWithDetails: (details) {
        final Consumption data = details.data;
        final newTime = _SaisieSheet.getDefaultTimeForMoment(moment);
        DateTime baseDate = _selectedDate;
        if (moment == 'Soirée' && newTime.hour < 6) {
          baseDate = baseDate.add(const Duration(days: 1));
        }

        final updated = Consumption(
          id: data.id,
          date: DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            newTime.hour,
            newTime.minute,
          ),
          moment: moment,
          type: data.type,
          volume: data.volume,
          degree: data.degree,
          userId: data.userId,
        );
        widget.onAddOrUpdate(updated);
      },
      builder: (context, candidateData, rejectedData) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedScale(
          scale: candidateData.isNotEmpty ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            borderColor: candidateData.isNotEmpty ? widget.accentColor : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: widget.accentColor, size: 22),
                  title: Text(
                    moment,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () => _showSaisie(moment),
                ),
                GestureDetector(
                  onTap: () => _showContextDialog(moment, momentContext ?? ''),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15, left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            (momentContext != null &&
                                momentContext.trim().isNotEmpty)
                            ? widget.accentColor.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 16,
                          color:
                              (momentContext != null &&
                                  momentContext.trim().isNotEmpty)
                              ? widget.accentColor
                              : (widget.isDarkMode
                                    ? Colors.white24
                                    : Colors.black26),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (momentContext != null &&
                                    momentContext.trim().isNotEmpty)
                                ? cleanDisplay(momentContext)
                                  : L10n.s('journal.add_context'),
                            style: TextStyle(
                              color:
                                  (momentContext != null &&
                                      momentContext.trim().isNotEmpty)
                                  ? (widget.isDarkMode
                                        ? const Color(0xFFB2EBF2)
                                        : Colors.blueGrey)
                                  : (widget.isDarkMode
                                        ? Colors.white24
                                        : Colors.black26),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (momentConsos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: momentConsos
                        .map((c) => _consoDraggable(c))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _consoDraggable(Consumption c) {
    final chip = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              onTap: () {
                final now = DateTime.now();
                // On garde la DATE de la conso d'origine (pour rester sur le même jour logique)
                // mais on prend l'HEURE actuelle.
                final newDate = DateTime(
                  c.date.year,
                  c.date.month,
                  c.date.day,
                  now.hour,
                  now.minute,
                );
                
                widget.onAddOrUpdate(
                  Consumption(
                    id: now.millisecondsSinceEpoch.toString(),
                    date: newDate,
                    moment: getMomentFromTime(TimeOfDay.fromDateTime(newDate)),
                    type: c.type,
                    volume: c.volume,
                    degree: c.degree,
                    userId: c.userId,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Icon(Icons.add_circle, size: 20, color: widget.accentColor),
              ),
            ),
            InkWell(
              onTap: () => _showSaisie(c.moment, existingConso: c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  '${c.type} ${_formatVol(c.volume)} (${DateFormat('HH:mm').format(c.date)})',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
              onTap: () => widget.onDelete(c.id),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(6, 8, 10, 8),
                child: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return LongPressDraggable<Consumption>(
      data: c,
      feedback: Opacity(opacity: 0.8, child: chip),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }

  void _showContextDialog(String moment, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1A1F26)
            : Colors.white,
        title: Text(L10n.s('journal.context_title')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: L10n.s('journal.context_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L10n.s('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              String logicalKeyDate = DateFormat(
                'yyyyMMdd',
              ).format(_selectedDate);
              widget.onUpdateContext(
                "${widget.activeUserId}_${logicalKeyDate}_$moment",
                ctrl.text,
              );
              Navigator.pop(c);
            },
            child: Text(
              L10n.s('common.validate'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaisie(String moment, {Consumption? existingConso}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _SaisieSheet(
        isDarkMode: widget.isDarkMode,
        accentColor: widget.accentColor,
        moment: moment,
        date: _selectedDate,
        activeUserId: widget.activeUserId,
        existingConso: existingConso,
        onSave: (conso) => widget.onAddOrUpdate(conso),
        unitMl: widget.unitMl,
      ),
    );
  }

  String _formatVol(String v) {
    if (!widget.unitMl) return v;
    if (v.contains('cl')) {
      double val = double.tryParse(v.replaceAll('cl', '')) ?? 0;
      return "${(val * 10).toInt()}ml";
    }
    return v;
  }
}

class StatsScreen extends StatefulWidget {
  final List<Consumption> consumptions;
  final Map<String, String> contexts;
  final bool isDarkMode;
  final Color accentColor;
  final UserProfile activeUser;
  final bool isYoungDriver;
  const StatsScreen({
    super.key,
    required this.consumptions,
    required this.contexts,
    required this.isDarkMode,
    required this.accentColor,
    required this.activeUser,
    required this.isYoungDriver,
  });
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _period = 'Semaine'; // will be updated below to use localized keys or stay as is for logic

  double _calculateBACAt(DateTime targetTime) {
    double r = widget.activeUser.gender == 'Homme' ? 0.7 : 0.6;
    double total = 0.0;
    // On prend en compte les consommations des dernières 24h, forcées en local
    final relevantConsos = widget.consumptions
        .where((c) {
          final cDate = c.date.toLocal();
          return targetTime.difference(cDate).inHours < 24 && cDate.isBefore(targetTime);
        })
        .toList();

    for (var c in relevantConsos) {
      final cDate = c.date.toLocal();
      double vol = 0;
      String vStr = c.volume.toLowerCase();
      if (vStr.contains('ml')) {
        vol = (double.tryParse(vStr.replaceAll('ml', '')) ?? 0) / 10.0;
      } else {
        vol = double.tryParse(vStr.replaceAll('cl', '')) ?? 0;
      }
      
      double grammes = (vol * 10 * c.degree * 0.8) / 100;
      double hoursSinceDrink = targetTime.difference(cDate).inMinutes / 60.0;
      double peakBAC = grammes / (widget.activeUser.weight * r);
      
      double bac = 0;
      // Phase montante (boisson + absorption) : max à 45 mins
      if (hoursSinceDrink <= 0.75) {
        bac = peakBAC * (hoursSinceDrink / 0.75);
      } else {
        // Phase d'élimination (0.15g/L par heure)
        bac = peakBAC - (0.15 * (hoursSinceDrink - 0.75));
      }
      if (bac > 0) total += bac;
    }
    return total;
  }

  double _calculateCurrentBAC() => _calculateBACAt(DateTime.now());

  Widget _buildBACCurve() {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    double maxBAC = 0.5;

    // On génère des points toutes les 15 minutes sur 12 heures (-1h à +11h)
    for (int i = -4; i <= 44; i++) {
      DateTime t = now.add(Duration(minutes: i * 15));
      double val = _calculateBACAt(t);
      if (val > maxBAC) maxBAC = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
              "ÉVOLUTION (12H)",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
                letterSpacing: 1.2,
              ),
            ),
            if (spots.any((s) => s.y > 0.01))
               Icon(Icons.auto_graph, size: 12, color: widget.accentColor.withValues(alpha: 0.5)),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 100,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 12, // Toutes les 3 heures
                    getTitlesWidget: (v, m) {
                      DateTime t = now.add(Duration(minutes: v.toInt() * 15));
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          DateFormat('HH:mm').format(t),
                          style: TextStyle(color: widget.isDarkMode ? Colors.white30 : Colors.black26, fontSize: 8),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: maxBAC * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: widget.accentColor,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.accentColor.withValues(alpha: 0.3),
                        widget.accentColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Ligne de seuil
                LineChartBarData(
                  spots: [
                    FlSpot(-4, widget.isYoungDriver ? 0.2 : 0.5),
                    FlSpot(44, widget.isYoungDriver ? 0.2 : 0.5),
                  ],
                  dashArray: [5, 5],
                  barWidth: 1,
                  color: Colors.red.withValues(alpha: 0.3),
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double currentBac = _calculateCurrentBAC();
    double threshold = widget.isYoungDriver ? 0.2 : 0.5;
    bool isDanger = currentBac >= threshold;
    String countdownText = currentBac > threshold
        ? L10n.s('stats.countdown_format', args: {
            'h': ((currentBac - threshold) / 0.15).floor().toString(),
            'm': (((currentBac - threshold) / 0.15 - ((currentBac - threshold) / 0.15).floor()) * 60).round().toString(),
          })
        : L10n.s('stats.ready_to_drive');
    final now = DateTime.now();
    final countedDrinks = widget.consumptions
        .where(
          (c) => now.difference(c.date).inHours < 12 && c.date.isBefore(now),
        )
        .toList();

    int daysToLookBack = (_period == 'Semaine')
        ? 7
        : (_period == 'Mois')
        ? 30
        : 365;
    DateTime startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToLookBack - 1));
    Set<String> datesWithDrinks = widget.consumptions
        .where((c) => !c.date.isBefore(startDate))
        .map((c) => "${c.date.year}-${c.date.month}-${c.date.day}")
        .toSet();
    int dryDays = daysToLookBack - datesWithDrinks.length;
    double totalGrams = 0;
    for (var c in widget.consumptions.where(
      (c) => !c.date.isBefore(startDate),
    )) {
      double vol = 0;
      String vStr = c.volume.toLowerCase();
      if (vStr.contains('ml')) {
        vol = (double.tryParse(vStr.replaceAll('ml', '')) ?? 0) / 10.0;
      } else {
        vol = double.tryParse(vStr.replaceAll('cl', '')) ?? 0;
      }
      double grammes = (vol * 10 * c.degree * 0.8) / 100;
      totalGrams += grammes;
    }
    int unities = (totalGrams / 10).round();

    int countTotalGoals = 0;
    int countSuccessGoals = 0;
    
    widget.contexts.keys.where((k) => k.startsWith("${widget.activeUser.id}_") && k.endsWith("_partyGoal")).forEach((k) {
      var parts = k.split('_');
      if (parts.length >= 3) {
        String dateStr = parts[1];
        if (dateStr.length == 8) {
          int year = int.tryParse(dateStr.substring(0,4)) ?? 0;
          int month = int.tryParse(dateStr.substring(4,6)) ?? 0;
          int day = int.tryParse(dateStr.substring(6,8)) ?? 0;
          if (year > 0) {
            DateTime d = DateTime(year, month, day);
            if (!d.isBefore(startDate)) {
              countTotalGoals++;
              int goal = int.tryParse(widget.contexts[k]!) ?? 0;
              int drinksCount = widget.consumptions.where((c) {
                return c.date.year == d.year && c.date.month == d.month && c.date.day == d.day;
              }).length;
              if (drinksCount <= goal) countSuccessGoals++;
            }
          }
        }
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              children: [
                Text(
                  L10n.s('stats.bac_estimated'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 110,
                      width: 110,
                      child: CircularProgressIndicator(
                        value: (currentBac / 1.5).clamp(0, 1),
                        strokeWidth: 8,
                        color: isDanger ? Colors.red : widget.accentColor,
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    Text(
                      currentBac.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isDanger 
                      ? L10n.s('stats.danger_threshold', args: {'threshold': threshold.toStringAsFixed(1)}) 
                      : L10n.s('stats.safety_ok'),
                  style: TextStyle(
                    color: isDanger ? Colors.red : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (countedDrinks.isNotEmpty) ...[
                  const Divider(height: 30),
                  Text(
                    L10n.s('stats.counted_drinks'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                  ...countedDrinks.map(
                    (c) => Text(
                      "• ${c.type} (${DateFormat('HH:mm').format(c.date)})",
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDarkMode
                            ? Colors.white54
                            : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _showBACMethodInfo,
                    child: Text(
                      "Comment est calculé mon taux ?",
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 15),
          glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            borderColor: isDanger
                ? Colors.red.withValues(alpha: 0.3)
                : (currentBac > 0 ? Colors.orange.withValues(alpha: 0.3) : widget.accentColor.withValues(alpha: 0.3)),
            child: Column(
              children: [
                Text(
                  L10n.s('stats.return_to_legal'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDanger
                          ? Icons.timer_outlined
                          : Icons.check_circle_outline,
                      size: 20,
                      color: isDanger ? Colors.redAccent : Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      countdownText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDanger
                            ? (widget.isDarkMode ? Colors.white : Colors.black)
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            child: _buildBACCurve(),
          ),
          const SizedBox(height: 15),
          // AGENT: BOUTON TEST RÉFLEXES PROÉMINENT
          GestureDetector(
            onTap: _showSobrietyTestFromStats,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.accentColor,
                    const Color(0xFFE94E77),
                  ], // Dégradé dynamique
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.white, size: 28),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.s('stats.reflex_btn'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          L10n.s('stats.reflex_desc'),
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Text(
              L10n.s('stats.disclaimer'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.s('stats.title_period', args: {
                      'period': _period == 'Semaine' ? L10n.s('stats.periods.week') : (_period == 'Mois' ? L10n.s('stats.periods.month') : L10n.s('stats.periods.year'))
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.s('stats.date_range', args: {
                      'start': DateFormat('dd MMM').format(startDate),
                      'end': DateFormat('dd MMM').format(now),
                    }),
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: widget.isDarkMode
                          ? Colors.white54
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [L10n.s('stats.periods.week'), L10n.s('stats.periods.month'), L10n.s('stats.periods.year')].map((localizedP) {
                    // Logic mapping back to original keys if necessary, or just use indices
                    String p;
                    if (localizedP == L10n.s('stats.periods.week')) {
                      p = 'Semaine';
                    } else if (localizedP == L10n.s('stats.periods.month')) {
                      p = 'Mois';
                    } else {
                      p = 'Année';
                    }
                    
                    bool isSelected = _period == p;
                    return GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (widget.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected && !widget.isDarkMode
                              ? const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? (widget.isDarkMode
                                      ? Colors.white
                                      : Colors.black)
                                : (widget.isDarkMode
                                      ? Colors.white54
                                      : Colors.black54),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: glassModule(
                  isDarkMode: widget.isDarkMode,
                  showHalo: false,
                  child: Column(
                    children: [
                      Text(
                        L10n.s('stats.green_days'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$dryDays",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      Text(
                        L10n.s('stats.days_count', args: {'count': daysToLookBack.toString()}),
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.isDarkMode
                              ? Colors.white54
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: glassModule(
                  isDarkMode: widget.isDarkMode,
                  showHalo: false,
                  child: Column(
                    children: [
                      Text(
                        L10n.s('stats.who_units'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$unities",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      Text(
                        L10n.s('stats.std_drinks'),
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.isDarkMode
                              ? Colors.white54
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (countTotalGoals > 0) ...[
            glassModule(
              isDarkMode: widget.isDarkMode,
              showHalo: false,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: countSuccessGoals == countTotalGoals ? Colors.green.withValues(alpha: 0.2) : widget.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      countSuccessGoals == countTotalGoals ? Icons.emoji_events : Icons.track_changes,
                      color: countSuccessGoals == countTotalGoals ? Colors.green : widget.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.s('stats.goals_respected'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: countSuccessGoals == countTotalGoals ? Colors.green : widget.accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$countSuccessGoals / $countTotalGoals",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          L10n.s('stats.goals_count'),
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 45,
                    width: 45,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: countSuccessGoals / countTotalGoals,
                          color: countSuccessGoals == countTotalGoals ? Colors.green : widget.accentColor,
                          backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.black12,
                          strokeWidth: 4,
                        ),
                        Center(
                          child: Text(
                            "${((countSuccessGoals / countTotalGoals) * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              L10n.s('stats.who_info'),
              style: TextStyle(
                fontSize: 9,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: widget.isDarkMode ? Colors.white54 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 15),
          glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.s('stats.trend'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: LineChart(_axisOnlyData())),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: (_period == 'Mois')
                                ? 800
                                : MediaQuery.of(context).size.width - 100,
                            child: LineChart(_mainChartData()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    L10n.s('stats.global_split'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      Expanded(child: PieChart(_buildPieData())),
                      const SizedBox(width: 20),
                      _buildPieLegend(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showBACMethodInfo() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: glassModule(
          isDarkMode: widget.isDarkMode,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.biotech, color: widget.accentColor, size: 28),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "Calcul de l'alcoolémie",
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text(
                    "Cette application utilise une Version 1.1.9+13",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.5,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildInfoSection(
                    "1. La base (Formule de Widmark)",
                    "Le calcul standard repose sur votre poids, votre sexe et la quantité d'alcool pur (en grammes) ingérée.",
                  ),
                  const Divider(height: 40, color: Colors.white12),
                  _buildInfoSection(
                    "2. Phase d'absorption progressive",
                    "Contrairement aux calculs simplistes qui considèrent que l'alcool est dans le sang dès la première gorgée, notre modèle simule une montée linéaire sur 45 minutes. Cela reflète le temps réel de consommation et le délai biologique d'absorption.",
                  ),
                  const Divider(height: 40, color: Colors.white12),
                  _buildInfoSection(
                    "3. Élimination constante",
                    "Une fois le pic atteint, votre organisme élimine l'alcool à un rythme moyen de 0,15 g/L par heure.",
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const Text(
                            "ATTENTION : Il s'agit d'une estimation théorique. La fatigue, l'alimentation et la santé peuvent modifier ces valeurs. Ne remplace jamais un éthylotest.",
                            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          side: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "J'ai compris", 
                          style: TextStyle(
                            color: widget.accentColor, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontSize: 16,
                          )
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: widget.isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  void _showSobrietyTestFromStats() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => SobrietyTestSheet(
        isDarkMode: widget.isDarkMode,
        accentColor: widget.accentColor,
      ),
    );
  }

  LineChartData _axisOnlyData() {
    int count = (_period == 'Semaine')
        ? 7
        : (_period == 'Mois')
        ? 30
        : 12;
    double maxFound = 0;
    DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    for (int i = 0; i < count; i++) {
      DateTime d = (_period == 'Année')
          ? DateTime(today.year, today.month - (count - 1 - i), 1)
          : today.subtract(Duration(days: (count - 1) - i));
      
      double dayUnits = 0;
      final dayConsos = widget.consumptions.where((c) => (_period == 'Année')
                ? (c.date.year == d.year && c.date.month == d.month)
                : belongsToLogicalDay(c.date, d));

      for (var c in dayConsos) {
        double vol = 0;
        String vStr = c.volume.toLowerCase();
        if (vStr.contains('ml')) {
          vol = (double.tryParse(vStr.replaceAll('ml', '')) ?? 0) / 10.0;
        } else {
          vol = double.tryParse(vStr.replaceAll('cl', '')) ?? 0;
        }
        dayUnits += (vol * 10 * c.degree * 0.8) / 1000.0; // En unités (10g)
      }

      if (dayUnits > maxFound) maxFound = dayUnits;
    }
    double sharedMaxY = maxFound < 5 ? 6 : maxFound + 2;

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            reservedSize: 40,
            getTitlesWidget: (v, m) => Text(
              '${v.toInt()}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 8),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (_, _) => const SizedBox(),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: sharedMaxY,
      lineBarsData: [
        LineChartBarData(spots: [const FlSpot(0, 0)], show: false),
      ],
    );
  }

  LineChartData _mainChartData() {
    int count = (_period == 'Semaine')
        ? 7
        : (_period == 'Mois')
        ? 30
        : 12;
    List<FlSpot> spots = [];
    double maxFound = 0;
    DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    for (int i = 0; i < count; i++) {
      DateTime d = (_period == 'Année')
          ? DateTime(today.year, today.month - (count - 1 - i), 1)
          : today.subtract(Duration(days: (count - 1) - i));
      
      double dayUnits = 0;
      final dayConsos = widget.consumptions.where((c) => (_period == 'Année')
                ? (c.date.year == d.year && c.date.month == d.month)
                : belongsToLogicalDay(c.date, d));

      for (var c in dayConsos) {
        double vol = 0;
        String vStr = c.volume.toLowerCase();
        if (vStr.contains('ml')) {
          vol = (double.tryParse(vStr.replaceAll('ml', '')) ?? 0) / 10.0;
        } else {
          vol = double.tryParse(vStr.replaceAll('cl', '')) ?? 0;
        }
        dayUnits += (vol * 10 * c.degree * 0.8) / 1000.0; // En unités (10g)
      }

      if (dayUnits > maxFound) maxFound = dayUnits;
      spots.add(FlSpot(i.toDouble(), dayUnits));
    }
    double sharedMaxY = maxFound < 5 ? 6 : maxFound + 2;

    return LineChartData(
      minX: 0,
      maxX: (count - 1).toDouble(),
      minY: 0,
      maxY: sharedMaxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (v) => FlLine(
          color: widget.isDarkMode ? Colors.white10 : Colors.black12,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 40,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx < 0 || idx >= count) return const SizedBox.shrink();
              DateTime d = (_period == 'Année')
                  ? DateTime(today.year, today.month - (count - 1 - idx), 1)
                  : today.subtract(Duration(days: (count - 1) - idx));
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('E', 'fr_FR').format(d)[0].toUpperCase(),
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM').format(d),
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 7),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          barWidth: 2.0,
          gradient: LinearGradient(
            colors: widget.isDarkMode
                ? const [Color(0xFFFFB74D), Color(0xFFFF9800)]
                : const [
                    Color(0xFFFF5722),
                    Color(0xFFD84315),
                  ], // Deeper orange/red for contrast
          ),
          shadow: BoxShadow(
            color: widget.isDarkMode
                ? const Color(0xFFFF9800).withValues(alpha: 0.4)
                : const Color(
                    0xFFE64A19,
                  ).withValues(alpha: 0.4), // Stronger shadow in light mode
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              // Highlight only the last point to mimic the blue reference image
              if (index != spots.length - 1) {
                return FlDotCirclePainter(
                  radius: 0,
                  color: Colors.transparent,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              }
              return FlDotCirclePainter(
                radius: 6,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: widget.isDarkMode
                    ? const Color(0xFFFF9800)
                    : const Color(0xFFD84315),
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.redAccent.withValues(alpha: widget.isDarkMode ? 0.6 : 0.4),
                Colors.orange.withValues(alpha: widget.isDarkMode ? 0.2 : 0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  PieChartData _buildPieData() {
    Map<String, int> counts = {'Bière': 0, 'Vin': 0, 'Spiritueux': 0};
    for (var c in widget.consumptions) {
      if (counts.containsKey(c.type)) counts[c.type] = counts[c.type]! + 1;
    }
    int total = counts.values.reduce((a, b) => a + b);
    return PieChartData(
      sectionsSpace: 4,
      centerSpaceRadius: 35,
      sections: counts.entries
          .map(
            (e) => PieChartSectionData(
              value: e.value.toDouble(),
              gradient: e.key == 'Bière'
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFFD93B),
                        Color(0xFFEA9216),
                        Color(0xFFD37C0E),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : (e.key == 'Vin'
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF8282),
                              Color(0xFFFF1744),
                              Color(0xFFA11736),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF90CAF9),
                              Color(0xFF2196F3),
                              Color(0xFF0F57A3),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )),
              title: total > 0 ? '${(e.value / total * 100).round()}%' : '',
              radius: 25,
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPieLegend() {
    Map<String, int> counts = {'Bière': 0, 'Vin': 0, 'Spiritueux': 0};
    for (var c in widget.consumptions) {
      if (counts.containsKey(c.type)) counts[c.type] = counts[c.type]! + 1;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: counts.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: e.key == 'Bière'
                          ? const LinearGradient(
                              colors: [Color(0xFFEA9216), Color(0xFFFFD93B)],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            )
                          : (e.key == 'Vin'
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF1744),
                                      Color(0xFFFF8282),
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF2196F3),
                                      Color(0xFF90CAF9),
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${e.key}: ",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${e.value}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class OptionsScreen extends StatefulWidget {
  final List<UserProfile> profiles;
  final VoidCallback onProfilesChanged;
  final VoidCallback onReset;
  final bool isDarkMode;
  final Color accentColor;
  final Function(bool) onThemeChanged;
  final Function(String) onDeleteProfile;
  final Function(UserProfile) onExportProfile;
  final Function(UserProfile) onImportProfile;
  final Function(UserProfile) onPrintProfile;
  final Future<void> Function() onImportFullProject;
  final Future<void> Function() onImportAsNew;
  final Future<void> Function() onExportFullProject;
  final bool isYoungDriver;
  final Function(bool) onYoungDriverChanged;
  final bool unitMl;
  final Function(bool) onUnitMlChanged;
  final VoidCallback? onSyncCloud;
  final VoidCallback? onPushCloud;
  final VoidCallback? onDeleteAccount;
  final VoidCallback onLogout;

  const OptionsScreen({
    super.key,
    required this.profiles,
    required this.onProfilesChanged,
    required this.onReset,
    required this.isDarkMode,
    required this.accentColor,
    required this.onThemeChanged,
    required this.onDeleteProfile,
    required this.onExportProfile,
    required this.onImportProfile,
    required this.onPrintProfile,
    required this.onImportFullProject,
    required this.onImportAsNew,
    required this.onExportFullProject,
    required this.isYoungDriver,
    required this.onYoungDriverChanged,
    required this.unitMl,
    required this.onUnitMlChanged,
    this.onSyncCloud,
    this.onPushCloud,
    this.onDeleteAccount,
    required this.onLogout,
  });
  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final ImagePicker _picker = ImagePicker();
  Future<void> _pickImage(UserProfile p) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => p.imagePath = base64Encode(bytes));
      widget.onProfilesChanged();
    }
  }

  void _editProfile(UserProfile? p) {
    final nameCtrl = TextEditingController(text: p?.name ?? '');
    final ageCtrl = TextEditingController(text: p?.age.toString() ?? '35');
    final weightCtrl = TextEditingController(
      text: p?.weight.toString() ?? '70',
    );
    String gender = p?.gender ?? 'Homme';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (cxt) => Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(cxt).viewInsets.bottom + 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p == null ? "NOUVEAU PROFIL" : "MODIFIER PROFIL",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Prénom"),
            ),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (context, setST) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Homme', 'Femme']
                    .map(
                      (g) => ChoiceChip(
                        label: Text(g),
                        selected: gender == g,
                        onSelected: (s) => setST(() => gender = g),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ageCtrl,
                    decoration: const InputDecoration(labelText: "Âge"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    decoration: const InputDecoration(labelText: "Poids (kg)"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (p == null) {
                    widget.profiles.add(
                      UserProfile(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text,
                        gender: gender,
                        age: int.tryParse(ageCtrl.text) ?? 35,
                        weight: int.tryParse(weightCtrl.text) ?? 70,
                      ),
                    );
                  } else {
                    p.name = nameCtrl.text;
                    p.gender = gender;
                    p.age = int.tryParse(ageCtrl.text) ?? 35;
                    p.weight = int.tryParse(weightCtrl.text) ?? 70;
                  }
                  widget.onProfilesChanged();
                  Navigator.pop(cxt);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("ENREGISTRER"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: (widget.isDarkMode ? const Color(0xFF14191F) : Colors.white).withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "POLITIQUE DE CONFIDENTIALITÉ",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        Text(
                          "Dernière mise à jour : 18 Avril 2026\n",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Text(
                          L10n.s('legal_content.privacy_intro'),
                          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                        _infoSection(
                          L10n.s('legal_content.privacy_section1_title'),
                          L10n.s('legal_content.privacy_section1_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.privacy_section2_title'),
                          L10n.s('legal_content.privacy_section2_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.privacy_section3_title'),
                          L10n.s('legal_content.privacy_section3_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.privacy_section4_title'),
                          L10n.s('legal_content.privacy_section4_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.privacy_section5_title'),
                          L10n.s('legal_content.privacy_section5_body'),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLegalInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: (widget.isDarkMode ? const Color(0xFF14191F) : Colors.white).withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "INFORMATIONS LÉGALES",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _infoSection(
                          L10n.s('legal_content.info_section1_title'),
                          L10n.s('legal_content.info_section1_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.info_section2_title'),
                          L10n.s('legal_content.info_section2_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.info_section3_title'),
                          L10n.s('legal_content.info_section3_body'),
                        ),
                        _infoSection(
                          L10n.s('legal_content.info_section4_title'),
                          L10n.s('legal_content.info_section4_body'),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDonationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),
            Text(
              L10n.s('settings.support_title'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              L10n.s('settings.support_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse(
                    "https://www.paypal.com/paypalme/chriskprodigeee",
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(L10n.s('settings.paypal_error')),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: Text(
                  L10n.s('settings.paypal_btn'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              L10n.s('settings.donation_notice'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: widget.isDarkMode ? Colors.white38 : Colors.black45,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCreditsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/terrasse_credits.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.black12),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                    ),
                    Text(
                      L10n.s('settings.credits_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 160),
                    glassModule(
                      isDarkMode: true,
                      showHalo: false,
                      child: Column(
                        children: [
                          const Text(
                            "Journal Conso",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            L10n.s('settings.author_text'),
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            L10n.s('settings.contact_text'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "journalconso@gmail.com",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    glassModule(
                      isDarkMode: true,
                      showHalo: false,
                      child: ListTile(
                        dense: true,
                        title: Center(
                          child: Text(
                            L10n.s('common.close'),
                            style: TextStyle(
                              color: widget.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String title, String content) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final itemTxt = widget.isDarkMode ? Colors.white : Colors.black87;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ---------------------------
        Text(
          L10n.s('settings.profiles_header'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.profiles.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final p = widget.profiles.removeAt(oldIndex);
              widget.profiles.insert(newIndex, p);
            });
            widget.onProfilesChanged();
          },
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, index) {
            final p = widget.profiles[index];
            return Padding(
              key: ValueKey(p.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: glassModule(
                isDarkMode: widget.isDarkMode,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                                size: 20,
                              ),
                            ),
                          ),
                          Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(p.colorValue),
                                radius: 24,
                                backgroundImage: getProfileImage(p.imagePath),
                                child: (p.imagePath == null || p.imagePath!.isEmpty)
                                    ? const Icon(Icons.person, color: Colors.white)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => _pickImage(p),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: widget.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: itemTxt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${p.age} ans • ${p.weight}kg",
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.white38
                              : Colors.black54,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: widget.accentColor,
                          size: 20,
                        ),
                        onPressed: () => _editProfile(p),
                      ),
                    ),
                    const Divider(height: 20, color: Colors.white10),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _miniAction(
                          Icons.upload,
                          L10n.s('common.export'),
                          () => widget.onExportProfile(p),
                        ),
                        _miniAction(
                          Icons.download,
                          L10n.s('common.import'),
                          () => widget.onImportProfile(p),
                        ),
                        _miniAction(
                          Icons.print,
                          L10n.s('common.print'),
                          () => widget.onPrintProfile(p),
                        ),
                        _miniAction(
                          Icons.delete_outline,
                          L10n.s('common.delete'),
                          () => _confirmDelete(p),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: glassModule(
                isDarkMode: widget.isDarkMode,
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.person_add_alt_1, color: widget.accentColor, size: 20),
                   title: Text(
                    L10n.s('settings.create_profile'),
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  onTap: () => _editProfile(null),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: glassModule(
                isDarkMode: widget.isDarkMode,
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.file_download_outlined, color: widget.accentColor, size: 20),
                  title: Text(
                    L10n.s('settings.import_json_profile'),
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  onTap: widget.onImportAsNew,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        glassModule(
          isDarkMode: widget.isDarkMode,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, color: widget.accentColor, size: 24),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L10n.s('settings.account_connected'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.accentColor, letterSpacing: 1.1)),
                          Text(
                            Supabase.instance.client.auth.currentUser?.email ?? "Utilisateur",
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onLogout,
                      child: Text(L10n.s('settings.logout'), style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ],
                ),
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.cloud_upload_rounded, color: widget.accentColor),
                title: Text(
                  L10n.s('settings.save_cloud'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text(L10n.s('settings.save_cloud_desc'), style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
                onTap: widget.onPushCloud,
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.cloud_download_rounded, color: widget.accentColor),
                title: Text(
                  L10n.s('settings.sync_cloud'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text(L10n.s('settings.sync_cloud_desc'), style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
                onTap: widget.onSyncCloud,
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.cloud_upload_outlined, color: widget.accentColor),
                title: Text(
                  L10n.s('legal.save_json'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text("Exporter une sauvegarde locale sur cet appareil", style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
                onTap: widget.onExportFullProject,
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.restore, color: widget.accentColor),
                title: Text(
                  L10n.s('legal.restore_json'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text("Restaurer depuis un fichier JSON local", style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
                onTap: widget.onImportFullProject,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          L10n.s('settings.global_prefs'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        glassModule(
          isDarkMode: widget.isDarkMode,
          showHalo: false,
          child: Column(
            children: [
              SwitchListTile(
                dense: true,
                title: Text(
                  widget.isDarkMode ? L10n.s('settings.theme_dark') : L10n.s('settings.theme_light'),
                  style: TextStyle(color: itemTxt, fontSize: 13),
                ),
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
                secondary: Icon(
                  widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: widget.accentColor,
                  size: 20,
                ),
              ),
              _divider(),
              SwitchListTile(
                dense: true,
                secondary: Icon(Icons.warning_amber_rounded, color: widget.accentColor, size: 20),
                title: Text(L10n.s('settings.young_driver'), style: const TextStyle(fontSize: 13)),
                value: widget.isYoungDriver,
                onChanged: widget.onYoungDriverChanged,
              ),
              _divider(),
              SwitchListTile(
                dense: true,
                secondary: Icon(Icons.straighten, color: widget.accentColor, size: 20),
                title: Text(L10n.s('settings.unit_ml'), style: const TextStyle(fontSize: 13)),
                value: widget.unitMl,
                onChanged: widget.onUnitMlChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          L10n.s('settings.about_legal'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        glassModule(
          isDarkMode: widget.isDarkMode,
          showHalo: false,
          child: Column(
            children: [
              _legalTile(
                Icons.help_outline,
                L10n.s('legal.guide'),
                _showUserGuide,
              ),
              _divider(),
              _legalTile(
                Icons.privacy_tip_outlined,
                L10n.s('legal.privacy'),
                _showPrivacyPolicy,
              ),
              _divider(),
              _legalTile(
                Icons.gavel_outlined,
                L10n.s('legal.info'),
                _showLegalInfo,
              ),
              _divider(),
              _legalTile(
                Icons.favorite_outline,
                L10n.s('legal.support'),
                _showDonationDialog,
              ),
              _divider(),
              _legalTile(
                Icons.info_outline,
                L10n.s('legal.credits'),
                _showCreditsDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          L10n.s('settings.danger_zone'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        glassModule(
          isDarkMode: widget.isDarkMode,
          showHalo: false,
          borderColor: Colors.redAccent.withValues(alpha: 0.3),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(
              L10n.s('settings.reset_all'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: () => _confirmFullReset(),
          ),
        ),
        if (Supabase.instance.client.auth.currentUser != null) ...[
          const SizedBox(height: 10),
          glassModule(
            isDarkMode: widget.isDarkMode,
            showHalo: false,
            borderColor: Colors.redAccent.withValues(alpha: 0.3),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_off, color: Colors.redAccent),
              title: const Text(
                "Supprimer mon compte & mes données",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onTap: () => _showDeleteAccountConfirm(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: Text(
            "Version 1.1.9+13",
            style: TextStyle(
              fontSize: 10,
              color: widget.isDarkMode ? Colors.white24 : Colors.black26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  void _confirmFullReset() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(L10n.s('settings.reset_confirm_title')),
        content: Text(
          L10n.s('settings.reset_confirm_content'),
        ),
            child: const Text(
              "TOUT SUPPRIMER",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirm() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Supprimer le compte ?"),
        content: const Text(
          "Cette action est irréversible. Vos données seront définitivement effacées du cloud et votre application sera réinitialisée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L10n.s('common.cancel').toUpperCase()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (widget.onDeleteAccount != null) {
                widget.onDeleteAccount!();
              }
            },
            child: const Text(
              "SUPPRIMER MON COMPTE",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



  void _showUserGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultTabController(
        length: 3,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: (widget.isDarkMode ? const Color(0xFF14191F) : Colors.white).withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
                ),
                child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "NOTICE D'UTILISATION",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: widget.accentColor,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                TabBar(
                  dividerColor: Colors.transparent,
                  indicatorColor: widget.accentColor,
                  labelColor: widget.accentColor,
                  unselectedLabelColor: widget.isDarkMode ? Colors.white38 : Colors.black38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: "Journal"),
                    Tab(text: "Stats"),
                    Tab(text: "Réglages"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildGuideTab(scrollController, [
                        _guideStep(Icons.add_circle_outline, L10n.s('guide.step1_title'), L10n.s('guide.step1_desc')),
                        _guideStep(Icons.edit_note_rounded, L10n.s('guide.step2_title'), L10n.s('guide.step2_desc')),
                        _guideStep(Icons.copy_rounded, "Duplication intelligente", "Gagnez du temps en dupliquant un verre ou même une série complète en un clic."),
                        _guideStep(Icons.timelapse, "Journal 24h", "Parcourez votre journée. Les tranches horaires s'adaptent dynamiquement à vos consommations."),
                      ]),
                      _buildGuideTab(scrollController, [
                        _guideStep(Icons.analytics_outlined, "Alcoolémie Réaliste", "Votre taux n'est pas instantané. Nous simulons une montée linéaire sur 45 min pour refléter le temps de boisson et d'absorption."),
                        _guideStep(Icons.directions_car_filled_outlined, "Prêt à conduire ?", "L'application calcule en temps réel quand votre taux repassera sous le seuil légal (jeune permis ou confirmé)."),
                        _guideStep(Icons.calendar_month_outlined, "Calendrier & PDF", "Visualisez votre activité mensuelle et exportez des rapports PDF professionnels pour un suivi médical ou personnel."),
                        _guideStep(Icons.psychology_outlined, L10n.s('guide.step3_title'), L10n.s('guide.step3_desc')),
                      ]),
                      _buildGuideTab(scrollController, [
                        _guideStep(Icons.people_outline, L10n.s('guide.step4_title'), L10n.s('guide.step4_desc')),
                        _guideStep(Icons.cloud_done_outlined, L10n.s('guide.step6_title'), L10n.s('guide.step6_desc')),
                        _guideStep(Icons.security_outlined, "Vie Privée", "Vos données de santé sont les vôtres. Elles restent anonymisées et chiffrées sur nos serveurs Supabase."),
                        _guideStep(Icons.style_outlined, L10n.s('guide.step8_title'), L10n.s('guide.step8_desc')),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}


  Widget _buildGuideTab(ScrollController sc, List<Widget> steps) {
    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: steps,
    );
  }

  Widget _guideStep(IconData icon, String title, String desc) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (widget.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: widget.accentColor.withValues(alpha: 0.1)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: widget.accentColor, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.accentColor),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(fontSize: 13, height: 1.4, color: widget.isDarkMode ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _miniAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16, color: color ?? widget.accentColor),
    label: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: color ?? (widget.isDarkMode ? Colors.white70 : Colors.black54),
      ),
    ),
  );
  Widget _legalTile(IconData icon, String title, VoidCallback onTap) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: widget.accentColor, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: widget.isDarkMode ? Colors.white24 : Colors.black12,
          size: 18,
        ),
        onTap: onTap,
      );
  Widget _divider() => Divider(
    height: 1,
    color: widget.isDarkMode ? Colors.white10 : Colors.black12,
  );
  void _confirmDelete(UserProfile p) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Supprimer le profil ?"),
        content: Text(
          "Toutes les consommations de ${p.name} seront effacées définitivement.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L10n.s('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteProfile(p.id);
              Navigator.pop(c);
            },
            child: Text(
              L10n.s('common.delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaisieSheet extends StatefulWidget {
  final String moment;
  final DateTime date;
  final String activeUserId;
  final Consumption? existingConso;
  final Function(Consumption) onSave;
  final bool isDarkMode;
  final Color accentColor;
  final bool unitMl;
  const _SaisieSheet({
    required this.moment,
    required this.date,
    required this.activeUserId,
    this.existingConso,
    required this.onSave,
    required this.isDarkMode,
    required this.accentColor,
    required this.unitMl,
  });

  static TimeOfDay getDefaultTimeForMoment(String moment) {
    if (moment == L10n.s('moments.morning') || moment == 'Matin') {
      return const TimeOfDay(hour: 8, minute: 0);
    } else if (moment == L10n.s('moments.noon') || moment == 'Midi') {
      return const TimeOfDay(hour: 12, minute: 30);
    } else if (moment == L10n.s('moments.afternoon') || moment == 'Après-midi') {
      return const TimeOfDay(hour: 16, minute: 0);
    } else if (moment == L10n.s('moments.evening') || moment == 'Soir') {
      return const TimeOfDay(hour: 19, minute: 30);
    } else if (moment == L10n.s('moments.night') || moment == 'Soirée') {
      return const TimeOfDay(hour: 23, minute: 0);
    }
    return const TimeOfDay(hour: 19, minute: 30);
  }

  @override
  State<_SaisieSheet> createState() => _SaisieSheetState();
}

class _SaisieSheetState extends State<_SaisieSheet> {
  late String _t;
  late String _v;
  late double _d;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _t = widget.existingConso?.type ?? L10n.s('common.beer');
    _v = widget.existingConso?.volume ?? '33cl';
    _d = widget.existingConso?.degree ?? 6.0;

    if (widget.existingConso != null) {
      _time = TimeOfDay.fromDateTime(widget.existingConso!.date);
    } else {
      _time = TimeOfDay.now();
    }
  }

  String _getMomentFromTime(TimeOfDay time) {
    return getMomentFromTime(time);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode 
                ? const Color(0xFF1A1F26).withValues(alpha: 0.6) 
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            gradient: widget.isDarkMode
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E272E),
                    Color(0xFF000000),
                  ],
                )
              : null,
            border: Border.all(
              color: widget.isDarkMode ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle de fermeture
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 25),
                ),
                
                Text(
                  L10n.s('entry.title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 12,
                    color: widget.accentColor,
                  ),
                ),
                Text(
                  widget.moment.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Sélecteur de type premium
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    L10n.s('common.beer'),
                    L10n.s('common.wine'),
                    L10n.s('common.spirits'),
                    L10n.s('common.soft'),
                  ]
                      .map((type) => _buildTypeCard(type))
                      .toList(),
                ),
                
                const SizedBox(height: 30),
                
                // Sélecteur de volume moderne
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    L10n.s('entry.volume'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['4cl','8cl','12.5cl','15cl','25cl','33cl','50cl','75cl']
                        .map((vol) => _buildVolumeChip(vol))
                        .toList(),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Section Degré
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      L10n.s('entry.alcohol'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${_d.toStringAsFixed(1)} %",
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    activeTrackColor: widget.accentColor,
                    inactiveTrackColor: widget.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 5),
                    overlayColor: widget.accentColor.withValues(alpha: 0.2),
                    showValueIndicator: ShowValueIndicator.onDrag,
                    valueIndicatorColor: widget.accentColor,
                    valueIndicatorTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: Slider(
                    value: _d,
                    min: 0,
                    max: 50,
                    divisions: 100,
                    label: "${_d.toStringAsFixed(1)}%",
                    onChanged: (v) => setState(() => _d = v),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Heure avec style épuré
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    leading: Icon(Icons.access_time_filled, color: widget.accentColor, size: 20),
                    title: Text(L10n.s('entry.time'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w900),
                      ),
                    ),
                    onTap: () async {
                      final p = await showTimePicker(
                        context: context,
                        initialTime: _time,
                        initialEntryMode: TimePickerEntryMode.dial,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: widget.isDarkMode 
                                  ? ColorScheme.dark(primary: widget.accentColor, onPrimary: Colors.white, surface: const Color(0xFF1A1F26), onSurface: Colors.white)
                                  : ColorScheme.light(primary: widget.accentColor, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: widget.accentColor,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                        },
                      );
                      if (p != null) setState(() => _time = p);
                    },
                  ),
                ),
                
                const SizedBox(height: 35),
                
                // Bouton Enregistrer Premium
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final String calculatedMoment = _getMomentFromTime(_time);
                      DateTime finalDate = widget.date;
                      if (calculatedMoment == L10n.s('moments.night') && _time.hour < 6) {
                        finalDate = widget.date.add(const Duration(days: 1));
                      }
                      final fDate = DateTime(
                        finalDate.year,
                        finalDate.month,
                        finalDate.day,
                        _time.hour,
                        _time.minute,
                      );
                      widget.onSave(Consumption(
                        id: widget.existingConso?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        date: fDate,
                        moment: calculatedMoment,
                        type: _t == L10n.s('entry.types.soft') ? L10n.s('entry.types.no_alcohol') : _t,
                        volume: _v,
                        degree: _d,
                        userId: widget.activeUserId,
                      ));
                      Navigator.pop(context);
                    },
                    child: Text(
                      L10n.s('entry.save'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(String type) {
    bool isSel = _t == type || (_t == L10n.s('entry.types.no_alcohol') && type == L10n.s('entry.types.soft'));
    IconData icon;
    if (type == L10n.s('common.beer')) {
      icon = Icons.sports_bar;
    } else if (type == L10n.s('common.wine')) {
      icon = Icons.wine_bar;
    } else if (type == L10n.s('common.soft')) {
      icon = Icons.local_cafe;
    } else {
      icon = Icons.local_drink;
    }

    return GestureDetector(
      onTap: () => setState(() {
        _t = type;
        if (type == L10n.s('common.beer')) {
          _d = 6.0;
          if (widget.existingConso == null) _v = '33cl';
        } else if (type == L10n.s('common.wine')) {
          _d = 13.0;
          if (widget.existingConso == null) _v = '12.5cl';
        } else if (type == L10n.s('common.spirits')) {
          _d = 40.0;
          if (widget.existingConso == null) _v = '4cl';
        } else {
          _d = 0.0;
          if (widget.existingConso == null) _v = '25cl';
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSel 
              ? widget.accentColor.withValues(alpha: 0.25) 
              : (widget.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? widget.accentColor : Colors.white10,
            width: isSel ? 2 : 1,
          ),
          boxShadow: isSel ? [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSel ? widget.accentColor : Colors.blueGrey, size: 28),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                color: isSel 
                    ? (widget.isDarkMode ? Colors.white : Colors.black) 
                    : Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChip(String vol) {
    bool isSel = _v == vol;
    String displayLabel = vol;
    if (widget.unitMl && vol.contains('cl')) {
      double val = double.tryParse(vol.replaceAll('cl', '')) ?? 0;
      displayLabel = "${(val * 10).toInt()}ml";
    }
    return GestureDetector(
      onTap: () => setState(() => _v = vol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? widget.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? widget.accentColor : (widget.isDarkMode ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
            color: isSel ? Colors.white : (widget.isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

