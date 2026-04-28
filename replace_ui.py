import sys
import codecs

with codecs.open('lib/main.dart', 'r', 'utf-8') as f:
    content = f.read()

start_str = "  Widget build(BuildContext context) {"
start_idx = content.find(start_str)

if start_idx == -1:
    print("Start not found")
    sys.exit(1)

# Find the end of the _SaisieSheetState class
# It ends with } and the next thing is probably another class or end of file
# Let's search for the end of _buildPremiumDateTimeBlock
end_str = "  }\n}\n"
end_idx = content.find(end_str, start_idx)

if end_idx == -1:
    print("End not found")
    sys.exit(1)

new_methods = """  Widget build(BuildContext context) {
    final Color effectiveAccent = const Color(0xFFFF7B00);
    final bool isDark = widget.isDarkMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0C10) : Colors.white,
        image: isDark
            ? DecorationImage(
                image: const AssetImage('assets/images/conso_bg.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  const Color(0xFF0A0C10).withOpacity(0.8),
                  BlendMode.darken,
                ),
              )
            : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: effectiveAccent.withOpacity(0.08),
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
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                        color: effectiveAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: effectiveAccent.withOpacity(0.2)),
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
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bar_chart_rounded, color: effectiveAccent, size: 18),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161A20).withOpacity(0.6) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: effectiveAccent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveAccent.withOpacity(0.2),
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
                        suffixIcon: Icon(Icons.mic_none_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 22),
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
                  const SizedBox(height: 12),

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
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                        Container(width: 1, height: 120, color: Colors.white.withOpacity(0.1)),
                        Expanded(
                          child: _buildWheelSelector(
                            "DEGRÉ D'ALCOOL",
                            _degreeCtrl,
                            List.generate(51, (i) => "$i%"),
                            "${_d.toInt()}%",
                            Icons.water_drop,
                            (idx) => setState(() => _d = idx.toDouble()),
                            effectiveAccent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

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

                  const SizedBox(height: 32),

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
                            color: effectiveAccent.withOpacity(0.5),
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
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    IconData icon;
    if (type == L10n.s('common.beer')) {
      icon = Icons.sports_bar_rounded;
    } else if (type == L10n.s('common.wine'))
      icon = Icons.wine_bar_rounded;
    else if (type == L10n.s('common.soft'))
      icon = Icons.local_cafe_rounded;
    else
      icon = Icons.local_drink_rounded;

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
        if (vIdx != -1) _volumeCtrl.jumpToItem(vIdx);
        _degreeCtrl.jumpToItem(_d.round());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isSel
              ? LinearGradient(
                  colors: [accent.withOpacity(0.6), accent.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSel ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSel ? accent : Colors.white.withOpacity(0.05),
            width: isSel ? 2 : 1,
          ),
          boxShadow: isSel
              ? [
                  BoxShadow(color: accent.withOpacity(0.4), blurRadius: 15, spreadRadius: 1),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black38),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black38),
              ),
            ),
          ],
        ),
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
  }) {
    final bool isDark = widget.isDarkMode;
    
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
                color: accent,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              valUnit,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 1, width: double.infinity, decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: accent, blurRadius: 4, spreadRadius: 1)],
                    color: accent.withOpacity(0.8),
                  )),
                  const SizedBox(height: 38),
                  Container(height: 1, width: double.infinity, decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: accent, blurRadius: 4, spreadRadius: 1)],
                    color: accent.withOpacity(0.8),
                  )),
                ],
              ),
              ListWheelScrollView.useDelegate(
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
                          color: isSel ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    );
                  },
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
          color: isDark ? const Color(0xFF161A20).withOpacity(0.8) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
            if (subValue.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
"""

new_content = content[:start_idx] + new_methods + content[end_idx:]

with codecs.open('lib/main.dart', 'w', 'utf-8') as f:
    f.write(new_content)

print("Replacement successful")
