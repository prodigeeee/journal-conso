import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Paris'));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const AlcoholTrackerApp());
}

// --- UTILITAIRES ---
String cleanDisplay(String? text) {
  if (text == null) return '';
  return text
      .replaceAll("´e", "é")
      .replaceAll("`e", "è")
      .replaceAll("^e", "ê")
      .replaceAll("Ã©", "é")
      .replaceAll("Ã¨", "è")
      .replaceAll("`a", "à");
}

bool belongsToLogicalDay(DateTime consumptionDate, DateTime dayInCalendar) {
  DateTime logical = consumptionDate.hour < 6
      ? consumptionDate.subtract(const Duration(days: 1))
      : consumptionDate;
  return logical.year == dayInCalendar.year &&
      logical.month == dayInCalendar.month &&
      logical.day == dayInCalendar.day;
}

// --- MODÈLES ---
class UserProfile {
  String id;
  String name;
  String gender;
  int age;
  int weight;
  int colorValue;
  String? imagePath;
  UserProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    this.weight = 70,
    this.colorValue = 0xFFEA9216,
    this.imagePath,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'age': age,
    'weight': weight,
    'colorValue': colorValue,
    'imagePath': imagePath,
  };
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'] ?? '',
    gender: json['gender'] ?? 'Homme',
    age: (json['age'] as num).toInt(),
    weight: (json['weight'] as num?)?.toInt() ?? 70,
    colorValue: json['colorValue'] ?? 0xFFEA9216,
    imagePath: json['imagePath'],
  );
}

class Consumption {
  String id;
  DateTime date;
  String moment;
  String type;
  String volume;
  double degree;
  String userId;
  Consumption({
    required this.id,
    required this.date,
    required this.moment,
    required this.type,
    required this.volume,
    required this.degree,
    required this.userId,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'moment': moment,
    'type': type,
    'volume': volume,
    'degree': degree,
    'userId': userId,
  };
  factory Consumption.fromJson(Map<String, dynamic> json) => Consumption(
    id: json['id'],
    date: DateTime.parse(json['date']),
    moment: json['moment'] ?? 'Soir',
    type: json['type'],
    volume: json['volume'],
    degree: (json['degree'] as num).toDouble(),
    userId: json['userId'] ?? '1',
  );
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
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('isDarkMode') ?? true);
  }

  void _updateTheme(bool dark) {
    setState(() => _isDarkMode = dark);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('isDarkMode', dark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isDarkMode
        ? const Color(0xFFEA9216)
        : const Color(0xFF1A3A5F);
    return MaterialApp(
      title: 'Journal Conso',
      debugShowCheckedModeBanner: false,
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
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('isDarkMode') ?? true);
  }

  void _updateTheme(bool dark) {
    setState(() => _isDarkMode = dark);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('isDarkMode', dark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isDarkMode
        ? const Color(0xFFEA9216)
        : const Color(0xFF1A3A5F);
    return MainNavigationScreen(
      isDarkMode: _isDarkMode,
      onThemeChanged: _updateTheme,
      accentColor: accentColor,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Color accentColor;
  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.accentColor,
  });
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  List<Consumption> _allConsumptions = [];
  List<UserProfile> _profiles = [];
  Map<String, String> _contexts = {};
  String _activeUserId = '';

  @override
  void initState() {
    super.initState();
    _initApp();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profiles = (jsonDecode(prefs.getString('profiles') ?? '[]') as List)
          .map((i) => UserProfile.fromJson(i))
          .toList();
      if (_profiles.isEmpty) {
        _profiles = [
          UserProfile(id: '1', name: 'Chris', gender: 'Homme', age: 35),
        ];
      }
      _activeUserId = prefs.getString('active_user_id') ?? _profiles.first.id;
      _contexts = Map<String, String>.from(
        jsonDecode(prefs.getString('momentsContexts') ?? '{}'),
      );
      _allConsumptions =
          (jsonDecode(prefs.getString('consumptions') ?? '[]') as List)
              .map((i) => Consumption.fromJson(i))
              .toList();
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'profiles',
      jsonEncode(_profiles.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('momentsContexts', jsonEncode(_contexts));
    await prefs.setString(
      'consumptions',
      jsonEncode(_allConsumptions.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('active_user_id', _activeUserId);
    setState(() {});
  }

  void _deleteProfile(String id) {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de supprimer le dernier profil."),
        ),
      );
      return;
    }
    setState(() {
      _profiles.removeWhere((p) => p.id == id);
      _allConsumptions.removeWhere((c) => c.userId == id);
      _contexts.removeWhere((key, value) => key.startsWith("${id}_"));
      if (_activeUserId == id) _activeUserId = _profiles.first.id;
    });
    _saveAll();
  }

  Future<void> _exportProfile(UserProfile p) async {
    final userConsos = _allConsumptions.where((c) => c.userId == p.id).toList();
    final data = {
      'profile': p.toJson(),
      'consumptions': userConsos.map((e) => e.toJson()).toList(),
    };
    final String jsonString = jsonEncode(data);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/export_${p.name}.json');
    await file.writeAsString(jsonString);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Export du profil ${p.name}');
  }

  Future<void> _importToProfile(UserProfile p) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      final data = jsonDecode(content);
      setState(() {
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
          SnackBar(content: Text("Données importées pour ${p.name}")),
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
          // 1. Force le format paysage dans la définition de la page
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
                          "Journal : ${p.name}",
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
                      "Bière: $totalB | Vin: $totalV | Spiritueux: $totalS",
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
                          ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
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
                            'Matin',
                            'Midi',
                            'Après-midi',
                            'Soir',
                            'Soirée',
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
                                      color: c.type == 'Bière'
                                          ? PdfColors.orange800
                                          : c.type == 'Vin'
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

    // 2. Force le format paysage lors de l'ouverture de l'aperçu système
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Journal_${p.name}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // 1. L'image de fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: widget.isDarkMode
                    ? Colors.black
                    : const Color(0xFFF7F3F0),
              ),
            ),
          ),
          // 2. Le voile par-dessus le fond
          Container(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.75)
                : Colors.white.withOpacity(0.5),
          ),

          // 3. Le contenu principal (Titre, Profil, Onglets)
          Column(
            children: [
              Image.asset(
                'assets/images/title.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: _glassModule(
                    isDarkMode: widget.isDarkMode,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(activeUser.colorValue),
                          radius: 16,
                          backgroundImage: activeUser.imagePath != null
                              ? FileImage(File(activeUser.imagePath!))
                              : null,
                          child: activeUser.imagePath == null
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
                                      : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                activeUser.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                          backgroundImage: p.imagePath != null
                                              ? FileImage(File(p.imagePath!))
                                              : null,
                                          child: p.imagePath == null
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
                      onDelete: (id) {
                        setState(
                          () => _allConsumptions.removeWhere((c) => c.id == id),
                        );
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
                    ),
                    StatsScreen(
                      consumptions: userConsos,
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      activeUser: activeUser,
                    ),
                    // --- LE BLOC OPTIONS CORRIGÉ ---
                    OptionsScreen(
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
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 4. LE DÉGRADÉ (placé APRÈS le reste pour être dessiné au-dessus)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              // Empêche le dégradé de bloquer les clics
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.9), // Noir en haut
                      Colors.transparent, // Transparent en bas
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: widget.isDarkMode
            ? Colors.black.withOpacity(0.9)
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Journal',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Stats'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Réglages',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _glassModule(
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

        final bezelColor = Colors.white.withOpacity(0.8);
        final baseColor = widget.accentColor;
        final shadeColor = widget.isDarkMode
            ? const Color(0xFF6D3F00)
            : const Color(0xFF0A1E35);

        return GestureDetector(
          onTap: isFuture ? null : () => setState(() => _selectedDate = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.6),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
              border: isSel
                  ? Border.all(color: widget.accentColor, width: 0.8)
                  : Border.all(color: Colors.transparent),
              gradient: isSel
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [baseColor.withOpacity(0.95), shadeColor],
                      stops: const [0.0, 1.0],
                    )
                  : null,
              color: !isSel
                  ? (hasC
                        ? widget.accentColor.withOpacity(0.4)
                        : (widget.isDarkMode
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05)))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  if (isSel)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(height: 1.5, color: bezelColor),
                    ),
                  if (isSel)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.1),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 0.46, 1.0],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: isSel ? 14 : 10,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isFuture
                            ? (widget.isDarkMode
                                  ? Colors.white10
                                  : Colors.black12)
                            : (isSel
                                  ? Colors.white
                                  : (widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black87)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- VERSION "ÉPURÉE EN LIGNE" DU RÉSUMÉ ---
  Widget _buildMonthlySummary() {
    // 1. Calcul (on garde la même logique)
    var monthConsos = widget.consumptions
        .where(
          (c) =>
              c.date.year == _focusedMonth.year &&
              c.date.month == _focusedMonth.month,
        )
        .toList();
    if (monthConsos.isEmpty) return const SizedBox.shrink();

    // 2. Comptage
    int totalB = monthConsos.where((c) => c.type == 'Bière').length;
    int totalV = monthConsos.where((c) => c.type == 'Vin').length;
    int totalS = monthConsos.where((c) => c.type == 'Spiritueux').length;

    // 3. Le design horizontal épuré
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5),
      child: Center(
        child: IntrinsicHeight(
          // Permet aux séparateurs de prendre toute la hauteur
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _summaryBadge('Bière', totalB, Colors.orange),
              _verticalDivider(), // Petit séparateur
              _summaryBadge('Vin', totalV, Colors.redAccent),
              _verticalDivider(), // Petit séparateur
              _summaryBadge('Spiritueux', totalS, Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  // Fonction d'aide pour le badge en ligne
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
            label.toUpperCase(), // Optionnel : en majuscules pour le style
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

  // Petit séparateur vertical discret
  Widget _verticalDivider() {
    return VerticalDivider(
      color: (widget.isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
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
      onWillAcceptWithDetails: (data) => data.moment != moment,
      onAcceptWithDetails: (data) {
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
          child: _glassModule(
            isDarkMode: widget.isDarkMode,
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
                  trailing: Icon(
                    Icons.add_circle_outline,
                    color: widget.accentColor,
                    size: 24,
                  ),
                  onTap: () => _showSaisie(moment),
                ),
                GestureDetector(
                  onTap: () => _showContextDialog(moment, momentContext ?? ''),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      (momentContext != null && momentContext.trim().isNotEmpty)
                          ? cleanDisplay(momentContext)
                          : 'Ajouter un contexte...',
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
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => widget.onAddOrUpdate(
              Consumption(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: c.date,
                moment: c.moment,
                type: c.type,
                volume: c.volume,
                degree: c.degree,
                userId: c.userId,
              ),
            ),
            child: Icon(Icons.add_circle, size: 14, color: widget.accentColor),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSaisie(c.moment, existingConso: c),
            child: Text(
              '${c.type} ${c.volume} (${DateFormat('HH:mm').format(c.date)})',
              style: TextStyle(
                fontSize: 10,
                color: widget.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.onDelete(c.id),
            child: const Icon(
              Icons.delete_outline,
              size: 14,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
    return LongPressDraggable<Consumption>(
      data: c,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.8, child: chip),
      ),
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
        title: const Text("Contexte"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: const InputDecoration(
            hintText: "Saisissez votre texte ici...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Annuler"),
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
            child: const Text(
              "Valider",
              style: TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  final List<Consumption> consumptions;
  final bool isDarkMode;
  final Color accentColor;
  final UserProfile activeUser;
  const StatsScreen({
    super.key,
    required this.consumptions,
    required this.isDarkMode,
    required this.accentColor,
    required this.activeUser,
  });
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _period = 'Semaine';

  double _calculateCurrentBAC() {
    double r = widget.activeUser.gender == 'Homme' ? 0.7 : 0.6;
    final now = DateTime.now();
    double total = 0.0;
    final recentConsos = widget.consumptions
        .where(
          (c) => now.difference(c.date).inHours < 12 && c.date.isBefore(now),
        )
        .toList();
    for (var c in recentConsos) {
      double vol = double.tryParse(c.volume.replaceAll('cl', '')) ?? 0;
      double grammes = (vol * 10 * c.degree * 0.8) / 100;
      double hoursSinceDrink = now.difference(c.date).inMinutes / 60.0;
      double eliminationHours = (hoursSinceDrink - 0.75).clamp(
        0.0,
        double.infinity,
      );
      double bac =
          (grammes / (widget.activeUser.weight * r)) -
          (0.15 * eliminationHours);
      if (bac > 0) total += bac;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    double currentBac = _calculateCurrentBAC();
    bool isDanger = currentBac >= 0.5;
    String countdownText = currentBac > 0.5
        ? "${((currentBac - 0.5) / 0.15).floor()}h ${(((currentBac - 0.5) / 0.15 - ((currentBac - 0.5) / 0.15).floor()) * 60).round()}min"
        : "Prêt à conduire";
    final now = DateTime.now();
    final countedDrinks = widget.consumptions
        .where(
          (c) => now.difference(c.date).inHours < 12 && c.date.isBefore(now),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              children: [
                const Text(
                  "ALCOOLÉMIE ESTIMÉE (WIDMARK + PIC)",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                        backgroundColor: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                    Text(
                      currentBac.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isDanger ? "⚠️ SEUIL DÉPASSÉ (0.50g/L)" : "SÉCURITÉ OK",
                  style: TextStyle(
                    color: isDanger ? Colors.red : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (countedDrinks.isNotEmpty) ...[
                  const Divider(height: 30),
                  const Text(
                    "Verres comptés (12h glissantes) :",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  ...countedDrinks.map(
                    (c) => Text(
                      "• ${c.type} (${DateFormat('HH:mm').format(c.date)})",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 15),
          _glassModule(
            isDarkMode: widget.isDarkMode,
            borderColor: isDanger
                ? Colors.red.withOpacity(0.3)
                : widget.accentColor.withOpacity(0.3),
            child: Column(
              children: [
                Text(
                  "RETOUR AU SEUIL LÉGAL DANS",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Text(
              "Estimation théorique uniquement. Ne remplace pas un éthylotest.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TENDANCE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _period,
                      underline: const SizedBox(),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (n) => setState(() => _period = n!),
                      items: ['Semaine', 'Mois', 'Année']
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
          _glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "RÉPARTITION GLOBALE PAR TYPE",
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

  // --- AXE FIXE À GAUCHE (CORRIGÉ POUR ÉVITER L'OVERFLOW) ---
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
      double val = widget.consumptions
          .where(
            (c) => (_period == 'Année')
                ? (c.date.year == d.year && c.date.month == d.month)
                : (c.date.year == d.year &&
                      d.month == c.date.month &&
                      c.date.day == d.day),
          )
          .length
          .toDouble();
      if (val > maxFound) maxFound = val;
    }
    double sharedMaxY = maxFound < 5 ? 6 : maxFound + 2;

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            reservedSize: 40, // Augmenté pour laisser passer les chiffres
            getTitlesWidget: (v, m) => Text(
              '${v.toInt()}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 8),
            ),
          ),
        ),
        // Espace fantôme en bas pour caler le 0
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

  // --- GRAPHIQUE DÉFILANT (CORRIGÉ POUR L'ALIGNEMENT) ---
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
      double val = widget.consumptions
          .where(
            (c) => (_period == 'Année')
                ? (c.date.year == d.year && c.date.month == d.month)
                : (c.date.year == d.year &&
                      d.month == c.date.month &&
                      c.date.day == d.day),
          )
          .length
          .toDouble();
      if (val > maxFound) maxFound = val;
      spots.add(FlSpot(i.toDouble(), val));
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
          barWidth: 2.0,
          gradient: LinearGradient(
            colors: [widget.accentColor, Colors.orange, Colors.redAccent],
          ),
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.accentColor.withOpacity(0.3), Colors.transparent],
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
              // --- AJOUT DES DÉGRADÉS GLOSSY ---
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
                      // --- DÉGRADÉ DANS LA LÉGENDE ---
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
  });
  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final ImagePicker _picker = ImagePicker();
  Future<void> _pickImage(UserProfile p) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => p.imagePath = image.path);
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
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              Text(
                "POLITIQUE DE CONFIDENTIALITÉ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      "Dernière mise à jour : 21 Mars 2026\n",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: widget.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                    _infoSection(
                      "1. Présentation",
                      "Journal Conso est une application mobile permettant à l’utilisateur de tenir un journal personnel de consommation d’alcool, de consulter des statistiques indicatives et de gérer ses données localement sur son appareil.",
                    ),
                    _infoSection(
                      "2. Données enregistrées",
                      "L’application peut enregistrer localement :\n• les données de journal de consommation saisies par l’utilisateur ;\n• les informations liées aux profils créés dans l’application ;\n• les préférences d’affichage, notamment le thème ;\n• les données nécessaires aux statistiques et visualisations ;\n• les fichiers exportés volontairement par l’utilisateur.",
                    ),
                    _infoSection(
                      "3. Stockage local uniquement",
                      "Toutes les données de Journal Conso sont stockées uniquement sur l’appareil de l’utilisateur.\nL’application n’envoie aucune donnée à son auteur, à un serveur distant ou à des tiers.",
                    ),
                    _infoSection(
                      "4. Absence de compte et de suivi",
                      "L’application fonctionne sans compte utilisateur, sans synchronisation cloud, sans publicité, sans outil d’analyse d’usage et sans traqueur externe.",
                    ),
                    _infoSection(
                      "5. Finalité",
                      "Les données sont utilisées uniquement pour permettre à l’utilisateur de consigner sa consommation, consulter son calendrier, utiliser plusieurs profils et gérer ses données.",
                    ),
                    _infoSection(
                      "6. Partage des données",
                      "Aucune donnée personnelle n’est partagée automatiquement par l’application.",
                    ),
                    _infoSection(
                      "7. Export et import",
                      "L’utilisateur peut exporter ses données au format JSON. Il reste responsable de leur stockage et de leur protection.",
                    ),
                    _infoSection(
                      "8. Suppression des données",
                      "L’utilisateur peut supprimer tout ou partie de ses données depuis l’application.",
                    ),
                    _infoSection(
                      "9. Sécurité",
                      "Les données étant conservées localement, leur sécurité dépend de la protection de l'appareil utilisé. Activez un code de verrouillage.",
                    ),
                    _infoSection(
                      "10. Limites de l’application",
                      "Journal Conso n'est pas un dispositif médical. Les estimations d'alcoolémie sont indicatives. L'application ne doit jamais déterminer une aptitude à conduire.",
                    ),
                    _infoSection(
                      "11. Contact",
                      "Auteur : ChrisK\nAdresse : journalconso@gmail.com",
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
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
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              Text(
                "INFORMATIONS LÉGALES",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      "Journal Conso est une application de suivi personnel permettant d’enregistrer localement sa consommation d’alcool et d’afficher des statistiques indicatives.\n",
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    _infoSection(
                      "Confidentialité",
                      "Vos données sont stockées uniquement sur votre appareil. L’application ne transmet aucune donnée à l’auteur ni à des tiers.",
                    ),
                    _infoSection(
                      "Avertissement",
                      "Journal Conso n’est pas un dispositif médical. Les estimations affichées sont indicatives et ne remplacent ni un éthylotest, ni un avis médical, ni les règles légales applicables.",
                    ),
                    _infoSection("Auteur", "ChrisK"),
                    _infoSection("Contact", "journalconso@gmail.com"),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
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
                color: widget.accentColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),
            Text(
              "SOUTENIR JOURNAL CONSO",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Si vous souhaitez soutenir le développement de l’application, vous pouvez effectuer un don via PayPal à l’adresse suivante :",
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
                    "https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=christophek@hotmail.com&currency_code=EUR",
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Impossible d'ouvrir PayPal"),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  "FAIRE UN DON VIA PAYPAL",
                  style: TextStyle(
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
              "Les dons sont facultatifs et servent à soutenir le développement de l’application.",
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
                      Colors.black.withOpacity(0.3),
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
                        color: widget.accentColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                    ),
                    Text(
                      "CRÉDITS",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 160),
                    _glassModule(
                      isDarkMode: true,
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
                            "Application créée par ChrisK",
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Pour toute question, suggestion ou retour :",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
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
                    _glassModule(
                      isDarkMode: true,
                      child: ListTile(
                        dense: true,
                        title: Center(
                          child: Text(
                            "Fermer",
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
        Text(
          "PROFILS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.profiles.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _glassModule(
              isDarkMode: widget.isDarkMode,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(p.colorValue),
                          radius: 24,
                          backgroundImage: p.imagePath != null
                              ? FileImage(File(p.imagePath!))
                              : null,
                          child: p.imagePath == null
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
                        "Export",
                        () => widget.onExportProfile(p),
                      ),
                      _miniAction(
                        Icons.download,
                        "Import",
                        () => widget.onImportProfile(p),
                      ),
                      _miniAction(
                        Icons.print,
                        "Imprimer",
                        () => widget.onPrintProfile(p),
                      ),
                      _miniAction(
                        Icons.delete_outline,
                        "Supprimer",
                        () => _confirmDelete(p),
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _glassModule(
          isDarkMode: widget.isDarkMode,
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.person_add_alt_1,
              color: widget.accentColor,
              size: 20,
            ),
            title: Text(
              "Ajouter un profil",
              style: TextStyle(color: widget.accentColor, fontSize: 13),
            ),
            onTap: () => _editProfile(null),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          "PRÉFÉRENCES GLOBALES",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        _glassModule(
          isDarkMode: widget.isDarkMode,
          child: Column(
            children: [
              SwitchListTile(
                dense: true,
                title: Text(
                  widget.isDarkMode ? "Mode Sombre" : "Mode Clair",
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
              Divider(
                height: 1,
                color: widget.isDarkMode ? Colors.white10 : Colors.black12,
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                  size: 20,
                ),
                title: Text(
                  "Réinitialisation totale",
                  style: TextStyle(color: itemTxt, fontSize: 13),
                ),
                onTap: widget.onReset,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          "À PROPOS & LÉGAL",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(height: 10),
        _glassModule(
          isDarkMode: widget.isDarkMode,
          child: Column(
            children: [
              _legalTile(
                Icons.privacy_tip_outlined,
                "Politique de confidentialité",
                _showPrivacyPolicy,
              ),
              _divider(),
              _legalTile(
                Icons.gavel_outlined,
                "Informations légales",
                _showLegalInfo,
              ),
              _divider(),
              _legalTile(
                Icons.favorite_outline,
                "Faire un don",
                _showDonationDialog,
              ),
              _divider(),
              _legalTile(Icons.info_outline, "Crédits", _showCreditsDialog),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

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
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteProfile(p.id);
              Navigator.pop(c);
            },
            child: const Text(
              "Supprimer",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CLASSE SAISIE UNIQUE ---
class _SaisieSheet extends StatefulWidget {
  final String moment;
  final DateTime date;
  final String activeUserId;
  final Consumption? existingConso;
  final Function(Consumption) onSave;
  final bool isDarkMode;
  final Color accentColor;
  const _SaisieSheet({
    required this.moment,
    required this.date,
    required this.activeUserId,
    this.existingConso,
    required this.onSave,
    required this.isDarkMode,
    required this.accentColor,
  });

  static TimeOfDay getDefaultTimeForMoment(String moment) {
    switch (moment) {
      case 'Matin':
        return const TimeOfDay(hour: 8, minute: 0);
      case 'Midi':
        return const TimeOfDay(hour: 12, minute: 30);
      case 'Après-midi':
        return const TimeOfDay(hour: 16, minute: 0);
      case 'Soir':
        return const TimeOfDay(hour: 19, minute: 30);
      case 'Soirée':
        return const TimeOfDay(hour: 23, minute: 0);
      default:
        return const TimeOfDay(hour: 19, minute: 30);
    }
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
    _t = widget.existingConso?.type ?? 'Bière';
    _v = widget.existingConso?.volume ?? '33cl';
    _d = widget.existingConso?.degree ?? 6.0;

    if (widget.existingConso != null) {
      _time = TimeOfDay.fromDateTime(widget.existingConso!.date);
    } else {
      final now = TimeOfDay.now();
      if (_isTimeValid(now, widget.moment)) {
        _time = now;
      } else {
        _time = _SaisieSheet.getDefaultTimeForMoment(widget.moment);
      }
    }
  }

  bool _isTimeValid(TimeOfDay time, String moment) {
    int h = time.hour;
    switch (moment) {
      case 'Matin':
        return h >= 6 && h < 11;
      case 'Midi':
        return h >= 11 && h < 15;
      case 'Après-midi':
        return h >= 15 && h < 18;
      case 'Soir':
        return h >= 18 && h < 21;
      case 'Soirée':
        return h >= 21 || h < 6;
      default:
        return true;
    }
  }

  String _getRangeText(String moment) {
    switch (moment) {
      case 'Matin':
        return "6h - 11h";
      case 'Midi':
        return "11h - 15h";
      case 'Après-midi':
        return "15h - 18h";
      case 'Soir':
        return "18h - 21h";
      case 'Soirée':
        return "21h - 6h";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1F26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 20),
          ),
          Text(
            "AJOUTER UN VERRE (${widget.moment})",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Bière', 'Vin', 'Spiritueux']
                .map(
                  (type) => GestureDetector(
                    onTap: () => setState(() {
                      _t = type;
                      _d = (type == 'Bière'
                          ? 6.0
                          : (type == 'Vin' ? 13.0 : 40.0));
                    }),
                    child: Container(
                      width: 95,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _t == type
                            ? widget.accentColor.withOpacity(0.15)
                            : (widget.isDarkMode
                                  ? Colors.black26
                                  : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _t == type
                              ? widget.accentColor
                              : (widget.isDarkMode
                                    ? Colors.white10
                                    : Colors.black12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            type == 'Bière'
                                ? Icons.sports_bar
                                : type == 'Vin'
                                ? Icons.wine_bar
                                : Icons.local_drink,
                            color: _t == type
                                ? widget.accentColor
                                : Colors.blueGrey,
                          ),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                        '4cl',
                        '8cl',
                        '12.5cl',
                        '15cl',
                        '25cl',
                        '33cl',
                        '50cl',
                        '75cl',
                      ]
                      .map(
                        (vol) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(vol),
                            selected: _v == vol,
                            onSelected: (s) => setState(() => _v = vol),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            "DEGRÉ : ${_d.toInt()} %",
            style: TextStyle(
              color: widget.accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: widget.isDarkMode
                  ? Colors.white10
                  : Colors.black12,
              thumbColor: Colors.white,
              overlayColor: widget.accentColor.withOpacity(0.2),
              valueIndicatorColor: widget.accentColor,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              showValueIndicator: ShowValueIndicator.onDrag,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Colors.lightBlueAccent,
                          Colors.orange,
                          Colors.redAccent,
                          Color(0xFF8B0000),
                        ],
                      ).createShader(bounds);
                    },
                    child: Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Slider(
                  value: _d,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: "${_d.toInt()}%",
                  onChanged: (v) => setState(() => _d = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.access_time, color: widget.accentColor),
            title: Text("Heure (${_getRangeText(widget.moment)})"),
            trailing: TextButton(
              onPressed: () async {
                final p = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (p != null) {
                  if (_isTimeValid(p, widget.moment)) {
                    setState(() => _time = p);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "L'heure doit être comprise entre ${_getRangeText(widget.moment)}",
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(
                _time.format(context),
                style: TextStyle(
                  color: widget.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              DateTime finalDate = widget.date;
              if (widget.moment == 'Soirée' && _time.hour < 6) {
                finalDate = widget.date.add(const Duration(days: 1));
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
                  moment: widget.moment,
                  type: _t,
                  volume: _v,
                  degree: _d,
                  userId: widget.activeUserId,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("ENREGISTRER"),
          ),
        ],
      ),
    );
  }
}

Widget _glassModule({
  required Widget child,
  Color? borderColor,
  required bool isDarkMode,
  EdgeInsets? padding,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF3A4750).withOpacity(0.25)
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                borderColor ??
                (isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.08)),
          ),
        ),
        child: child,
      ),
    ),
  );
}
