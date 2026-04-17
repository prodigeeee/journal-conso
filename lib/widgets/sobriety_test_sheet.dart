import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'glass_widgets.dart';
import '../utils/l10n_service.dart';

class SobrietyTestSheet extends StatefulWidget {
  final bool isDarkMode;
  final Color accentColor;
  const SobrietyTestSheet({
    super.key,
    required this.isDarkMode,
    required this.accentColor,
  });
  @override
  State<SobrietyTestSheet> createState() => _SobrietyTestSheetState();
}

class _SobrietyTestSheetState extends State<SobrietyTestSheet>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isReady = false;
  int? _reactionTime;
  DateTime? _startTime;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _start() {
    setState(() {
      _isPlaying = true;
      _isReady = false;
      _reactionTime = null;
    });
    int delay = 2000 + (Random().nextInt(3000));
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() {
          _isReady = true;
          _startTime = DateTime.now();
        });
      }
    });
  }

  void _tap() {
    if (!_isReady) {
      _timer?.cancel();
      setState(() {
        _isPlaying = false;
        _reactionTime = -1; // Trop tôt
      });
      return;
    }
    final diff = DateTime.now().difference(_startTime!).inMilliseconds;
    setState(() {
      _isPlaying = false;
      _isReady = false;
      _reactionTime = diff;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color targetColor = _isReady
        ? Colors.greenAccent
        : (_isPlaying
              ? Colors.redAccent.withValues(alpha: 0.3)
              : widget.accentColor.withValues(alpha: 0.2));

    String statusText = !_isPlaying
        ? (_reactionTime == null
              ? L10n.s('test.ready')
              : (_reactionTime == -1 ? L10n.s('test.too_early') : "$_reactionTime ms"))
        : (_isReady ? L10n.s('test.press') : L10n.s('test.wait'));

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.s('test.lab'),
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      L10n.s('test.reflex_title'),
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!_isPlaying && _reactionTime == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: widget.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        L10n.s('test.instructions'),
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: _isPlaying ? _tap : _start,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isPlaying && !_isReady)
                    ...List.generate(
                      3,
                      (i) => AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width:
                                150 + (i * 40) + (_pulseController.value * 30),
                            height:
                                150 + (i * 40) + (_pulseController.value * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.accentColor.withValues(
                                  alpha: 0.1 * (1 - _pulseController.value),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isReady ? 220 : 180,
                    height: _isReady ? 220 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: targetColor,
                      boxShadow: [
                        BoxShadow(
                          color: targetColor.withValues(alpha: 0.6),
                          blurRadius: _isReady ? 40 : 20,
                          spreadRadius: _isReady ? 10 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isReady
                              ? Colors.black
                              : (widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87),
                          fontSize: _isReady ? 32 : 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                if (_reactionTime != null && _reactionTime! > 0)
                  _buildResultsCard(),
                const SizedBox(height: 20),
                Text(
                  _isPlaying
                      ? L10n.s('test.dont_quit')
                      : L10n.s('test.tap_to_start'),
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    String rank = L10n.s('test.rank_pilot');
    Color rankColor = Colors.greenAccent;
    if (_reactionTime! > 300) {
      rank = L10n.s('test.rank_medium');
      rankColor = Colors.orangeAccent;
    }
    if (_reactionTime! > 500) {
      rank = L10n.s('test.rank_slowed');
      rankColor = Colors.redAccent;
    }

    return glassModule(
      isDarkMode: widget.isDarkMode,
      showHalo: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resultStat(L10n.s('test.time_label'), "$_reactionTime", "ms"),
          Container(
            width: 1,
            height: 40,
            color: widget.isDarkMode ? Colors.white10 : Colors.black12,
          ),
          _resultStat(L10n.s('test.rank_label'), rank, "", color: rankColor),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value, String unit, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color:
                    color ??
                    (widget.isDarkMode ? Colors.white : Colors.black87),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                " $unit",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
