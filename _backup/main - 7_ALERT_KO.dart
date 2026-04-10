import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
    name: json['name'],
    gender: json['gender'],
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
    userId: json['userId'],
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
  int _selectedIndex = 0;
  List<Consumption> _allConsumptions = [];
  List<UserProfile> _profiles = [];
  Map<String, String> _contexts = {};
  String _activeUserId = '';
  @override
  void initState() {
    super.initState();
    _initApp();
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

  Future<void> _exportFile() async {
    final data = {
      'profiles': _profiles,
      'consumptions': _allConsumptions,
      'contexts': _contexts,
    };
    final String jsonString = jsonEncode(data);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/backup_conso.json');
    await file.writeAsString(jsonString);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Ma sauvegarde Journal Conso');
  }

  Future<void> _importFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      final data = jsonDecode(content);
      setState(() {
        _profiles = (data['profiles'] as List)
            .map((i) => UserProfile.fromJson(i))
            .toList();
        _allConsumptions = (data['consumptions'] as List)
            .map((i) => Consumption.fromJson(i))
            .toList();
        _contexts = Map<String, String>.from(data['contexts'] ?? {});
      });
      await _saveAll();
    }
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
          Container(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.75)
                : Colors.white.withOpacity(0.5),
          ),
          Column(
            children: [
              Image.asset(
                'assets/images/title.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(activeUser.colorValue),
                            radius: 18,
                            backgroundImage: activeUser.imagePath != null
                                ? FileImage(File(activeUser.imagePath!))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PROFIL ACTUEL",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode
                                      ? Colors.white38
                                      : Colors.black54,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    activeUser.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: widget.accentColor,
                                    ),
                                    onSelected: (id) {
                                      setState(() => _activeUserId = id);
                                      _saveAll();
                                    },
                                    itemBuilder: (context) => _profiles
                                        .map(
                                          (p) => PopupMenuItem(
                                            value: p.id,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: Color(
                                                    p.colorValue,
                                                  ),
                                                  radius: 12,
                                                  backgroundImage:
                                                      p.imagePath != null
                                                      ? FileImage(
                                                          File(p.imagePath!),
                                                        )
                                                      : null,
                                                  child: p.imagePath == null
                                                      ? const Icon(
                                                          Icons.person,
                                                          size: 14,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(p.name),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    HomeScreen(
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      consumptions: userConsos,
                      activeUserId: _activeUserId,
                      contexts: _contexts,
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
                    ),
                    StatsScreen(
                      consumptions: userConsos,
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      activeUser: activeUser,
                    ),
                    OptionsScreen(
                      isDarkMode: widget.isDarkMode,
                      accentColor: widget.accentColor,
                      onThemeChanged: widget.onThemeChanged,
                      profiles: _profiles,
                      onProfilesChanged: _saveAll,
                      onReset: () {
                        setState(() {
                          _allConsumptions.clear();
                          _contexts.clear();
                        });
                        _saveAll();
                      },
                      onExport: _exportFile,
                      onImport: _importFile,
                    ),
                  ],
                ),
              ),
            ],
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
        onTap: (index) => setState(() => _selectedIndex = index),
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
    required this.isDarkMode,
    required this.accentColor,
    required this.activeUser,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1200);
  DateTime _selectedDate = DateTime.now();
  late DateTime _focusedMonth;
  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Future<void> _printMonthlyReport() async {
    final doc = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final firstDayOffset =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday - 1;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Rapport Mensuel : ${widget.activeUser.name} ($monthLabel)",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 7,
                  children: List.generate(42, (i) {
                    final dayNum = i - firstDayOffset + 1;
                    if (dayNum <= 0 || dayNum > daysInMonth) {
                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey100),
                        ),
                      );
                    }
                    final dateForConso = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month,
                      dayNum,
                    );
                    final dayConsos = widget.consumptions
                        .where(
                          (c) =>
                              c.date.day == dayNum &&
                              c.date.month == _focusedMonth.month,
                        )
                        .toList();
                    final contextKey =
                        "${widget.activeUserId}_${DateFormat('yyyyMMdd').format(dateForConso)}";
                    final dayContext = widget.contexts[contextKey] ?? "";
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        color: dayConsos.isNotEmpty ? PdfColors.orange50 : null,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "$dayNum",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (dayContext.isNotEmpty)
                            pw.Text(
                              dayContext,
                              style: pw.TextStyle(
                                fontSize: 5,
                                color: PdfColors.blueGrey,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          pw.SizedBox(height: 2),
                          ...dayConsos.map(
                            (c) => pw.Text(
                              "${c.type} ${c.volume} ${c.degree.toInt()}%",
                              style: const pw.TextStyle(fontSize: 4.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Rapport_$monthLabel',
    );
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
              ],
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _printMonthlyReport,
            child: _glassModule(
              isDarkMode: widget.isDarkMode,
              borderColor: widget.accentColor.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, color: widget.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "IMPRIMER LE MOIS (PDF)",
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
    final today = DateTime(now.year, now.month, now.day);
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
        final isFuture = date.isAfter(today);
        final isSel =
            date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        final hasC = widget.consumptions.any(
          (c) =>
              c.date.year == date.year &&
              c.date.month == date.month &&
              c.date.day == date.day,
        );
        return GestureDetector(
          onTap: isFuture ? null : () => setState(() => _selectedDate = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: isSel
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: widget.isDarkMode
                          ? [
                              const Color(0xFF8B5300),
                              const Color(0xFFEA9216),
                              const Color(0xFFFFD54F),
                            ]
                          : [
                              const Color(0xFF2C507E),
                              const Color(0xFF1A3A5F),
                              const Color(0xFF3B6B9E),
                            ],
                      stops: const [0.0, 0.7, 1.0],
                    )
                  : null,
              color: !isSel
                  ? (hasC
                        ? widget.accentColor.withOpacity(0.4)
                        : (widget.isDarkMode
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05)))
                  : null,
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  if (isSel) ...[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  Widget _momentTile(String moment) {
    final key =
        "${widget.activeUserId}_${DateFormat('yyyyMMdd').format(_selectedDate)}_$moment";
    final momentContext = widget.contexts[key];
    final momentConsos = widget.consumptions
        .where(
          (c) =>
              c.moment == moment &&
              c.date.year == _selectedDate.year &&
              c.date.month == _selectedDate.month &&
              c.date.day == _selectedDate.day,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _glassModule(
        isDarkMode: widget.isDarkMode,
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
                        : (widget.isDarkMode ? Colors.white24 : Colors.black26),
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
                children: momentConsos.map((c) => _consoDraggable(c)).toList(),
              ),
          ],
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
              widget.onUpdateContext(
                "${widget.activeUserId}_${DateFormat('yyyyMMdd').format(_selectedDate)}_$moment",
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
  bool _isNotificationSet = false;

  double _calculateCurrentBAC() {
    double r = widget.activeUser.gender == 'Homme' ? 0.7 : 0.6;
    final now = DateTime.now();
    double total = 0.0;

    final today = widget.consumptions
        .where(
          (c) =>
              c.date.day == now.day &&
              c.date.month == now.month &&
              c.date.year == now.year,
        )
        .toList();

    for (var c in today) {
      double vol = double.tryParse(c.volume.replaceAll('cl', '')) ?? 0;
      double grammes = (vol * 10 * c.degree * 0.8) / 100;
      double hoursPassed = now.difference(c.date).inMinutes / 60.0;
      double bac =
          (grammes / (widget.activeUser.weight * r)) - (0.15 * hoursPassed);
      if (bac > 0) total += bac;
    }
    return total;
  }

  Future<void> _scheduleNotification(
    double currentBac,
    int minutesRemaining,
  ) async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Permission de base
    await androidImplementation?.requestNotificationsPermission();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alcohol_tracker_channel_v5',
          'Alertes de Sécurité',
          channelDescription: 'Notifications de retour sous le seuil légal',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          showWhen: true,
        );

    try {
      // 1. Confirmation immédiate
      await flutterLocalNotificationsPlugin.show(
        999,
        'Alerte activée',
        'Le système vous préviendra dès le retour théorique sous 0,50g/L.',
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );

      // 2. Programmation finale
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Seuil légal atteint',
        'Vous êtes théoriquement redescendu sous le seuil légal (0,50g/L). Soyez prudent.',
        tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesRemaining)),
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      setState(() => _isNotificationSet = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              "Action requise : Autorisez 'Alarmes et rappels' dans les paramètres Android de l'appli.",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentBac = _calculateCurrentBAC();
    bool isDanger = currentBac >= 0.5;
    if (!isDanger && _isNotificationSet) _isNotificationSet = false;

    String countdownText = "Prêt à conduire";
    int totalMinutesRemaining = 0;

    if (currentBac > 0.5) {
      double hoursToLegal = (currentBac - 0.5) / 0.15;
      int h = hoursToLegal.floor();
      int m = ((hoursToLegal - h) * 60).round();
      countdownText = "${h}h ${m}min";
      totalMinutesRemaining = (hoursToLegal * 60).round();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _glassModule(
            isDarkMode: widget.isDarkMode,
            child: Column(
              children: [
                const Text(
                  "ALCOOLÉMIE ESTIMÉE (WIDMARK)",
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
                const Text(
                  "RETOUR À L'ÉTAT LÉGAL ACCEPTABLE DANS",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
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
                if (isDanger) ...[
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _isNotificationSet
                        ? null
                        : () => _scheduleNotification(
                            currentBac,
                            totalMinutesRemaining,
                          ),
                    icon: Icon(
                      _isNotificationSet
                          ? Icons.check_circle
                          : Icons.notifications_active,
                      size: 18,
                    ),
                    label: Text(
                      _isNotificationSet
                          ? "ALERTE EN COURS..."
                          : "M'ALERTER AU RETOUR AU SEUIL",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNotificationSet
                          ? Colors.grey.withOpacity(0.2)
                          : widget.accentColor.withOpacity(0.2),
                      foregroundColor: _isNotificationSet
                          ? Colors.grey
                          : widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                      SizedBox(width: 30, child: LineChart(_axisOnlyData())),
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
                    "RÉPARTITION GLOBALE PAR TYPE DE BOISSON",
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

  PieChartData _buildPieData() {
    Map<String, int> counts = {'Bière': 0, 'Vin': 0, 'Spiritueux': 0};
    for (var c in widget.consumptions) {
      if (counts.containsKey(c.type)) counts[c.type] = counts[c.type]! + 1;
    }
    int total = counts.values.reduce((a, b) => a + b);
    if (total == 0) {
      return PieChartData(
        sections: [
          PieChartSectionData(
            value: 1,
            color: Colors.grey.withOpacity(0.2),
            title: '',
          ),
        ],
      );
    }
    return PieChartData(
      sectionsSpace: 4,
      centerSpaceRadius: 35,
      sections: [
        PieChartSectionData(
          value: counts['Bière']!.toDouble(),
          color: Colors.amber,
          title: total > 0
              ? '${(counts['Bière']! / total * 100).round()}%'
              : '',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: counts['Vin']!.toDouble(),
          color: Colors.redAccent,
          title: total > 0 ? '${(counts['Vin']! / total * 100).round()}%' : '',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: counts['Spiritueux']!.toDouble(),
          color: Colors.blueAccent,
          title: total > 0
              ? '${(counts['Spiritueux']! / total * 100).round()}%'
              : '',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
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
      children: [
        _legendItem("Bière", Colors.amber, counts['Bière']!),
        const SizedBox(height: 8),
        _legendItem("Vin", Colors.redAccent, counts['Vin']!),
        const SizedBox(height: 8),
        _legendItem("Spirits", Colors.blueAccent, counts['Spiritueux']!),
      ],
    );
  }

  Widget _legendItem(String label, Color color, int val) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        "$label: ",
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      Text(
        "$val",
        style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
      ),
    ],
  );

  LineChartData _axisOnlyData() => LineChartData(
    gridData: const FlGridData(show: false),
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 2,
          reservedSize: 25,
          getTitlesWidget: (v, m) => Text(
            '${v.toInt()}',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 8),
          ),
        ),
      ),
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    minY: 0,
    maxY: 10,
    lineBarsData: [
      LineChartBarData(spots: [const FlSpot(0, 0)], show: false),
    ],
  );

  LineChartData _mainChartData() {
    int count = (_period == 'Semaine')
        ? 7
        : (_period == 'Mois')
        ? 30
        : 12;
    List<FlSpot> spots = [];
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    double maxFound = 0;
    for (int i = 0; i < count; i++) {
      DateTime d = (_period == 'Année')
          ? DateTime(now.year, now.month - (count - 1 - i), 1)
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
    return LineChartData(
      minX: 0,
      maxX: (count - 1).toDouble(),
      minY: 0,
      maxY: maxFound < 5 ? 6 : maxFound + 2,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
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
            reservedSize: 45,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx < 0 || idx >= count) return const SizedBox.shrink();
              DateTime d = (_period == 'Année')
                  ? DateTime(now.year, now.month - (count - 1 - idx), 1)
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
          barWidth: 1.5,
          gradient: LinearGradient(
            colors: [widget.accentColor, Colors.orange, Colors.red],
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
}

class OptionsScreen extends StatefulWidget {
  final List<UserProfile> profiles;
  final VoidCallback onProfilesChanged;
  final VoidCallback onReset;
  final bool isDarkMode;
  final Color accentColor;
  final Function(bool) onThemeChanged;
  final VoidCallback onExport;
  final VoidCallback onImport;
  const OptionsScreen({
    super.key,
    required this.profiles,
    required this.onProfilesChanged,
    required this.onReset,
    required this.isDarkMode,
    required this.accentColor,
    required this.onThemeChanged,
    required this.onExport,
    required this.onImport,
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
            padding: const EdgeInsets.only(bottom: 8),
            child: _glassModule(
              isDarkMode: widget.isDarkMode,
              child: ListTile(
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
                title: Text(p.name, style: TextStyle(color: itemTxt)),
                subtitle: Text(
                  "${p.age} ans • ${p.weight}kg",
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white38 : Colors.black54,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.edit, color: widget.accentColor),
                  onPressed: () => _editProfile(p),
                ),
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
          "DATA & SAUVEGARDE",
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
              ListTile(
                dense: true,
                leading: Icon(Icons.share, color: widget.accentColor, size: 20),
                title: Text(
                  "Exporter (.json)",
                  style: TextStyle(color: itemTxt),
                ),
                onTap: widget.onExport,
              ),
              Divider(
                height: 1,
                color: widget.isDarkMode ? Colors.white10 : Colors.black12,
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.file_open,
                  color: widget.accentColor,
                  size: 20,
                ),
                title: Text(
                  "Importer (.json)",
                  style: TextStyle(color: itemTxt),
                ),
                onTap: widget.onImport,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          "PRÉFÉRENCES",
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
      ],
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
  const _SaisieSheet({
    required this.moment,
    required this.date,
    required this.activeUserId,
    this.existingConso,
    required this.onSave,
    required this.isDarkMode,
    required this.accentColor,
  });
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
    _time = widget.existingConso != null
        ? TimeOfDay.fromDateTime(widget.existingConso!.date)
        : _getDefaultTime(widget.moment);
  }

  TimeOfDay _getDefaultTime(String m) {
    if (m == 'Matin') return const TimeOfDay(hour: 8, minute: 0);
    if (m == 'Midi') return const TimeOfDay(hour: 12, minute: 30);
    if (m == 'Après-midi') return const TimeOfDay(hour: 16, minute: 0);
    if (m == 'Soir') return const TimeOfDay(hour: 19, minute: 30);
    return const TimeOfDay(hour: 22, minute: 30);
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
            "AJOUTER UN VERRE",
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
            title: const Text("Heure du verre"),
            trailing: TextButton(
              onPressed: () async {
                final p = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (p != null) setState(() => _time = p);
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
              final fDate = DateTime(
                widget.date.year,
                widget.date.month,
                widget.date.day,
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
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(12),
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
