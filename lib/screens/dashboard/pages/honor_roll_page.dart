import 'dart:io' as io;

import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/pdf/diploma_pdf_service.dart';

class HonorRollPage extends StatefulWidget {
  final bool isDark;

  const HonorRollPage({super.key, required this.isDark});

  @override
  State<HonorRollPage> createState() => _HonorRollPageState();
}

class _HonorRollPageState extends State<HonorRollPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _annees = [];
  int? _selectedAnneeId;

  // List of { 'class_name': String, 'top3': List<Map> }
  List<Map<String, dynamic>> _top3ByClass = [];

  @override
  void initState() {
    super.initState();
    _loadAnnees();
  }

  Future<void> _loadAnnees() async {
    try {
      final db = await _dbHelper.database;
      final anneesRows = await db.query(
        'annee_scolaire',
        orderBy: 'date_debut DESC',
      );
      final annees = List<Map<String, dynamic>>.from(anneesRows);

      final activeAnnee = await _dbHelper.getActiveAnnee();

      if (mounted) {
        setState(() {
          _annees = annees;
          if (_annees.isNotEmpty) {
            _selectedAnneeId = activeAnnee?['id'] ?? _annees.first['id'] as int;
            _loadDataForSelectedAnnee();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDataForSelectedAnnee() async {
    if (_selectedAnneeId == null) return;
    setState(() {
      _isLoading = true;
      _top3ByClass = [];
    });

    try {
      final classes = await _dbHelper.classeDao.getClassesByAnnee(
        _selectedAnneeId!,
      );
      List<Map<String, dynamic>> results = [];

      for (var c in classes) {
        int classId = c['id'] as int;
        String classNom = c['nom'] as String;
        final classWithCycle = await _dbHelper.classeDao.getClasseWithCycle(
          classId,
        );
        final noteMax =
            (classWithCycle?['note_max'] as num?)?.toDouble() ?? 20.0;

        final rawData = await _dbHelper.getClassGradesData(
          _selectedAnneeId!,
          classId,
        );

        Map<int, Map<String, dynamic>> studentsMap = {};
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
              'lieu_naissance': row['lieu_naissance'],
              'sexe': row['sexe'],
              'subjects': <int, Map<String, dynamic>>{},
              'moyenne_generale': 0.0,
            };
          }

          final matiereId = row['matiere_id'] as int?;
          if (matiereId != null) {
            if (!subjectsMap.containsKey(matiereId)) {
              subjectsMap[matiereId] = {
                'id': matiereId,
                'coefficient': (row['coefficient'] as num).toDouble(),
              };
            }

            final subjectMap =
                studentsMap[eleveId]!['subjects']
                    as Map<int, Map<String, dynamic>>;
            if (!subjectMap.containsKey(matiereId)) {
              subjectMap[matiereId] = {
                'trimesters': <int, Map<String, dynamic>>{},
              };
            }

            final trimester = row['trimestre'] as int?;
            if (trimester != null) {
              final trimMap =
                  subjectMap[matiereId]!['trimesters']
                      as Map<int, Map<String, dynamic>>;
              if (!trimMap.containsKey(trimester)) {
                trimMap[trimester] = {'sequences': <int, double>{}};
              }

              final sequence = row['sequence'] as int?;
              final noteValue = row['note'];
              if (sequence != null && noteValue != null) {
                (trimMap[trimester]!['sequences']
                    as Map<int, double>)[sequence] = (noteValue as num)
                    .toDouble();
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
                final trimAvg =
                    seqs.values.reduce((a, b) => a + b) / seqs.length;
                sumTrimesterAverages += trimAvg;
                trimestersCount++;
              }
            }

            double finalSubjectAvg = 0.0;
            if (trimestersCount > 0) {
              finalSubjectAvg = sumTrimesterAverages / trimestersCount;
              final coeff = subjectsMap[matiereId]!['coefficient'] as double;
              sumSubjectAveragesWeighted += (finalSubjectAvg * coeff);
              sumCoefficients += coeff;
            }
          }

          if (sumCoefficients > 0) {
            s['moyenne_generale'] =
                sumSubjectAveragesWeighted / sumCoefficients;
          }
        }

        List<Map<String, dynamic>> rankings = studentsMap.values.toList();
        // Sort descending
        rankings.sort((a, b) {
          final avgA = a['moyenne_generale'] as double;
          final avgB = b['moyenne_generale'] as double;
          return avgB.compareTo(avgA); // descending
        });

        // Compute rank (handling ties)
        int currentRank = 1;
        for (int i = 0; i < rankings.length; i++) {
          if (i > 0 &&
              (rankings[i]['moyenne_generale'] as double) ==
                  (rankings[i - 1]['moyenne_generale'] as double)) {
            rankings[i]['rang'] = rankings[i - 1]['rang'];
          } else {
            rankings[i]['rang'] = currentRank;
          }
          currentRank++;
        }

        // Take top 3
        List<Map<String, dynamic>> top3 = [];
        for (var s in rankings) {
          if (s['rang'] <= 3) {
            top3.add(s);
          } else if (top3.length >= 3 && s['rang'] > 3) {
            // Because of ties, top3 list might be larger than 3 (e.g. two 3rd places),
            // but we stop as soon as we drop below 3rd rank if we already have 3 people.
            break;
          }
        }

        if (top3.isNotEmpty) {
          results.add({
            'class_nom': classNom,
            'top3': top3,
            'note_max': noteMax,
          });
        }
      }

      if (mounted) {
        setState(() {
          _top3ByClass = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _top3ByClass.isEmpty
                ? Center(
                    child: Text(
                      'Aucune donnée pour cette année.',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
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
                    'Tableau d\'Honneur',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Les 3 premiers de chaque classe',
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
            value: _selectedAnneeId,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            dropdownColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
            items: _annees.map((a) {
              return DropdownMenuItem<int>(
                value: a['id'] as int,
                child: Text(
                  a['libelle'].toString(),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedAnneeId = val);
                _loadDataForSelectedAnnee();
              }
            },
            icon: Icon(
              Icons.calendar_today_rounded,
              color: widget.isDark ? Colors.white54 : Colors.black54,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _top3ByClass.length,
      itemBuilder: (context, index) {
        final classeData = _top3ByClass[index];
        final classNom = classeData['class_nom'] as String;
        final top3 = classeData['top3'] as List<Map<String, dynamic>>;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, 4),
                blurRadius: 15,
              ),
            ],
            border: widget.isDark ? Border.all(color: Colors.white12) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Text(
                  classNom,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 600;
                    if (isMobile) {
                      return Column(
                        children: top3
                            .map(
                              (s) => _buildStudentCard(
                                s,
                                isMobile: true,
                                className: classNom,
                                noteMax:
                                    (classeData['note_max'] as num?)
                                        ?.toDouble() ??
                                    20.0,
                              ),
                            )
                            .toList(),
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: top3
                            .map(
                              (s) => Expanded(
                                child: _buildStudentCard(
                                  s,
                                  className: classNom,
                                  noteMax:
                                      (classeData['note_max'] as num?)
                                          ?.toDouble() ??
                                      20.0,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student, {
    bool isMobile = false,
    required String className,
    required double noteMax,
  }) {
    final rang = student['rang'] as int;
    final fullName = '${student['nom']} ${student['prenom']}';
    final photo = student['photo'] as String?;
    final avg = (student['moyenne_generale'] as double).toStringAsFixed(2);

    final matricule = student['matricule']?.toString() ?? 'N/A';
    final dateNais = student['date_naissance']?.toString() ?? '';
    final lieuNais = student['lieu_naissance']?.toString() ?? '';
    final sexe = student['sexe']?.toString() ?? 'M';

    List<Color> gradientColors;
    Color badgeColor;
    IconData badgeIcon;

    switch (rang) {
      case 1:
        badgeColor = const Color(0xFFFFD700); // Gold
        gradientColors = [const Color(0xFFFFF7CC), const Color(0xFFFFEBB2)];
        badgeIcon = Icons.emoji_events_rounded;
        break;
      case 2:
        badgeColor = const Color(0xFF9E9E9E); // Silver
        gradientColors = [const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)];
        badgeIcon = Icons.military_tech_rounded;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        gradientColors = [const Color(0xFFFDF0E6), const Color(0xFFF6D6BD)];
        badgeIcon = Icons.military_tech_rounded;
        break;
      default:
        badgeColor = Colors.blueGrey;
        gradientColors = [Colors.grey[100]!, Colors.grey[200]!];
        badgeIcon = Icons.star_rounded;
        break;
    }

    if (widget.isDark) {
      gradientColors = [
        AppTheme.surfaceDark,
        AppTheme.surfaceDark.withValues(alpha: 0.9),
      ];
    }

    String naisInfo = '';
    if (dateNais.isNotEmpty) {
      naisInfo = 'Né(e) le $dateNais';
      if (lieuNais.isNotEmpty) {
        naisInfo += ' à $lieuNais';
      }
    }

    Widget content = Container(
      margin: EdgeInsets.only(
        right: isMobile ? 0 : 16,
        bottom: isMobile ? 16 : 0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.2),
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
        border: Border.all(
          color: widget.isDark
              ? badgeColor.withValues(alpha: 0.3)
              : Colors.white,
          width: 2,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Absolute Badge
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(badgeIcon, color: badgeColor, size: 32),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Rank
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rang == 1 ? '1er du Classement' : '${rang}ème Place',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 3),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: widget.isDark
                      ? Colors.grey[800]
                      : Colors.white,
                  backgroundImage: photo != null && photo.isNotEmpty
                      ? (photo.startsWith('/') || photo.contains(':\\')
                            ? FileImage(io.File(photo)) as ImageProvider
                            : AssetImage(photo))
                      : null,
                  child: (photo == null || photo.isEmpty)
                      ? Icon(
                          sexe == 'F' ? Icons.face_3 : Icons.face,
                          size: 40,
                          color: badgeColor,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                fullName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              // Matricule
              Text(
                'Matricule: $matricule',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              // Date/Lieu de naissance
              if (naisInfo.isNotEmpty)
                Text(
                  naisInfo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 16),
              // Average Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppTheme.cardDark
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark ? Colors.white12 : Colors.white,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Moyenne Générale',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$avg / ${noteMax.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                        shadows: [
                          Shadow(
                            color: badgeColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Export Button
          Positioned(
            bottom: -10,
            right: -10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final currentAnnee = _annees.firstWhere(
                    (a) => a['id'] == _selectedAnneeId,
                    orElse: () => {'libelle': '...'},
                  )['libelle'];

                  await DiplomaPdfService.generateDiploma(
                    studentData: student,
                    anneeScolaire: currentAnnee,
                    classeNom: className,
                    noteMax: noteMax,
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: badgeColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return content;
  }
}
