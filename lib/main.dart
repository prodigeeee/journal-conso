import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Ajout pour le support Web
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
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro',
      )
      .then((_) => debugPrint("✅ Supabase initialisé"))
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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
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
    _syncTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _pushToCloud(silent: true),
    );
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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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
          ),
        ];
      } else if (_profiles.isEmpty) {
        _profiles = [
          UserProfile(id: '1', name: 'Moi', gender: 'Homme', age: 35),
        ];
      }

      _activeUserId = data['activeUserId'];
      _contexts = data['contexts'];
      _allConsumptions = data['consumptions'];
    });
    // On lance une synchro Cloud au démarrage pour être certain d'avoir le dernier état (silencieuse)
    await _pullFromCloud(silent: true);
    // On s'assure que les données locales (ex: un profil créé hors ligne) sont bien remontées sur Supabase automatiquement
    await _pushToCloud(silent: true);
  }

  Future<void> _saveAll() async {
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

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (kIsWeb) {
      final bytes = utf8.encode(jsonStr);
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'backup_full_$dateStr.json',
      );
      await Share.shareXFiles([
        xfile,
      ], text: 'Sauvegarde complète Alcohol Tracker');
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/backup_full_$dateStr.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sauvegarde complète Alcohol Tracker');
    }
  }

  Future<void> _deleteProfile(String id) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.s('common.error_last_profile'))),
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
                color: (isError ? Colors.red : widget.accentColor).withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: (isError ? Colors.red : widget.accentColor).withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.cloud_done_rounded,
                    color: isError ? Colors.redAccent : widget.accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Future<void> _pushToCloud({bool silent = true}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!silent) {
        _showAuraSnackBar(
          "Veuillez vous connecter pour sauvegarder",
          isError: true,
        );
      }
      return;
    }
    if (!silent) _showAuraSnackBar("Sauvegarde vers le Cloud...");
    try {
      await SupabaseService.syncProfiles(_profiles, user.id);
      await SupabaseService.syncConsumptions(_allConsumptions, user.id);
      await SupabaseService.syncContexts(_contexts, user.id);
      if (!silent) {
        _showAuraSnackBar(
          L10n.s(
            'sync.success',
            args: {
              'profiles': _profiles.length.toString(),
              'consos': _allConsumptions.length.toString(),
            },
          ),
        );
      }
    } catch (e) {
      if (!silent) {
        _showAuraSnackBar(
          L10n.s('sync.error', args: {'message': e.toString()}),
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteOnlineAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Suppression des données sur le serveur
      // 1. Suppression des données sur le serveur (Cascade SQL)
      await SupabaseService.deleteAllUserData(user.id);

      // 1.b Suppression DEFINITIVE du compte Auth (via la fonction RPC créée dans Supabase)
      await Supabase.instance.client.rpc('delete_user');

      // 2. Déconnexion
      await Supabase.instance.client.auth.signOut();

      // 3. Réinitialisation locale pour un nouveau départ propre
      setState(() {
        _profiles = [
          UserProfile(id: '1', name: 'Moi', gender: 'Homme', age: 35),
        ];
        _allConsumptions.clear();
        _contexts.clear();
        _activeUserId = '1';
      });
      await _saveAll();

      _showAuraSnackBar(
        "Données effacées. Vote compte email reste enregistré mais est maintenant vide.",
      );
    } catch (e) {
      _showAuraSnackBar("Erreur lors de la suppression: $e", isError: true);
    }
  }

  Future<void> _pullFromCloud({bool silent = true}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!silent) {
        _showAuraSnackBar(
          "Veuillez vous connecter pour synchroniser",
          isError: true,
        );
      }
      return;
    }
    if (!silent) _showAuraSnackBar("Récupération de vos données...");
    try {
      final data = await SupabaseService.fetchAllData(user.id);
      final List<UserProfile> cloudProfiles = data['profiles'] != null
          ? List<UserProfile>.from(data['profiles'])
          : [];
      final List<Consumption> cloudConsos = data['consumptions'] != null
          ? List<Consumption>.from(data['consumptions'])
          : [];

      if (cloudProfiles.isNotEmpty ||
          cloudConsos.isNotEmpty ||
          (data['contexts'] != null && (data['contexts'] as Map).isNotEmpty)) {
        setState(() {
          // Si on récupère des profils du cloud, on supprime le profil par défaut local
          if (cloudProfiles.isNotEmpty) {
            _profiles.removeWhere((p) => p.id == '1' || p.id == 'moi_default');
          }

          // Fusion des Profils
          for (var cp in cloudProfiles) {
            final idx = _profiles.indexWhere((p) => p.id == cp.id);
            if (idx != -1) {
              _profiles[idx] = cp;
            } else {
              _profiles.add(cp);
            }
          }

          // Fusion des Consommations
          for (var cc in cloudConsos) {
            final idx = _allConsumptions.indexWhere((c) => c.id == cc.id);
            if (idx != -1) {
              _allConsumptions[idx] = cc;
            } else {
              _allConsumptions.add(cc);
            }
          }

          // Fusion des Contextes
          if (data['contexts'] != null) {
            final Map<String, String> cloudCtx = Map<String, String>.from(
              data['contexts'],
            );
            cloudCtx.forEach((key, value) {
              _contexts[key] = value;
            });
          }

          if (!_profiles.any((p) => p.id == _activeUserId)) {
            _activeUserId = _profiles.isNotEmpty ? _profiles.first.id : '1';
          }
        });
        await StorageService.saveAll(
          profiles: _profiles,
          contexts: _contexts,
          consumptions: _allConsumptions,
          activeUserId: _activeUserId,
        );
        if (!silent) {
          _showAuraSnackBar(
            L10n.s(
              'sync.fetch_success',
              args: {
                'profiles': cloudProfiles.length.toString(),
                'consos': cloudConsos.length.toString(),
              },
            ),
          );
        }
      } else {
        if (!silent) {
          _showAuraSnackBar(
            L10n.s(
              'sync.no_data',
              args: {
                'profiles': cloudProfiles.length.toString(),
                'consos': cloudConsos.length.toString(),
              },
            ),
          );
        }
      }
    } catch (e) {
      if (!silent) {
        _showAuraSnackBar(
          L10n.s('sync.error', args: {'message': e.toString()}),
          isError: true,
        );
      }
    }
  }

  Future<void> _exportProfile(UserProfile p) async {
    final userConsos = _allConsumptions.where((c) => c.userId == p.id).toList();
    final data = {
      'profile': p.toJson(),
      'consumptions': userConsos.map((e) => e.toJson()).toList(),
    };
    final String jsonString = jsonEncode(data);

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (kIsWeb) {
      final bytes = utf8.encode(jsonString);
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'export_${p.name}_$dateStr.json',
      );
      await Share.shareXFiles([xfile], text: 'Export du profil ${p.name}');
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/export_${p.name}_$dateStr.json');
      await file.writeAsString(jsonString);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Export du profil ${p.name}');
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
        final profilesData =
            data['profiles'] ?? data['Profiles'] ?? data['userProfiles'];
        if (profilesData != null) {
          _profiles = (profilesData as List)
              .map((i) => UserProfile.fromJson(i))
              .toList();
        }

        // Recherche souple des consommations
        final consosData =
            data['consumptions'] ??
            data['Consumptions'] ??
            data['history'] ??
            data['consumoires'];
        if (consosData != null) {
          _allConsumptions = (consosData as List)
              .map((i) => Consumption.fromJson(i))
              .toList();
        } else {
          _allConsumptions = [];
        }

        _contexts = Map<String, String>.from(
          data['momentsContexts'] ?? data['contexts'] ?? {},
        );

        if (_profiles.isNotEmpty) {
          _activeUserId = _profiles.first.id;
        }
      });

      await _saveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.s(
                'sync.restoration_success',
                args: {
                  'profiles': _profiles.length.toString(),
                  'consos': _allConsumptions.length.toString(),
                },
              ),
            ),
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
        dynamic profilesData =
            data['profiles'] ??
            data['profile'] ??
            data['Profiles'] ??
            data['userProfiles'] ??
            data['users'];

        if (profilesData == null) {
          try {
            profilesData = data.values.firstWhere(
              (v) => v is List && v.isNotEmpty && v.first['name'] != null,
            );
          } catch (_) {
            profilesData = null;
          }
        }

        if (profilesData == null) throw L10n.s('settings.unknown_format');
        if (profilesData is Map) profilesData = [profilesData];
        if ((profilesData as List).isEmpty) {
          throw L10n.s('settings.no_profile_found');
        }

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
          SnackBar(
            content: Text(L10n.s('settings.import_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.s('settings.import_failed', args: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
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
      int daysInMonth = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
      int firstWeekday = firstOfMonth.weekday - 1;
      
      var monthConsosTotal = userConsos
          .where((c) => DateFormat('yyyy-MM').format(c.date) == monthStr)
          .toList();
          
      int totalB = monthConsosTotal.where((c) => c.type == L10n.s('common.beer')).length;
      int totalV = monthConsosTotal.where((c) => c.type == L10n.s('common.wine')).length;
      int totalS = monthConsosTotal.where((c) => c.type == L10n.s('common.spirits')).length;
      int totalSoft = monthConsosTotal.where((c) => c.type == L10n.s('entry.types.no_alcohol')).length;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Expert Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "RAPPORT DE CONSOMMATION",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          DateFormat('MMMM yyyy', 'fr_FR').format(firstOfMonth).toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          p.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange900,
                          ),
                        ),
                        pw.Text(
                          "ID: ${p.id.substring(0, 8).toUpperCase()}",
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.SizedBox(height: 20),

                // Summary Statistics Box
                pw.Row(
                  children: [
                    _expertStatBox("BIÈRES", totalB, PdfColors.orange800),
                    pw.SizedBox(width: 15),
                    _expertStatBox("VINS", totalV, PdfColors.red800),
                    pw.SizedBox(width: 15),
                    _expertStatBox("SPIRITUEUX", totalS, PdfColors.purple800),
                    pw.SizedBox(width: 15),
                    _expertStatBox("SANS ALCOOL", totalSoft, PdfColors.green800),
                    pw.Spacer(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "TOTAL UNITÉS",
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          "${totalB + totalV + totalS}",
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 25),

                // Calendar Table
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI", "DIMANCHE"
                        ].map((d) => pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.center,
                          child: pw.Text(d, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        )).toList(),
                      ),
                      ...List.generate(6, (weekIndex) {
                        return pw.TableRow(
                          children: List.generate(7, (dayIndex) {
                            int currentDay = (weekIndex * 7) + dayIndex - firstWeekday + 1;
                            if (currentDay <= 0 || currentDay > daysInMonth) {
                              return pw.Container(constraints: const pw.BoxConstraints(minHeight: 50), color: PdfColors.grey50);
                            }

                            DateTime currentCalDay = DateTime(firstOfMonth.year, firstOfMonth.month, currentDay);
                            var dayConsos = userConsos.where((c) => belongsToLogicalDay(c.date, currentCalDay)).toList();
                            dayConsos.sort((a, b) => a.date.compareTo(b.date));

                            return pw.Container(
                              constraints: const pw.BoxConstraints(minHeight: 50),
                              padding: const pw.EdgeInsets.all(4),
                              color: dayConsos.isNotEmpty ? PdfColors.orange50 : null,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "$currentDay",
                                    style: pw.TextStyle(
                                      fontSize: 8, 
                                      fontWeight: pw.FontWeight.bold,
                                      color: dayConsos.isNotEmpty ? PdfColors.orange900 : PdfColors.grey400,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  ...dayConsos.map((c) => pw.Row(
                                    children: [
                                      pw.Container(width: 3, height: 3, decoration: pw.BoxDecoration(color: _getDrinkColor(c.type), shape: pw.BoxShape.circle)),
                                      pw.SizedBox(width: 2),
                                      pw.Text(
                                        "${c.volume} (${DateFormat('HH:mm').format(c.date)})",
                                        style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold),
                                      ),
                                    ],
                                  )),
                                  // Restore Contexts in PDF
                                  ...[
                                    L10n.s('moments.morning'),
                                    L10n.s('moments.noon'),
                                    L10n.s('moments.afternoon'),
                                    L10n.s('moments.evening'),
                                    L10n.s('moments.night'),
                                  ].where((m) {
                                    final key = "${p.id}_${DateFormat('yyyyMMdd').format(currentCalDay)}_$m";
                                    return _contexts.containsKey(key) && _contexts[key]!.isNotEmpty;
                                  }).map((m) {
                                    final key = "${p.id}_${DateFormat('yyyyMMdd').format(currentCalDay)}_$m";
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.only(top: 2),
                                      child: pw.Text(
                                        "${m[0]}: ${_contexts[key]}",
                                        style: pw.TextStyle(fontSize: 4.5, fontStyle: pw.FontStyle.italic, color: PdfColors.blueGrey700),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        );
                      }),
                    ],
                  ),
                ),

                // Footer
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Généré par Alcohol Tracker - Journal Conso", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                    pw.Text("Page ${context.pageNumber} / ${context.pagesCount}", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String pdfName = 'journal_${p.name}_$dateStr.pdf';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text("Rapport Expert"),
            backgroundColor: widget.isDarkMode
                ? const Color(0xFF14191F)
                : Colors.white,
            foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
            elevation: 0,
          ),
          body: PdfPreview(
            build: (format) async => pdf.save(),
            pdfFileName: pdfName,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  // Helper pour la légende PDF

  PdfColor _getDrinkColor(String type) {
    if (type == L10n.s('common.beer')) return PdfColors.orange800;
    if (type == L10n.s('common.wine')) return PdfColors.red800;
    if (type == L10n.s('common.spirits')) return PdfColors.purple800;
    if (type == L10n.s('entry.types.no_alcohol')) return PdfColors.green800;
    return PdfColors.blue800;
  }

  pw.Widget _expertStatBox(String label, int count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            "$count",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
                : Colors.black.withValues(
                    alpha: 0.15,
                  ), // Voile léger pour protéger les yeux en Light Mode
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
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
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
                            _StreakAura(
                              streak: calculateSobrietyStreak(userConsos),
                              child: CircleAvatar(
                                backgroundColor: Color(activeUser.colorValue),
                                radius: 16,
                                backgroundImage: getProfileImage(
                                  activeUser.imagePath,
                                ),
                                child:
                                    (activeUser.imagePath == null ||
                                        activeUser.imagePath!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                              DateFormat(
                                'EEEE d MMMM',
                                'fr_FR',
                              ).format(DateTime.now()),
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
                                            MediaQuery.of(context).size.width -
                                            120,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Color(
                                                p.colorValue,
                                              ),
                                              radius: 12,
                                              backgroundImage: getProfileImage(
                                                p.imagePath,
                                              ),
                                              child:
                                                  (p.imagePath == null ||
                                                      p.imagePath!.isEmpty)
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
                                                fontWeight:
                                                    p.id == _activeUserId
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
                        _PremiumPageWrapper(
                          index: 0,
                          controller: _pageController,
                          child: HomeScreen(
                            consumptions: userConsos,
                            activeUserId: _activeUserId,
                            contexts: _contexts,
                            selectedJournalDate: _currentJournalDate, // New prop
                            isDarkMode: widget.isDarkMode,
                            accentColor: widget.accentColor,
                            activeUser: activeUser,
                            onDateSelected: (date) =>
                                setState(() => _currentJournalDate = date),
                            onAddOrUpdate: (c) async {
                              setState(() {
                                final i = _allConsumptions.indexWhere(
                                  (item) => item.id == c.id,
                                );
                                if (i != -1) {
                                  _allConsumptions[i] = c;
                                } else {
                                  _allConsumptions.add(c);
                                }
                              });
                              await _saveAll();

                              final user =
                                  Supabase.instance.client.auth.currentUser;
                              if (user != null) {
                                try {
                                  await SupabaseService.syncConsumptions([
                                    c,
                                  ], user.id);
                                } catch (e) {
                                  debugPrint("Erreur synchro conso : $e");
                                }
                              }
                            },
                            onDelete: (id) async {
                              setState(
                                () => _allConsumptions.removeWhere(
                                  (c) => c.id == id,
                                ),
                              );
                              final user =
                                  Supabase.instance.client.auth.currentUser;
                              if (user != null) {
                                await SupabaseService.deleteConsumption(
                                  id,
                                  user.id,
                                );
                              }
                              _saveAll();
                            },
                            onUpdateContext: (key, val) async {
                              setState(() {
                                if (val.trim().isEmpty) {
                                  _contexts.remove(key);
                                } else {
                                  _contexts[key] = val;
                                }
                              });
                              await _saveAll();

                              final user =
                                  Supabase.instance.client.auth.currentUser;
                              if (user != null) {
                                try {
                                  if (val.trim().isEmpty) {
                                    await SupabaseService.deleteContext(
                                      key,
                                      user.id,
                                    );
                                  } else {
                                    await SupabaseService.syncSingleContext(
                                      key,
                                      val,
                                      user.id,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint("Erreur synchro contexte : $e");
                                }
                              }
                            },
                            onPrint: (m) =>
                                _printProfile(activeUser, specificMonth: m),
                            unitMl: widget.unitMl,
                          ),
                        ),
                        _PremiumPageWrapper(
                          index: 1,
                          controller: _pageController,
                          child: StatsScreen(
                            consumptions: userConsos,
                            contexts: _contexts,
                            isDarkMode: widget.isDarkMode,
                            accentColor: widget.accentColor,
                            activeUser: activeUser,
                            isYoungDriver: widget.isYoungDriver,
                          ),
                        ),
                        _PremiumPageWrapper(
                          index: 2,
                          controller: _pageController,
                          child: OptionsScreen(
                            key: ValueKey(
                              'opt_${_profiles.length}_$_activeUserId',
                            ),
                            profiles: _profiles,
                            onProfilesChanged: () async {
                              await _saveAll();
                              _pushToCloud(silent: true);
                            },
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
                              final session =
                                  Supabase.instance.client.auth.currentSession;
                              if (session != null) {
                                await Supabase.instance.client.auth.signOut();
                              } else {
                                widget.onOfflineLogout();
                              }
                            },
                          ),
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
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? _PulseWidget(
              enabled: userConsos.every((c) => !belongsToLogicalDay(c.date, DateTime.now())),
              accentColor: widget.accentColor,
              child: LiquidGlassFAB(
                accentColor: widget.accentColor,
                currentBac: calculateBACAt(
                  activeUser.gender,
                  activeUser.weight,
                  userConsos,
                  DateTime.now(),
                ),
                threshold: widget.isYoungDriver ? 0.2 : 0.5,
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
                    contexts: _contexts,
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
                  ),
                );
              },
            ),
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
  final DateTime selectedJournalDate;
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
    required this.selectedJournalDate,
    this.onDateSelected,
    required this.unitMl,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedJournalDate;
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedJournalDate != widget.selectedJournalDate) {
      setState(() {
        _selectedDate = widget.selectedJournalDate;
        _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
      });
    }
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
                            ? Colors.white.withValues(
                                alpha: 0.08,
                              ) // Beaucoup plus transparent
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        // Nécessaire pour les InkWells/Buttons
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.nightlife,
                                  color: widget.accentColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    L10n.s('home.party_goal_title'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
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
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20), // Réduit
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    size: 40,
                                  ),
                                  color: selectedVal > 1
                                      ? widget.accentColor
                                      : Colors.white24,
                                  onPressed: selectedVal > 1
                                      ? () => setStateSB(() => selectedVal--)
                                      : null,
                                ),
                                const SizedBox(width: 20),
                                Text(
                                  "$selectedVal",
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, size: 40),
                                  color: selectedVal < 20
                                      ? widget.accentColor
                                      : Colors.white24,
                                  onPressed: selectedVal < 20
                                      ? () => setStateSB(() => selectedVal++)
                                      : null,
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
                                    style: TextStyle(
                                      color: widget.isDarkMode
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    widget.onUpdateContext(
                                      partyKey,
                                      selectedVal.toString(),
                                    );
                                    Navigator.pop(c);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    L10n.s('home.activate_limit'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
          },
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

    int currentDrinks = widget.consumptions
        .where((c) => DateFormat('yyyyMMdd').format(c.date) == logicalKeyDate)
        .length;

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
                child: Icon(
                  Icons.nightlife,
                  color: widget.accentColor,
                  size: 20,
                ),
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
                        color: widget.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    Text(
                      L10n.s('home.fix_limit'),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDarkMode
                            ? Colors.white54
                            : Colors.black54,
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
                            color: widget.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          L10n.s(
                            'home.drinks_count',
                            args: {
                              'current': currentDrinks.toString(),
                              'goal': currentGoal.toString(),
                            },
                          ),
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
                        backgroundColor: widget.isDarkMode
                            ? Colors.white10
                            : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor,
                        ),
                      ),
                    ),
                    if (progress >= 1.0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          L10n.s('home.objective_reached'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
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
                          onPressed: () => setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month - 1,
                            );
                          }),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: widget.accentColor,
                          ),
                          onPressed: () => setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month + 1,
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_focusedMonth),
                    child: _buildHeatmap(_focusedMonth),
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
          ].asMap().entries.map((entry) => _EntranceFadedSlide(
            key: ValueKey("${_selectedDate.toIso8601String()}_${entry.value}"),
            index: entry.key,
            child: _momentTile(entry.value),
          )),
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

    final List<String> weekDays = [
      L10n.s('pdf.days.mon')[0],
      L10n.s('pdf.days.tue')[0],
      L10n.s('pdf.days.wed')[0],
      L10n.s('pdf.days.thu')[0],
      L10n.s('pdf.days.fri')[0],
      L10n.s('pdf.days.sat')[0],
      L10n.s('pdf.days.sun')[0],
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final dayNum = index - firstDay + 1;
            if (dayNum <= 0 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }
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
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = date);
                      widget.onDateSelected?.call(date);
                      if (!hasC) {
                        _triggerConfetti(context);
                      }
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
        ),
      ],
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

    int totalB = monthConsos
        .where((c) => c.type == L10n.s('common.beer'))
        .length;
    int totalV = monthConsos
        .where((c) => c.type == L10n.s('common.wine'))
        .length;
    int totalS = monthConsos
        .where((c) => c.type == L10n.s('common.spirits'))
        .length;

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
    String? imagePath;
    if (label == L10n.s('common.beer')) {
      imagePath = 'assets/images/beer.png';
    } else if (label == L10n.s('common.wine')) {
      imagePath = 'assets/images/wine.png';
    } else if (label == L10n.s('common.spirits')) {
      imagePath = 'assets/images/whisky.png';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                Image.asset(imagePath, height: 42, fit: BoxFit.contain)
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: widget.isDarkMode ? Colors.white38 : Colors.black45,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return VerticalDivider(
      color: (widget.isDarkMode ? Colors.white : Colors.black).withValues(
        alpha: 0.1,
      ),
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
    final momentConsos =
        widget.consumptions
            .where(
              (c) =>
                  c.userId == widget.activeUserId &&
                  c.moment == moment &&
                  belongsToLogicalDay(c.date, _selectedDate),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
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
                      fontWeight: FontWeight.w900,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
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
                    children: momentConsos.asMap().entries.map((entry) {
                      return _EntranceFadedSlide(
                        index: entry.key,
                        child: _consoDraggable(entry.value),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getUIConstantDrinkColor(String type) {
    if (type == L10n.s('common.beer')) return const Color(0xFFEA9216); // Orange
    if (type == L10n.s('common.wine')) return const Color(0xFFE53935); // Rouge
    if (type == L10n.s('common.spirits')) {
      return const Color(0xFF9C27B0); // Violet
    }
    if (type == L10n.s('entry.types.no_alcohol')) {
      return const Color(0xFF43A047); // Vert
    }
    return widget.accentColor;
  }

  Widget _consoDraggable(Consumption c) {
    final Color drinkColor = _getUIConstantDrinkColor(c.type);
    String? imagePath;
    if (c.type == L10n.s('common.beer')) {
      imagePath = 'assets/images/beer.png';
    } else if (c.type == L10n.s('common.wine')) {
      imagePath = 'assets/images/wine.png';
    } else if (c.type == L10n.s('common.spirits')) {
      imagePath = 'assets/images/whisky.png';
    } else if (c.type == L10n.s('entry.types.no_alcohol') || c.type == 'Soft') {
      imagePath = 'assets/images/water.png';
    }

    return LongPressDraggable<Consumption>(
      data: c,
      feedback: Opacity(
        opacity: 0.8,
        child: _consoCard(c, drinkColor, imagePath, isDragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _consoCard(c, drinkColor, imagePath),
      ),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onDelete(c.id);
        },
        onTap: () {
           HapticFeedback.selectionClick();
           _showSaisie(c.moment, existingConso: c);
        },
        child: _consoCard(c, drinkColor, imagePath),
      ),
    );
  }

  Widget _consoCard(Consumption c, Color drinkColor, String? imagePath, {bool isDragging = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // La Bulle Principale (Style Pill / Capture 2)
        Container(
          width: 170,
          margin: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: drinkColor.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 8, 12, 8),
                decoration: BoxDecoration(
                  color: widget.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: drinkColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Bouton de duplication (Style Capture 2 mais blanc)
                    InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        final duplicated = Consumption(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: c.userId,
                          date: c.date.add(const Duration(seconds: 1)),
                          moment: c.moment,
                          type: c.type,
                          volume: c.volume,
                          degree: c.degree,
                        );
                        widget.onAddOrUpdate(duplicated);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${c.type} ${c.volume}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "(${DateFormat('HH:mm').format(c.date)})",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bouton supprimer (plus discret)
                    InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        widget.onDelete(c.id);
                      },
                      child: const Icon(Icons.close, size: 16, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // L'icône qui dépasse (Style Capture 2)
        Positioned(
          left: -5,
          top: -5,
          bottom: -5,
          child: Center(
            child: imagePath != null
                ? Image.asset(imagePath, height: 48, width: 48, fit: BoxFit.contain)
                : Icon(Icons.local_bar, color: drinkColor, size: 30),
          ),
        ),
      ],
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
          decoration: InputDecoration(hintText: L10n.s('journal.context_hint')),
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
        contexts: widget.contexts,
        onUpdateContext: widget.onUpdateContext,
      ),
    );
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
  String _period = 'Mois';

  double _calculateBACAt(DateTime targetTime) {
    return calculateBACAt(
      widget.activeUser.gender,
      widget.activeUser.weight,
      widget.consumptions,
      targetTime,
    );
  }

  double _calculateCurrentBAC() {
    return _calculateBACAt(DateTime.now());
  }

  Widget _buildBACCurve() {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    double maxBAC = 0.6;

    // On génère 12 heures de courbe (-2h à +10h par rapport à maintenant)
    for (int i = -8; i <= 40; i++) {
      final t = now.add(Duration(minutes: i * 15));
      double val = _calculateBACAt(t);
      if (val > maxBAC) maxBAC = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    double threshold = widget.isYoungDriver ? 0.2 : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ÉVOLUTION PRÉVISIONNELLE (12H)",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
                letterSpacing: 1.2,
              ),
            ),
            Icon(
              Icons.show_chart,
              size: 12,
              color: widget.accentColor.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.2,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: (value == threshold)
                      ? Colors.red.withValues(alpha: 0.3)
                      : (widget.isDarkMode
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05)),
                  strokeWidth: (value == threshold) ? 1.5 : 0.5,
                  dashArray: (value == threshold) ? [5, 5] : null,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 0.2,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => Text(
                      v.toStringAsFixed(1),
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : Colors.black26,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 8, // Toutes les 2 heures (8 * 15 min)
                    getTitlesWidget: (v, m) {
                      DateTime t = now.add(Duration(minutes: v.toInt() * 15));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('HH:mm').format(t),
                          style: TextStyle(
                            color: v.toInt() == 0
                                ? widget.accentColor
                                : (widget.isDarkMode
                                      ? Colors.white30
                                      : Colors.black26),
                            fontSize: 8,
                            fontWeight: v.toInt() == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: (maxBAC * 1.1).clamp(0.6, 3.0),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: widget.accentColor,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) =>
                        spot.x == 0, // Point sur "Maintenant"
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: widget.accentColor,
                        ),
                  ),
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
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => widget.isDarkMode
                      ? const Color(0xFF2C3440)
                      : Colors.white,
                  getTooltipItems: (items) => items
                      .map(
                        (i) => LineTooltipItem(
                          "${i.y.toStringAsFixed(2)} g/L",
                          TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
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
        ? L10n.s(
            'stats.countdown_format',
            args: {
              'h': ((currentBac - threshold) / 0.15).floor().toString(),
              'm':
                  (((currentBac - threshold) / 0.15 -
                              ((currentBac - threshold) / 0.15).floor()) *
                          60)
                      .round()
                      .toString(),
            },
          )
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

    widget.contexts.keys
        .where(
          (k) =>
              k.startsWith("${widget.activeUser.id}_") &&
              k.endsWith("_partyGoal"),
        )
        .forEach((k) {
          var parts = k.split('_');
          if (parts.length >= 3) {
            String dateStr = parts[1];
            if (dateStr.length == 8) {
              int year = int.tryParse(dateStr.substring(0, 4)) ?? 0;
              int month = int.tryParse(dateStr.substring(4, 6)) ?? 0;
              int day = int.tryParse(dateStr.substring(6, 8)) ?? 0;
              if (year > 0) {
                DateTime d = DateTime(year, month, day);
                if (!d.isBefore(startDate)) {
                  countTotalGoals++;
                  int goal = int.tryParse(widget.contexts[k]!) ?? 0;
                  int drinksCount = widget.consumptions.where((c) {
                    return c.date.year == d.year &&
                        c.date.month == d.month &&
                        c.date.day == d.day;
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
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: (currentBac / 1.5).clamp(0, 1)),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, child) => _LiquidCircularProgress(
                          value: value,
                          color: isDanger ? Colors.red : widget.accentColor,
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    _AnimatedCounter(
                      value: currentBac,
                      decimals: 2,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isDanger
                      ? L10n.s(
                          'stats.danger_threshold',
                          args: {'threshold': threshold.toStringAsFixed(1)},
                        )
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
                : (currentBac > 0
                      ? Colors.orange.withValues(alpha: 0.3)
                      : widget.accentColor.withValues(alpha: 0.3)),
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
                    L10n.s(
                      'stats.title_period',
                      args: {
                        'period': _period == 'Semaine'
                            ? L10n.s('stats.periods.week')
                            : (_period == 'Mois'
                                  ? L10n.s('stats.periods.month')
                                  : L10n.s('stats.periods.year')),
                      },
                    ),
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
                    L10n.s(
                      'stats.date_range',
                      args: {
                        'start': DateFormat('dd MMM').format(startDate),
                        'end': DateFormat('dd MMM').format(now),
                      },
                    ),
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
                  children:
                      [
                        L10n.s('stats.periods.week'),
                        L10n.s('stats.periods.month'),
                        L10n.s('stats.periods.year'),
                      ].map((localizedP) {
                        // Logic mapping back to original keys if necessary, or just use indices
                        String p;
                        if (localizedP == L10n.s('stats.periods.week')) {
                          p = 'Semaine';
                        } else if (localizedP ==
                            L10n.s('stats.periods.month')) {
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
                      _AnimatedCounter(
                        value: dryDays,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        L10n.s(
                          'stats.days_count',
                          args: {'count': daysToLookBack.toString()},
                        ),
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
                      _AnimatedCounter(
                        value: unities,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
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
                      color: countSuccessGoals == countTotalGoals
                          ? Colors.green.withValues(alpha: 0.2)
                          : widget.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      countSuccessGoals == countTotalGoals
                          ? Icons.emoji_events
                          : Icons.track_changes,
                      color: countSuccessGoals == countTotalGoals
                          ? Colors.green
                          : widget.accentColor,
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
                            color: countSuccessGoals == countTotalGoals
                                ? Colors.green
                                : widget.accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$countSuccessGoals / $countTotalGoals",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          L10n.s('stats.goals_count'),
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isDarkMode
                                ? Colors.white54
                                : Colors.black54,
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
                          color: countSuccessGoals == countTotalGoals
                              ? Colors.green
                              : widget.accentColor,
                          backgroundColor: widget.isDarkMode
                              ? Colors.white10
                              : Colors.black12,
                          strokeWidth: 4,
                        ),
                        Center(
                          child: Text(
                            "${((countSuccessGoals / countTotalGoals) * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
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
                  "${L10n.s('stats.trend')} (VERRES)".toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 230,
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
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors.black87,
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
                    "3. Élimination globale",
                    "Une fois l'absorption commencée, votre organisme élimine l'alcool à un rythme moyen de 0,15 g/L par heure pour l'ensemble de vos consommations (un seul foie !).",
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const Text(
                            "ATTENTION : Il s'agit d'une estimation théorique. La fatigue, l'alimentation et la santé peuvent modifier ces valeurs. Ne remplace jamais un éthylotest.",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
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
                          backgroundColor: widget.accentColor.withValues(
                            alpha: 0.15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          side: BorderSide(
                            color: widget.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "J'ai compris",
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontSize: 16,
                          ),
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
      final dayConsos = widget.consumptions.where(
        (c) => (_period == 'Année')
            ? (c.date.year == d.year && c.date.month == d.month)
            : belongsToLogicalDay(c.date, d),
      );

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
    double sharedMaxY = maxFound < 5 ? 8 : maxFound + 4;

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (sharedMaxY / 4).clamp(1, 10).toDouble(),
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
      final dayConsos = widget.consumptions.where(
        (c) => (_period == 'Année')
            ? (c.date.year == d.year && c.date.month == d.month)
            : belongsToLogicalDay(c.date, d),
      );

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
    double sharedMaxY = maxFound < 5 ? 8 : maxFound + 4;

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
            interval: _period == 'Mois' ? 5 : 1,
            reservedSize: 40,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx < 0 || idx >= count) return const SizedBox.shrink();
              DateTime d = (_period == 'Année')
                  ? DateTime(today.year, today.month - (count - 1 - idx), 1)
                  : today.subtract(Duration(days: (count - 1) - idx));
              
              if (_period == 'Année') {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM', 'fr_FR').format(d).toUpperCase(),
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${d.year}",
                      style: const TextStyle(color: Colors.blueGrey, fontSize: 7),
                    ),
                  ],
                );
              }
              
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
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (spot) => widget.isDarkMode
              ? const Color(0xFF263238)
              : Colors.white,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                "${spot.y.toStringAsFixed(1)} verres",
                TextStyle(
                  color: widget.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
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
                Colors.redAccent.withValues(
                  alpha: widget.isDarkMode ? 0.6 : 0.4,
                ),
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
      if (!mounted) return;
      String? cloudPath;
      if (Supabase.instance.client.auth.currentUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Envoi de la photo sur le Cloud...")),
        );

        final result = await SupabaseService.uploadProfileImage(image);
        if (!mounted) return;
        cloudPath = result['url'];

        if (cloudPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Photo sauvegardée sur le serveur !"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Erreur : ${result['error']}"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "💡 Mode local : la photo ne sera pas visible dans l'admin.",
            ),
          ),
        );
      }

      setState(() {
        p.imagePath = cloudPath ?? image.path;
      });
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
                color:
                    (widget.isDarkMode ? const Color(0xFF14191F) : Colors.white)
                        .withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.2),
                ),
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
                            color: widget.isDarkMode
                                ? Colors.white54
                                : Colors.black54,
                          ),
                        ),
                        Text(
                          L10n.s('legal_content.privacy_intro'),
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
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
                color:
                    (widget.isDarkMode ? const Color(0xFF14191F) : Colors.white)
                        .withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.2),
                ),
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
            const SizedBox(height: 30),
            Center(
              child: Text(
                "v1.2.0+18-CLOUD",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
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
          buildDefaultDragHandles: false,
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
          proxyDecorator: (child, index, animation) =>
              Material(color: Colors.transparent, child: child),
          itemBuilder: (context, index) {
            final p = widget.profiles[index];
            return Padding(
              key: ValueKey(p.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _PremiumTiltCard(
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
                                color: widget.isDarkMode
                                    ? Colors.white24
                                    : Colors.black12,
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
                                child:
                                    (p.imagePath == null ||
                                        p.imagePath!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
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
                  leading: Icon(
                    Icons.person_add_alt_1,
                    color: widget.accentColor,
                    size: 20,
                  ),
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
                  leading: Icon(
                    Icons.file_download_outlined,
                    color: widget.accentColor,
                    size: 20,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      color: widget.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.s('settings.account_connected'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.accentColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            Supabase.instance.client.auth.currentUser?.email ??
                                "Utilisateur",
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onLogout,
                      child: Text(
                        L10n.s('settings.logout'),
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  Icons.cloud_upload_rounded,
                  color: widget.accentColor,
                ),
                title: Text(
                  L10n.s('settings.save_cloud'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text(
                  L10n.s('settings.save_cloud_desc'),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
                onTap: widget.onPushCloud,
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  Icons.cloud_download_rounded,
                  color: widget.accentColor,
                ),
                title: Text(
                  L10n.s('settings.sync_cloud'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text(
                  L10n.s('settings.sync_cloud_desc'),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
                onTap: widget.onSyncCloud,
              ),
              _divider(),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  Icons.cloud_upload_outlined,
                  color: widget.accentColor,
                ),
                title: Text(
                  L10n.s('legal.save_json'),
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                subtitle: Text(
                  "Exporter une sauvegarde locale sur cet appareil",
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
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
                subtitle: Text(
                  "Restaurer depuis un fichier JSON local",
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
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
                  widget.isDarkMode
                      ? L10n.s('settings.theme_dark')
                      : L10n.s('settings.theme_light'),
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
                secondary: Icon(
                  Icons.warning_amber_rounded,
                  color: widget.accentColor,
                  size: 20,
                ),
                title: Text(
                  L10n.s('settings.young_driver'),
                  style: const TextStyle(fontSize: 13),
                ),
                value: widget.isYoungDriver,
                onChanged: widget.onYoungDriverChanged,
              ),
              _divider(),
              SwitchListTile(
                dense: true,
                secondary: Icon(
                  Icons.straighten,
                  color: widget.accentColor,
                  size: 20,
                ),
                title: Text(
                  L10n.s('settings.unit_ml'),
                  style: const TextStyle(fontSize: 13),
                ),
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
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
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
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showDeleteAccountConfirm(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: Text(
            "v1.2.0+18-CLOUD",
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
        content: Text(L10n.s('settings.reset_confirm_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L10n.s('common.cancel').toUpperCase()),
          ),
          TextButton(
            onPressed: () {
              widget.onReset();
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Toutes les données ont été effacées"),
                ),
              );
            },
            child: const Text(
              "TOUT SUPPRIMER",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
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
          "Cette action effacera définitivement votre historique et vos profils du Cloud. Vos identifiants (e-mail/mot de passe) restent techniquement réservés par le serveur, mais l'intégralité de vos données personnelles sera supprimée.",
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
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
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
                  color:
                      (widget.isDarkMode
                              ? const Color(0xFF14191F)
                              : Colors.white)
                          .withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.2),
                  ),
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
                      unselectedLabelColor: widget.isDarkMode
                          ? Colors.white38
                          : Colors.black38,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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
                            _guideStep(
                              Icons.add_circle_outline,
                              L10n.s('guide.step1_title'),
                              L10n.s('guide.step1_desc'),
                            ),
                            _guideStep(
                              Icons.edit_note_rounded,
                              L10n.s('guide.step2_title'),
                              L10n.s('guide.step2_desc'),
                            ),
                            _guideStep(
                              Icons.copy_rounded,
                              "Duplication intelligente",
                              "Gagnez du temps en dupliquant un verre ou même une série complète en un clic.",
                            ),
                            _guideStep(
                              Icons.timelapse,
                              "Journal 24h",
                              "Parcourez votre journée. Les tranches horaires s'adaptent dynamiquement à vos consommations.",
                            ),
                          ]),
                          _buildGuideTab(scrollController, [
                            _guideStep(
                              Icons.analytics_outlined,
                              "Alcoolémie Réaliste",
                              "Votre taux n'est pas instantané. Nous simulons une montée linéaire sur 45 min pour refléter le temps de boisson et d'absorption.",
                            ),
                            _guideStep(
                              Icons.directions_car_filled_outlined,
                              "Prêt à conduire ?",
                              "L'application calcule en temps réel quand votre taux repassera sous le seuil légal (jeune permis ou confirmé).",
                            ),
                            _guideStep(
                              Icons.calendar_month_outlined,
                              "Calendrier & PDF",
                              "Visualisez votre activité mensuelle et exportez des rapports PDF professionnels pour un suivi médical ou personnel.",
                            ),
                            _guideStep(
                              Icons.psychology_outlined,
                              L10n.s('guide.step3_title'),
                              L10n.s('guide.step3_desc'),
                            ),
                          ]),
                          _buildGuideTab(scrollController, [
                            _guideStep(
                              Icons.people_outline,
                              L10n.s('guide.step4_title'),
                              L10n.s('guide.step4_desc'),
                            ),
                            _guideStep(
                              Icons.cloud_done_outlined,
                              L10n.s('guide.step6_title'),
                              L10n.s('guide.step6_desc'),
                            ),
                            _guideStep(
                              Icons.security_outlined,
                              "Vie Privée",
                              "Vos données de santé sont les vôtres. Elles restent anonymisées et chiffrées sur nos serveurs Supabase.",
                            ),
                            _guideStep(
                              Icons.style_outlined,
                              L10n.s('guide.step8_title'),
                              L10n.s('guide.step8_desc'),
                            ),
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
      color: (widget.isDarkMode ? Colors.white : Colors.black).withValues(
        alpha: 0.03,
      ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                ),
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
  final Map<String, String> contexts;
  final Function(String, String) onUpdateContext;

  const _SaisieSheet({
    required this.moment,
    required this.date,
    required this.activeUserId,
    this.existingConso,
    required this.onSave,
    required this.isDarkMode,
    required this.accentColor,
    required this.unitMl,
    required this.contexts,
    required this.onUpdateContext,
  });

  static TimeOfDay getDefaultTimeForMoment(String moment) {
    if (moment == L10n.s('moments.morning') || moment == 'Matin') {
      return const TimeOfDay(hour: 8, minute: 0);
    } else if (moment == L10n.s('moments.noon') || moment == 'Midi') {
      return const TimeOfDay(hour: 12, minute: 30);
    } else if (moment == L10n.s('moments.afternoon') ||
        moment == 'Après-midi') {
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
  late DateTime _selectedDate;
  late TextEditingController _contextCtrl;

  final List<String> _volumes = [
    '4cl',
    '8cl',
    '12.5cl',
    '15cl',
    '25cl',
    '33cl',
    '50cl',
    '75cl',
  ];
  late FixedExtentScrollController _volumeCtrl;
  late FixedExtentScrollController _degreeCtrl;
  bool _spinning = false;
  
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();

  void _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            debugPrint('onStatus: $val');
            if (val == 'done' || val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (val) {
            debugPrint('onError: $val');
            if (mounted) {
              setState(() => _isListening = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Erreur dictée : ${val.errorMsg}")),
              );
            }
          },
        );
        if (available) {
          final locales = await _speech.locales();
          // On cherche fr_FR ou fr-FR, sinon on prend le premier disponible
          String? localeId;
          try {
            localeId = locales.firstWhere(
              (l) => l.localeId.contains('fr'),
            ).localeId;
          } catch (e) {
            localeId = null; // Laisser le système décider
          }

          if (mounted) setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) {
              if (mounted && val.recognizedWords.isNotEmpty) {
                String newText = val.recognizedWords;
                if (_contextCtrl.text != newText) {
                  setState(() {
                    _contextCtrl.text = newText;
                    _contextCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: newText.length),
                    );
                  });
                }
              }
            },
            localeId: localeId,
            listenOptions: stt.SpeechListenOptions(
              cancelOnError: true,
              partialResults: true,
              listenMode: stt.ListenMode.dictation,
            ),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Dictée vocale non disponible sur cet appareil")),
            );
          }
        }
      } catch (e) {
        debugPrint("Speech init error: $e");
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _t = widget.existingConso?.type ?? L10n.s('common.beer');
    _v = widget.existingConso?.volume ?? '33cl';
    _d = widget.existingConso?.degree ?? 6.0;

    int initVol = _volumes.indexOf(_v);
    if (initVol == -1) initVol = 5;
    _volumeCtrl = FixedExtentScrollController(initialItem: initVol);
    _degreeCtrl = FixedExtentScrollController(initialItem: _d.round());

    if (widget.existingConso != null) {
      _time = TimeOfDay.fromDateTime(widget.existingConso!.date);
      _selectedDate = widget.existingConso!.date;
    } else {
      _time = TimeOfDay.now();
      _selectedDate = widget.date;
    }

    String logicalKeyDate = DateFormat('yyyyMMdd').format(_selectedDate);
    String contextKey =
        "${widget.activeUserId}_${logicalKeyDate}_${widget.moment}";
    _contextCtrl = TextEditingController(
      text: widget.contexts[contextKey] ?? '',
    );
  }

  @override
  void dispose() {
    _contextCtrl.dispose();
    _volumeCtrl.dispose();
    _degreeCtrl.dispose();
    super.dispose();
  }

  String _getMomentFromTime(TimeOfDay time) {
    return getMomentFromTime(time);
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = const Color(0xFFFF7B00);
    final bool isDark = widget.isDarkMode;

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0A0C10).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
              boxShadow: [
                if (isDark)
                  BoxShadow(
                    color: effectiveAccent.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 10,
                    offset: const Offset(0, -10),
                  ),
              ],
            ),
            child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: effectiveAccent, size: 16),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Nouvelle consommation',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: effectiveAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: effectiveAccent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wb_sunny_rounded, color: effectiveAccent, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.moment.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: effectiveAccent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161A20).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: effectiveAccent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveAccent.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _contextCtrl,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Ajouter un contexte...",
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        prefixIcon: Icon(Icons.edit, color: effectiveAccent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, 
                                     color: _isListening ? effectiveAccent : (isDark ? Colors.white38 : Colors.black38)),
                          onPressed: _listen,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    "TYPE DE CONSOMMATION",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 60),

                  Row(
                    children: [
                      L10n.s('common.beer'),
                      L10n.s('common.wine'),
                      L10n.s('common.spirits'),
                      L10n.s('common.soft'),
                    ].asMap().entries.map((entry) {
                      int idx = entry.key;
                      String type = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: idx < 3 ? 8 : 0),
                          child: _buildTypeCard(type, effectiveAccent),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildWheelSelector(
                            "VOLUME",
                            _volumeCtrl,
                            _volumes,
                            _v,
                            Icons.water_drop_rounded,
                            (idx) => setState(() => _v = _volumes[idx]),
                            effectiveAccent,
                            isVolume: true,
                          ),
                        ),
                        Container(width: 1, height: 120, color: Colors.white.withValues(alpha: 0.1)),
                        Expanded(
                          child: _buildWheelSelector(
                            "DEGRÉ D'ALCOOL",
                            _degreeCtrl,
                            List.generate(51, (i) => "$i%"),
                            "${_d.toInt()}%",
                            Icons.water_drop,
                            (idx) => setState(() => _d = idx.toDouble()),
                            effectiveAccent,
                            enabled: _t != L10n.s('common.soft') || _spinning,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumDateTimeBlock(
                          "DATE",
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          DateFormat('EEEE', 'fr_FR').format(_selectedDate),
                          Icons.calendar_today_rounded,
                          effectiveAccent,
                          () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) => _buildThemePicker(context, child, effectiveAccent),
                            );
                            if (d != null) setState(() => _selectedDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumDateTimeBlock(
                          "HEURE",
                          "${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}",
                          "",
                          Icons.access_time_rounded,
                          effectiveAccent,
                          () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _time,
                              builder: (context, child) => _buildThemePicker(context, child, effectiveAccent),
                            );
                            if (t != null) setState(() => _time = t);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _handleSave,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            effectiveAccent,
                            const Color(0xFFD96300),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: effectiveAccent.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Text(
                            "ENREGISTRER",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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

  Widget _buildThemePicker(BuildContext context, Widget? child, Color color) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: widget.isDarkMode
            ? ColorScheme.dark(
                primary: color,
                onPrimary: Colors.white,
                surface: const Color(0xFF1A1F26),
              )
            : ColorScheme.light(
                primary: color,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
      ),
      child: child!,
    );
  }

  void _handleSave() {
    final String calculatedMoment = _getMomentFromTime(_time);
    DateTime finalDate = _selectedDate;
    if (calculatedMoment == L10n.s('moments.night') && _time.hour < 6) {
      finalDate = _selectedDate.add(const Duration(days: 1));
    }
    final fDate = DateTime(
      finalDate.year,
      finalDate.month,
      finalDate.day,
      _time.hour,
      _time.minute,
    );
    widget.onSave(
      Consumption(
        id:
            widget.existingConso?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: fDate,
        moment: calculatedMoment,
        type: _t == L10n.s('entry.types.soft')
            ? L10n.s('entry.types.no_alcohol')
            : _t,
        volume: _v,
        degree: _d,
        userId: widget.activeUserId,
      ),
    );

    String logicalKeyDate = DateFormat('yyyyMMdd').format(_selectedDate);
    String contextKey =
        "${widget.activeUserId}_${logicalKeyDate}_$calculatedMoment";
    widget.onUpdateContext(contextKey, _contextCtrl.text);
    Navigator.pop(context);
  }

  Widget _buildTypeCard(String type, Color accent) {
    final bool isDark = widget.isDarkMode;
    bool isSel =
        _t == type ||
        (_t == L10n.s('entry.types.no_alcohol') &&
            type == L10n.s('entry.types.soft'));

    String? imagePath;
    IconData icon;
    if (type == L10n.s('common.beer')) {
      imagePath = 'assets/images/beer.png';
      icon = Icons.sports_bar_rounded;
    } else if (type == L10n.s('common.wine')) {
      imagePath = 'assets/images/wine.png';
      icon = Icons.wine_bar_rounded;
    } else if (type == L10n.s('common.spirits')) {
      imagePath = 'assets/images/whisky.png';
      icon = Icons.local_drink_rounded;
    } else if (type == L10n.s('common.soft')) {
      imagePath = 'assets/images/water.png';
      icon = Icons.local_cafe_rounded;
    } else {
      icon = Icons.help_outline;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
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
        });
        int vIdx = _volumes.indexOf(_v);
        if (vIdx != -1) {
          _volumeCtrl.animateToItem(
            vIdx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }

        if (type == L10n.s('common.soft')) {
          setState(() => _spinning = true);
          _degreeCtrl.jumpToItem(50);
          _degreeCtrl.animateToItem(
            0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.decelerate,
          ).then((_) {
            if (mounted) setState(() => _spinning = false);
          });
        } else {
          _degreeCtrl.animateToItem(
            _d.round(),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.fromLTRB(8, 48, 8, 12),
            decoration: BoxDecoration(
              gradient: isSel
                  ? LinearGradient(
                      colors: [accent.withValues(alpha: 0.6), accent.withValues(alpha: 0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: !isSel ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSel ? accent : Colors.white.withValues(alpha: 0.05),
                width: isSel ? 2 : 1,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 1),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                type,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                  color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black38),
                ),
              ),
            ),
          ),
          Positioned(
            top: isSel ? -55 : 12,
            child: isSel && imagePath != null
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Image.asset(
                          imagePath!,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  )
                : Icon(
                    icon,
                    color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black38),
                    size: 26,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelSelector(
    String label,
    FixedExtentScrollController ctrl,
    List<String> items,
    String current,
    IconData icon,
    Function(int) onSelected,
    Color accent, {
    bool isVolume = false,
    bool enabled = true,
  }) {
    final bool isDark = widget.isDarkMode;
    final Color displayAccent = enabled ? accent : (isDark ? Colors.white24 : Colors.black26);
    
    String valNum = current.replaceAll(RegExp(r'[^0-9.]'), '');
    String valUnit = current.replaceAll(RegExp(r'[0-9.]'), '');
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              valNum,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: displayAccent,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              valUnit,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: displayAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 1, width: double.infinity, decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: accent, blurRadius: 4, spreadRadius: 1)],
                    color: accent.withValues(alpha: 0.8),
                  )),
                  const SizedBox(height: 38),
                  Container(height: 1, width: double.infinity, decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: accent, blurRadius: 4, spreadRadius: 1)],
                    color: accent.withValues(alpha: 0.8),
                  )),
                ],
              ),
              IgnorePointer(
                ignoring: !enabled,
                child: ListWheelScrollView.useDelegate(
                  controller: ctrl,
                  itemExtent: 38,
                  perspective: 0.01,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: onSelected,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: items.length,
                    builder: (context, index) {
                      String display = items[index];
                      String dispNum = display.replaceAll(RegExp(r'[^0-9.]'), '');
                      bool isSel = current == display;
                      return Center(
                        child: Text(
                          dispNum,
                          style: TextStyle(
                            fontSize: isSel ? 22 : 16,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                            color: !enabled 
                                ? (isDark ? Colors.white10 : Colors.black12)
                                : (isSel ? Colors.white : (isDark ? Colors.white38 : Colors.black38)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDateTimeBlock(
    String label,
    String value,
    String subValue,
    IconData icon,
    Color accent,
    VoidCallback onTap,
  ) {
    final bool isDark = widget.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A20).withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: subValue.isNotEmpty 
                ? Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  )
                : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntranceFadedSlide extends StatefulWidget {
  final Widget child;
  final int index;
  const _EntranceFadedSlide({super.key, required this.child, required this.index});

  @override
  State<_EntranceFadedSlide> createState() => _EntranceFadedSlideState();
}

class _EntranceFadedSlideState extends State<_EntranceFadedSlide> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _opacity.value)),
            child: Transform.scale(
              scale: 0.95 + (0.05 * _opacity.value),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle style;
  final int decimals;
  final String suffix;

  const _AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 0,
    this.suffix = "",
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value.toDouble()).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
      );
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        String display = _anim.value.toStringAsFixed(widget.decimals);
        return Text("$display${widget.suffix}", style: widget.style);
      },
    );
  }
}

class _LiquidCircularProgress extends StatefulWidget {
  final double value;
  final Color color;
  final Color backgroundColor;

  const _LiquidCircularProgress({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  State<_LiquidCircularProgress> createState() => _LiquidCircularProgressState();
}

class _LiquidCircularProgressState extends State<_LiquidCircularProgress> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiquidPainter(
        value: widget.value,
        color: widget.color,
        backgroundColor: widget.backgroundColor,
        animationValue: _ctrl.value,
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double animationValue;

  _LiquidPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Clip to circle
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(path);

    // Wave
    final wavePaint = Paint()..color = color.withValues(alpha: 0.8);
    final wavePath = Path();
    
    final yBase = size.height * (1 - value);
    final waveHeight = 6.0;
    
    wavePath.moveTo(0, yBase);
    for (double i = 0; i <= size.width; i++) {
      wavePath.lineTo(i, yBase + waveHeight * math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)));
    }
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    canvas.drawPath(wavePath, wavePaint);
    canvas.restore();
    
    // Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) => true;
}

void _triggerConfetti(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ConfettiWidget(onFinished: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _ConfettiWidget extends StatefulWidget {
  final VoidCallback onFinished;
  const _ConfettiWidget({required this.onFinished});

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    
    // Create particles
    for (int i = 0; i < 100; i++) {
      final isGold = _rng.nextBool();
      _particles.add(_ConfettiParticle(
        x: 0.3 + _rng.nextDouble() * 0.4, // More concentrated center (0.3 to 0.7)
        y: 1.0, // Start right at the bottom edge
        vx: (_rng.nextDouble() - 0.5) * 0.03, // Tighter horizontal spread
        vy: -0.05 - (_rng.nextDouble() * 0.1), // Lower upward shoot
        size: 5 + _rng.nextDouble() * 10, // Slightly bigger
        color: isGold 
            ? [const Color(0xFFFFD700), const Color(0xFFEA9216), const Color(0xFFD4AF37)][_rng.nextInt(3)]
            : const Color(0xFF1A1A1A),
        rotation: _rng.nextDouble() * 2 * math.pi,
        rotationSpeed: 0.05 + (_rng.nextDouble() * 0.1),
      ));
    }

    _ctrl.addListener(() {
      setState(() {
        for (var p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.002; // Very light gravity for a slow, dense rain
          p.rotation += p.rotationSpeed;
        }
      });
    });

    _ctrl.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_particles),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiParticle {
  double x, y, vx, vy, size, rotation, rotationSpeed;
  Color color;
  _ConfettiParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.color, required this.rotation, required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      // Shimmer effect - higher base opacity for better visibility
      final shine = (math.sin(p.rotation * 2).abs() * 0.3) + 0.7;
      final paint = Paint()
        ..color = p.color.withValues(alpha: shine)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      
      // Draw a more "confetti-like" shape (long rectangle)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-p.size / 2, -p.size / 4, p.size, p.size / 2),
          const Radius.circular(1),
        ),
        paint,
      );
      
      // Add a tiny highlight/sparkle for gold particles
      if (p.color != const Color(0xFF1A1A1A) && shine > 0.9) {
        final sparkPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
        canvas.drawCircle(Offset.zero, 1.5, sparkPaint);
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PremiumTiltCard extends StatefulWidget {
  final Widget child;
  const _PremiumTiltCard({required this.child});

  @override
  State<_PremiumTiltCard> createState() => _PremiumTiltCardState();
}

class _PremiumTiltCardState extends State<_PremiumTiltCard> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (details) {
        final box = context.findRenderObject() as RenderBox;
        final pos = box.globalToLocal(details.position);
        final centerX = box.size.width / 2;
        final centerY = box.size.height / 2;
        
        setState(() {
          _tiltY = (pos.dx - centerX) / centerX * 0.25;
          _tiltX = (centerY - pos.dy) / centerY * 0.25;
        });
      },
      onExit: (_) => setState(() { _tiltX = 0; _tiltY = 0; }),
      child: Listener(
        onPointerMove: (details) {
          final box = context.findRenderObject() as RenderBox;
          final pos = box.globalToLocal(details.position);
          final centerX = box.size.width / 2;
          final centerY = box.size.height / 2;
          
          setState(() {
            _tiltY = (pos.dx - centerX) / centerX * 0.25;
            _tiltX = (centerY - pos.dy) / centerY * 0.25;
          });
        },
        onPointerUp: (_) => setState(() { _tiltX = 0; _tiltY = 0; }),
        onPointerCancel: (_) => setState(() { _tiltX = 0; _tiltY = 0; }),
        child: TweenAnimationBuilder<Matrix4>(
          tween: Matrix4Tween(
            begin: Matrix4.identity(),
            end: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // Perspective
              ..rotateX(_tiltX)
              ..rotateY(_tiltY),
          ),
          duration: const Duration(milliseconds: 150),
          builder: (context, matrix, child) {
            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _PremiumPageWrapper extends StatelessWidget {
  final Widget child;
  final int index;
  final PageController controller;

  const _PremiumPageWrapper({
    required this.child,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double value = 1.0;
        if (controller.position.haveDimensions) {
          value = (controller.page! - index).abs();
        } else {
          value = (controller.initialPage - index).abs().toDouble();
        }
        
        final double opacity = (1 - (value * 1.0)).clamp(0.0, 1.0);
        final double scale = (1 - (value * 0.25)).clamp(0.75, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _StreakAura extends StatefulWidget {
  final Widget child;
  final int streak;
  const _StreakAura({required this.child, required this.streak});

  @override
  State<_StreakAura> createState() => _StreakAuraState();
}

class _StreakAuraState extends State<_StreakAura> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak < 3) return widget.child;
    
    final double intensity = (widget.streak / 10).clamp(0.5, 1.5);
    
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3 * _ctrl.value * intensity),
                blurRadius: 10 + (10 * _ctrl.value),
                spreadRadius: 2 + (4 * _ctrl.value),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _PulseWidget extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color accentColor;
  const _PulseWidget({required this.child, required this.enabled, required this.accentColor});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60 + (30 * _anim.value),
              height: 60 + (30 * _anim.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.5 * (1.0 - _anim.value * 0.5)),
                  width: 2.0,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
