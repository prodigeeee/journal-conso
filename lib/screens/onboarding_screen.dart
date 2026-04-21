import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _AuthScreenState {} // Placeholder to avoid confusion

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "Bienvenue sur Journal Conso",
      desc:
          "Une application élégante et privée pour suivre votre consommation de manière responsable.",
      icon: Icons.local_bar,
      color: const Color(0xFFEA9216),
    ),
    OnboardingData(
      title: "Synchronisation Cloud",
      desc:
          "Retrouvez vos données sur tous vos appareils (Web, Mobile) grâce à votre compte sécurisé Supabase.",
      icon: Icons.cloud_done,
      color: Colors.blueAccent,
    ),
    OnboardingData(
      title: "Vie Privée & Sécurité",
      desc:
          "Vos données sont chiffrées et protégées. Seul vous avez accès à votre historique.",
      icon: Icons.security,
      color: Colors.greenAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 2,
                colors: [
                  _pages[_currentPage].color.withValues(alpha: 0.15),
                  Colors.black,
                ],
              ),
            ),
          ),

          PageView.builder(
            controller: _controller,
            onPageChanged: (v) => setState(() => _currentPage = v),
            itemCount: _pages.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pages[i].color.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _pages[i].color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _pages[i].icon,
                        size: 80,
                        color: _pages[i].color,
                      ),
                    ),
                    const SizedBox(height: 50),
                    Text(
                      _pages[i].title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _pages[i].desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? _pages[index].color
                            : Colors.white24,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: glassModule(
                    isDarkMode: true,
                    padding: EdgeInsets.zero,
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage < _pages.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          widget.onDone();
                        }
                      },
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? "C'EST PARTI !"
                              : "SUIVANT",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: _pages[_currentPage].color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  OnboardingData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}
