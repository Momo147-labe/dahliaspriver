import 'dart:io' as io;

import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/utils/mention_helper.dart';

class GlobalRankingPage extends StatefulWidget {
  final bool isDark;

  const GlobalRankingPage({super.key, required this.isDark});

  @override
  State<GlobalRankingPage> createState() => _GlobalRankingPageState();
}

class _GlobalRankingPageState extends State<GlobalRankingPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];
  int? _selectedClassId;

  List<Map<String, dynamic>> _studentRankings = [];
  List<Map<String, dynamic>> _mentions = [];
  List<int> _trimesters = [];
  Map<int, List<int>> _sequencesByTrimester = {};
  Map<int, String> _sequenceNames = {}; // sequenceNumber -> real name
  List<Map<String, dynamic>> _subjects = [];

  double _moyennePassage = 10.0;
  bool _sortAscending = false;

  // Stats
  int _totalStudents = 0;
  int _maleCount = 0;
  int _femaleCount = 0;
  int _admittedCount = 0;
  int _failedCount = 0;
  double _classAverage = 0.0;
  double _successRate = 0.0;
  double _maleSuccessRate = 0.0;
  double _femaleSuccessRate = 0.0;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final activeAnnee = await _dbHelper.getActiveAnneeScolaire();
      int anneeId = activeAnnee?['id'] ?? 1;

      final classes = await _dbHelper.classeDao.getClassesByAnnee(anneeId);
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty) {
          _selectedClassId = _classes.first['id'] as int;
          _loadRankingData();
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement classes: $e')),
        );
      }
    }
  }

  Future<void> _loadRankingData() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoading = true);

    try {
      final activeAnnee = await _dbHelper.getActiveAnneeScolaire();
      int anneeId = activeAnnee?['id'] ?? 1;

      final classeInfo = await _dbHelper.classeDao.getClasseWithCycle(
        _selectedClassId!,
      );
      if (classeInfo != null) {
        _moyennePassage =
            (classeInfo['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
      }

      final rawData = await _dbHelper.getClassGradesData(
        anneeId,
        _selectedClassId!,
      );

      // Fetch mentions for this cycle
      _mentions = [];
      if (classeInfo != null && classeInfo['cycle_id'] != null) {
        _mentions = await _dbHelper.getMentionsByCycle(
          classeInfo['cycle_id'] as int,
        );
      }
      // Fetch sequence names for this academic year
      _sequenceNames = {};
      try {
        final seqRows = await _dbHelper.configDao.getSequences(anneeId);
        for (final r in seqRows) {
          final num = r['numero_sequence'] as int?;
          final nom = r['nom'] as String?;
          if (num != null && nom != null && nom.isNotEmpty) {
            _sequenceNames[num] = nom;
          }
        }
      } catch (_) {}

      Map<int, Map<String, dynamic>> studentsMap = {};
      Set<int> trimestersSet = {};
      Map<int, Set<int>> sequencesByTrimesterSet = {};
      Map<int, Map<String, dynamic>> subjectsMap = {};

      for (var row in rawData) {
        final eleveId = row['eleve_id'] as int;
        if (!studentsMap.containsKey(eleveId)) {
          studentsMap[eleveId] = {
            'eleve_id': eleveId,
            'nom': row['eleve_nom'],
            'prenom': row['eleve_prenom'],
            'photo': row['eleve_photo'],
            'matricule': row['matricule'],
            'date_naissance': row['date_naissance'],
            'sexe': row['sexe'], // Added sexe
            'subjects': <int, Map<String, dynamic>>{},
            'moyenne_generale': 0.0,
            'rang': 0,
            'statut': '',
          };
        }

        final matiereId = row['matiere_id'] as int?;
        if (matiereId != null) {
          if (!subjectsMap.containsKey(matiereId)) {
            subjectsMap[matiereId] = {
              'id': matiereId,
              'nom': row['matiere_nom'],
              'coefficient': (row['coefficient'] as num).toDouble(),
            };
          }

          final subjectMap =
              studentsMap[eleveId]!['subjects']
                  as Map<int, Map<String, dynamic>>;
          if (!subjectMap.containsKey(matiereId)) {
            subjectMap[matiereId] = {
              'moyenne': 0.0,
              'trimesters':
                  <
                    int,
                    Map<String, dynamic>
                  >{}, // trim -> { moyenne, seqs: { seq: note } }
            };
          }

          final trimester = row['trimestre'] as int?;
          if (trimester != null) {
            trimestersSet.add(trimester);
            sequencesByTrimesterSet.putIfAbsent(trimester, () => {});

            final trimMap =
                subjectMap[matiereId]!['trimesters']
                    as Map<int, Map<String, dynamic>>;
            if (!trimMap.containsKey(trimester)) {
              trimMap[trimester] = {
                'moyenne': 0.0,
                'sequences': <int, double>{},
              };
            }

            final sequence = row['sequence'] as int?;
            final noteValue = row['note'];
            if (sequence != null && noteValue != null) {
              sequencesByTrimesterSet[trimester]!.add(sequence);
              (trimMap[trimester]!['sequences'] as Map<int, double>)[sequence] =
                  (noteValue as num).toDouble();
            }
          }
        }
      }

      // Calculate Averages
      for (var s in studentsMap.values) {
        double sumSubjectAveragesWeighted = 0;
        double sumCoefficients = 0;

        final subjectMap = s['subjects'] as Map<int, Map<String, dynamic>>;
        for (var matiereId in subjectMap.keys) {
          final subj = subjectMap[matiereId]!;
          final trimesters =
              subj['trimesters'] as Map<int, Map<String, dynamic>>;

          double sumTrimesterAverages = 0;
          int trimestersCount = 0;

          for (var trimKey in trimesters.keys) {
            final trimData = trimesters[trimKey]!;
            final seqs = trimData['sequences'] as Map<int, double>;

            if (seqs.isNotEmpty) {
              final trimAvg = seqs.values.reduce((a, b) => a + b) / seqs.length;
              trimData['moyenne'] = trimAvg;
              sumTrimesterAverages += trimAvg;
              trimestersCount++;
            }
          }

          double finalSubjectAvg = 0.0;
          if (trimestersCount > 0) {
            finalSubjectAvg = sumTrimesterAverages / trimestersCount;
            subj['moyenne'] = finalSubjectAvg;

            final coeff = subjectsMap[matiereId]!['coefficient'] as double;
            sumSubjectAveragesWeighted += (finalSubjectAvg * coeff);
            sumCoefficients += coeff;
          }
        }

        if (sumCoefficients > 0) {
          s['moyenne_generale'] = sumSubjectAveragesWeighted / sumCoefficients;
        }

        s['statut'] = (s['moyenne_generale'] as double) >= _moyennePassage
            ? 'Admis'
            : 'Échec';

        // Add Mention
        s['mention_data'] = MentionHelper.getMentionForGrade(
          s['moyenne_generale'] as double,
          _mentions,
        );
      }

      // Format Headers
      _trimesters = trimestersSet.toList()..sort();
      _sequencesByTrimester = {};
      for (var t in _trimesters) {
        _sequencesByTrimester[t] = sequencesByTrimesterSet[t]!.toList()..sort();
      }
      _subjects = subjectsMap.values.toList()
        ..sort((a, b) => a['nom'].toString().compareTo(b['nom'].toString()));

      List<Map<String, dynamic>> rankings = studentsMap.values.toList();
      _studentRankings = _sortRankings(rankings, ascending: _sortAscending);

      // ── Compute Stats ────────────────────────────────────────────────────────
      _totalStudents = _studentRankings.length;
      _maleCount = _studentRankings.where((s) => s['sexe'] == 'M').length;
      _femaleCount = _studentRankings.where((s) => s['sexe'] == 'F').length;
      _admittedCount = _studentRankings
          .where((s) => s['statut'] == 'Admis')
          .length;
      _failedCount = _totalStudents - _admittedCount;

      if (_totalStudents > 0) {
        _classAverage =
            _studentRankings.fold<double>(
              0.0,
              (sum, s) => sum + (s['moyenne_generale'] as double),
            ) /
            _totalStudents;
        _successRate = (_admittedCount / _totalStudents) * 100;

        final admittedMales = _studentRankings
            .where((s) => s['sexe'] == 'M' && s['statut'] == 'Admis')
            .length;
        _maleSuccessRate = _maleCount > 0
            ? (admittedMales / _maleCount) * 100
            : 0.0;

        final admittedFemales = _studentRankings
            .where((s) => s['sexe'] == 'F' && s['statut'] == 'Admis')
            .length;
        _femaleSuccessRate = _femaleCount > 0
            ? (admittedFemales / _femaleCount) * 100
            : 0.0;
      } else {
        _classAverage = 0.0;
        _successRate = 0.0;
        _maleSuccessRate = 0.0;
        _femaleSuccessRate = 0.0;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur analyse: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _sortRankings(
    List<Map<String, dynamic>> list, {
    required bool ascending,
  }) {
    list.sort((a, b) {
      final avgA = a['moyenne_generale'] as double;
      final avgB = b['moyenne_generale'] as double;
      return ascending ? avgA.compareTo(avgB) : avgB.compareTo(avgA);
    });

    int currentRank = 1;
    for (int i = 0; i < list.length; i++) {
      if (i > 0 &&
          (list[i]['moyenne_generale'] as double) ==
              (list[i - 1]['moyenne_generale'] as double)) {
        list[i]['rang'] = list[i - 1]['rang'];
      } else {
        list[i]['rang'] = currentRank;
      }
      currentRank++;
    }
    return list;
  }

  void _onSortToggle() {
    setState(() {
      _sortAscending = !_sortAscending;
      _studentRankings = _sortRankings(
        _studentRankings,
        ascending: _sortAscending,
      );
    });
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: widget.isDark ? Colors.white : AppTheme.primaryColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classement Général',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Récapitulatif et admission annuelle',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? AppTheme.cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark ? Colors.white12 : Colors.grey[300]!,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedClassId,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  dropdownColor: widget.isDark
                      ? AppTheme.surfaceDark
                      : Colors.white,
                  items: _classes.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(
                        c['nom'],
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedClassId = v);
                      _loadRankingData();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _onSortToggle,
            icon: Icon(
              _sortAscending
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            label: const Text('Trier Moyenne'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark ? AppTheme.cardDark : Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              side: BorderSide(
                color: widget.isDark ? Colors.white12 : Colors.grey[300]!,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingView() {
    if (_studentRankings.isEmpty) {
      return Center(
        child: Text(
          'Aucun élève trouvé ou aucune note saisie',
          style: TextStyle(
            color: widget.isDark ? Colors.white60 : Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the massive table if screen is wide enough
        if (constraints.maxWidth > 800) {
          return _buildMassiveDataTable();
        }
        return _buildMobileRankingList();
      },
    );
  }

  Widget _buildMobileRankingList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _studentRankings.length,
      itemBuilder: (context, index) {
        final student = _studentRankings[index];
        return _buildStudentRankingCard(student);
      },
    );
  }

  Widget _buildMassiveDataTable() {
    const double rowHeight = 56.0;
    const double headerHeight = 72.0; // 32 (upper) + 40 (lower)
    const double rankW = 48.0;
    const double birthW = 100.0;
    const double nameW = 280.0;
    // Removed matriculeW as it's now merged into nameW
    const double seqW = 72.0;
    const double trimW = 80.0;
    const double annW = 72.0;
    const double pondW = 72.0;

    final bg = widget.isDark ? AppTheme.surfaceDark : Colors.white;
    final headerBg = widget.isDark
        ? AppTheme.cardDark
        : const Color(0xFFF5F6FA);
    final border = widget.isDark ? Colors.white12 : Colors.grey.shade200;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    // ── helpers ──────────────────────────────────────────────────────────────
    Widget hCell(
      String text,
      double w, {
      Color? color,
      FontWeight? fw,
      TextAlign align = TextAlign.center,
    }) {
      return Container(
        width: w,
        height: headerHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: headerBg,
          border: Border(
            right: BorderSide(color: border),
            bottom: BorderSide(color: border, width: 2),
          ),
        ),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 11,
            fontWeight: fw ?? FontWeight.bold,
            color: color ?? textColor,
          ),
        ),
      );
    }

    Widget dCell(Widget child, double w, {bool isEven = false}) {
      return Container(
        width: w,
        height: rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEven
              ? (widget.isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.shade50)
              : bg,
          border: Border(right: BorderSide(color: border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      );
    }

    // ── fixed left columns ────────────────────────────────────────────────────
    Widget buildFixedPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row (synchronized height with two-row header)
          Row(
            children: [
              hCell('Rang', rankW, fw: FontWeight.w900),
              hCell('Né(e) le', birthW, fw: FontWeight.w900),
              hCell(
                'Élève & Matricule',
                nameW,
                align: TextAlign.left,
                fw: FontWeight.w900,
              ),
            ],
          ),
          // data rows
          Expanded(
            child: ListView.builder(
              controller: _verticalScrollController,
              itemCount: _studentRankings.length,
              itemBuilder: (_, i) {
                final s = _studentRankings[i];
                final isEven = i.isEven;
                final photo = s['photo'] as String?;
                final hasPhoto = photo != null && photo.isNotEmpty;
                return Row(
                  children: [
                    dCell(
                      Text(
                        '${s['rang']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      rankW,
                      isEven: isEven,
                    ),
                    dCell(
                      Builder(
                        builder: (context) {
                          final rawDate = s['date_naissance'] as String?;
                          String displayDate = '-';
                          if (rawDate != null && rawDate.isNotEmpty) {
                            try {
                              final parts = rawDate.split('-');
                              if (parts.length == 3) {
                                displayDate =
                                    '${parts[2]}/${parts[1]}/${parts[0]}';
                              } else {
                                displayDate = rawDate;
                              }
                            } catch (_) {
                              displayDate = rawDate;
                            }
                          }
                          return Text(
                            displayDate,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          );
                        },
                      ),
                      birthW,
                      isEven: isEven,
                    ),
                    dCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: AppTheme.primaryColor.withOpacity(
                              0.1,
                            ),
                            backgroundImage: hasPhoto
                                ? FileImage(io.File(photo))
                                : null,
                            child: !hasPhoto
                                ? Text(
                                    s['nom'][0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s['nom']} ${s['prenom']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${s['matricule']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      nameW,
                      isEven: isEven,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    // ── scrollable right columns ─────────────────────────────────────────────
    // ── Two-level grouped header ──────────────────────────────────────────────
    Widget groupCell(
      String text,
      double w, {
      Color? bg,
      Color? fg,
      bool isTitle = false,
      FontWeight? fw,
    }) {
      return Container(
        width: w,
        height: isTitle ? 32.0 : 40.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              bg ?? (widget.isDark ? AppTheme.surfaceDark : Colors.grey[100]),
          border: Border(
            right: BorderSide(color: border, width: isTitle ? 2 : 1),
            bottom: BorderSide(color: border, width: 2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: isTitle ? 11 : 10,
            fontWeight: fw ?? (isTitle ? FontWeight.w900 : FontWeight.bold),
            color: fg ?? textColor,
          ),
        ),
      );
    }

    final List<Widget> groupTitleCells = [];
    final List<Widget> subLabelCells = [];

    // Alternating group background colors for visual separation
    final List<Color> groupColors = widget.isDark
        ? [Colors.blueGrey.withOpacity(0.2), Colors.blueGrey.withOpacity(0.1)]
        : [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.12),
          ];

    int groupIdx = 0;
    for (var subj in _subjects) {
      final coef = (subj['coefficient'] as num).toDouble();
      final name = '${subj['nom']} (C:${coef.toStringAsFixed(0)})';
      final groupBg = groupColors[groupIdx % 2];
      groupIdx++;

      double subjW = 0;
      for (var t in _trimesters) {
        subjW += seqW * (_sequencesByTrimester[t]?.length ?? 0);
        subjW += trimW;
      }
      subjW += annW + pondW;

      groupTitleCells.add(
        groupCell(
          name,
          subjW,
          bg: groupBg,
          fg: AppTheme.primaryColor,
          isTitle: true,
        ),
      );

      for (var t in _trimesters) {
        for (var s in _sequencesByTrimester[t]!) {
          subLabelCells.add(
            groupCell(_sequenceNames[s] ?? 'S$s', seqW, bg: groupBg),
          );
        }
        subLabelCells.add(
          groupCell('Moy T$t', trimW, bg: groupBg, fg: AppTheme.primaryColor),
        );
      }
      subLabelCells.add(groupCell('Ann.', annW, bg: groupBg));
      subLabelCells.add(
        groupCell('Pond.', pondW, bg: groupBg, fg: Colors.orange),
      );
    }

    groupTitleCells.add(
      groupCell(
        'RÉSULTATS GLOBAUX',
        90 + 80 + 120 + 220, // Added 120 for Mention + 220 for Appreciation
        bg: AppTheme.primaryColor,
        fg: Colors.white,
        isTitle: true,
      ),
    );
    subLabelCells.add(
      groupCell(
        'Moy. Gén.',
        90,
        bg: AppTheme.primaryColor.withOpacity(0.9),
        fg: Colors.white,
      ),
    );
    subLabelCells.add(
      groupCell(
        'Décision',
        80,
        bg: AppTheme.primaryColor.withOpacity(0.9),
        fg: Colors.white,
      ),
    );
    subLabelCells.add(
      groupCell(
        'Mention',
        120,
        bg: AppTheme.primaryColor.withOpacity(0.9),
        fg: Colors.white,
      ),
    );
    subLabelCells.add(
      groupCell(
        'Appréciation',
        220,
        bg: AppTheme.primaryColor.withOpacity(0.9),
        fg: Colors.white,
      ),
    );

    Widget buildScrollablePanel() {
      double totalW = 0;
      for (var _ in _subjects) {
        for (var t in _trimesters) {
          totalW += seqW * (_sequencesByTrimester[t]?.length ?? 0);
          totalW += trimW;
        }
        totalW += annW + pondW;
      }
      totalW += 90 + 80 + 120 + 220; // Added Mention and Appreciation columns

      return SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (2 rows) ──
              Column(
                children: [
                  Row(children: groupTitleCells),
                  Row(children: subLabelCells),
                ],
              ),
              // ── Data rows ──
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollUpdateNotification &&
                        n.metrics.axis == Axis.vertical &&
                        _verticalScrollController.hasClients &&
                        _verticalScrollController.offset != n.metrics.pixels) {
                      _verticalScrollController.jumpTo(n.metrics.pixels);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: _studentRankings.length,
                    itemBuilder: (_, i) {
                      final student = _studentRankings[i];
                      final isPassing =
                          (student['moyenne_generale'] as double) >=
                          _moyennePassage;
                      final sd =
                          student['subjects'] as Map<int, Map<String, dynamic>>;
                      final isEven = i.isEven;

                      final List<Widget> cells = [];
                      for (var subj in _subjects) {
                        final subjData = sd[subj['id']];
                        final coef = (subj['coefficient'] as num).toDouble();
                        for (var t in _trimesters) {
                          for (var s in _sequencesByTrimester[t]!) {
                            final seqVal =
                                subjData?['trimesters']?[t]?['sequences']?[s]
                                    as double?;
                            cells.add(
                              dCell(
                                Text(
                                  seqVal?.toStringAsFixed(1) ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                seqW,
                                isEven: isEven,
                              ),
                            );
                          }
                          final trimVal =
                              subjData?['trimesters']?[t]?['moyenne']
                                  as double?;
                          cells.add(
                            dCell(
                              Text(
                                trimVal?.toStringAsFixed(1) ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              trimW,
                              isEven: isEven,
                            ),
                          );
                        }
                        final anVal = subjData?['moyenne'] as double?;
                        cells.add(
                          dCell(
                            Text(
                              anVal?.toStringAsFixed(2) ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            annW,
                            isEven: isEven,
                          ),
                        );
                        final pond = anVal != null ? (anVal * coef) : null;
                        cells.add(
                          dCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                pond?.toStringAsFixed(1) ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            pondW,
                            isEven: isEven,
                          ),
                        );
                      }

                      // Moy Générale
                      final moyGen = student['moyenne_generale'] as double;
                      cells.add(
                        dCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPassing
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              moyGen.toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          90,
                          isEven: isEven,
                        ),
                      );

                      // Décision
                      cells.add(
                        dCell(
                          Text(
                            isPassing ? 'Admis' : 'Échec',
                            style: TextStyle(
                              color: isPassing
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          80,
                          isEven: isEven,
                        ),
                      );

                      // Mention
                      final mentionData =
                          student['mention_data'] as Map<String, dynamic>?;
                      cells.add(
                        dCell(
                          mentionData != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MentionHelper.getMentionColor(
                                      mentionData['couleur'],
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: MentionHelper.getMentionColor(
                                        mentionData['couleur'],
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        MentionHelper.getMentionIcon(
                                          mentionData['icone'],
                                        ),
                                        size: 14,
                                        color: MentionHelper.getMentionColor(
                                          mentionData['couleur'],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        MentionHelper.stripEmojis(
                                          mentionData['label'] ?? '',
                                        ),
                                        style: TextStyle(
                                          color: MentionHelper.getMentionColor(
                                            mentionData['couleur'],
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text('-'),
                          120,
                          isEven: isEven,
                        ),
                      );

                      // Appréciation
                      cells.add(
                        dCell(
                          Text(
                            MentionHelper.stripEmojis(
                              mentionData?['appreciation'] ?? '-',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.black87,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          220,
                          isEven: isEven,
                        ),
                      );

                      // Plain Row — no individual ScrollView needed
                      return Row(children: cells);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use LayoutBuilder to get a finite height for the two side-by-side panels.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use full available height from Expanded
        final tableH = constraints.maxHeight;

        return Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          height: tableH,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed left panel – fixed width, fills container height
                SizedBox(
                  width: rankW + birthW + nameW,
                  height: tableH,
                  child: buildFixedPanel(),
                ),
                // Scrollable right panel – takes remaining width
                Expanded(
                  child: SizedBox(
                    height: tableH,
                    child: buildScrollablePanel(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentRankingCard(Map<String, dynamic> student) {
    final avg = student['moyenne_generale'] as double;
    final isPassing = avg >= _moyennePassage;
    final photo = student['photo'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: widget.isDark ? AppTheme.cardDark : Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPassing
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: (photo != null && photo.isNotEmpty)
              ? FileImage(io.File(photo))
              : null,
          child: (photo == null || photo.isEmpty)
              ? Text(
                  student['nom'][0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          '${student['nom']} ${student['prenom']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Rang: ${student['rang']}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPassing ? 'Admis' : 'Échec',
                  style: TextStyle(
                    color: isPassing
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (student['mention_data'] != null)
              Builder(
                builder: (context) {
                  final m = student['mention_data'] as Map<String, dynamic>;
                  final color = MentionHelper.getMentionColor(m['couleur']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(
                            MentionHelper.stripEmojis(m['label'] ?? ''),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (m['appreciation'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 2),
                            child: Text(
                              MentionHelper.stripEmojis(
                                m['appreciation'].toString(),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: widget.isDark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isPassing ? AppTheme.successColor : AppTheme.errorColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            avg.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        children: [_buildStudentDetailsTable(student)],
      ),
    );
  }

  Widget _buildStudentDetailsTable(Map<String, dynamic> student) {
    if (_subjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Aucune matière configurée'),
      );
    }

    final subjectsData = student['subjects'] as Map<int, Map<String, dynamic>>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 24,
          columns: [
            const DataColumn(
              label: Text(
                'Matières',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Coef.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (var t in _trimesters) ...[
              for (var s in _sequencesByTrimester[t]!)
                DataColumn(
                  label: Text(
                    'T$t S$s',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              DataColumn(
                label: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Moy. T$t',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            const DataColumn(
              label: Text(
                'Moy. Annuelle',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _subjects.map((subj) {
            final subjData = subjectsData[subj['id']];
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    subj['nom'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(subj['coefficient'].toString())),
                for (var t in _trimesters) ...[
                  for (var s in _sequencesByTrimester[t]!)
                    DataCell(
                      Text(
                        subjData?['trimesters']?[t]?['sequences']?[s]
                                ?.toStringAsFixed(1) ??
                            '-',
                      ),
                    ),
                  DataCell(
                    Text(
                      subjData?['trimesters']?[t]?['moyenne']?.toStringAsFixed(
                            1,
                          ) ??
                          '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
                DataCell(
                  Text(
                    subjData?['moyenne']?.toStringAsFixed(2) ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_studentRankings.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            'Moyenne Classe',
            _classAverage.toStringAsFixed(2),
            Icons.analytics_rounded,
            Colors.blue,
          ),
          _buildStatCard(
            'Taux Réussite',
            '${_successRate.toStringAsFixed(1)}%',
            Icons.trending_up_rounded,
            AppTheme.successColor,
          ),
          _buildStatCard(
            'Admis / Échecs',
            '$_admittedCount / $_failedCount',
            Icons.people_alt_rounded,
            Colors.orange,
          ),
          _buildStatCard(
            'Effectif Total',
            '$_totalStudents (H:$_maleCount, F:$_femaleCount)',
            Icons.school_rounded,
            Colors.purple,
          ),
          _buildStatCard(
            'Réussite H/F',
            'H:${_maleSuccessRate.toStringAsFixed(1)}% / F:${_femaleSuccessRate.toStringAsFixed(1)}%',
            Icons.wc_rounded,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: widget.isDark ? Colors.white60 : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: Column(
        children: [
          _buildTopBar(),
          _buildFilters(),
          if (!_isLoading) _buildStatsSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRankingView(),
          ),
        ],
      ),
    );
  }
}
