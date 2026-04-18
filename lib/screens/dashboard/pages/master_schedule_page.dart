import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/academic_year_provider.dart';

class MasterSchedulePage extends StatefulWidget {
  const MasterSchedulePage({super.key});

  @override
  State<MasterSchedulePage> createState() => _MasterSchedulePageState();
}

class _MasterSchedulePageState extends State<MasterSchedulePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];

  // Structure: _matrix[jour][heure_debut_fin][classe_id] = course
  final Map<int, Map<String, Map<int, Map<String, dynamic>>>> _matrix = {};

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _headerHorizontalController = ScrollController();

  final List<String> _days = [
    '',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(() {
      if (_headerHorizontalController.hasClients) {
        _headerHorizontalController.jumpTo(_horizontalController.offset);
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _headerHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final anneeId = context.read<AcademicYearProvider>().selectedAnneeId;
      if (anneeId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // 1. Charger toutes les classes
      final classes = await db.rawQuery('''
        SELECT c.*, n.nom as niveau_nom 
        FROM classe c 
        LEFT JOIN niveaux n ON c.niveau_id = n.id 
        ORDER BY n.cycle_id ASC, n.id ASC, c.nom ASC
        ''');

      // 2. Charger tout l'emploi du temps de l'année
      final schedule = await db.rawQuery(
        '''
        SELECT edt.*, m.nom as matiere_nom, 
               e.nom as enseignant_nom, e.prenom as enseignant_prenom
        FROM emploi_du_temps edt
        JOIN matiere m ON edt.matiere_id = m.id
        LEFT JOIN enseignant e ON edt.enseignant_id = e.id
        WHERE edt.annee_scolaire_id = ?
        ORDER BY edt.jour_semaine ASC, edt.heure_debut ASC
        ''',
        [anneeId],
      );

      _buildMatrix(schedule);

      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _buildMatrix(List<Map<String, dynamic>> schedule) {
    _matrix.clear();
    for (var course in schedule) {
      final jour = course['jour_semaine'] as int;
      final timeSlot = '${course['heure_debut']} - ${course['heure_fin']}';
      final classeId = course['classe_id'] as int;

      _matrix.putIfAbsent(jour, () => {});
      _matrix[jour]!.putIfAbsent(timeSlot, () => {});
      _matrix[jour]![timeSlot]![classeId] = course;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Planning Global de l\'École',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? _buildEmptyState(isDark)
          : _buildMatrixTable(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.event_busy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune classe ou emploi du temps configuré.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(bool isDark) {
    // Collect all unique timeslots per day
    final List<Widget> rows = [];
    final cellWidth = 160.0;
    final headerWidth = 140.0;

    for (int day = 1; day <= 7; day++) {
      if (!_matrix.containsKey(day)) continue; // Skip empty days

      final timeSlotsMap = _matrix[day]!;
      final timeSlots = timeSlotsMap.keys.toList()
        ..sort(); // Sort chronologically

      // Add Day Header Row spanning the whole table
      rows.add(
        Container(
          width: headerWidth + (cellWidth * _classes.length),
          color: isDark ? Colors.white10 : Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(top: 16),
          child: Text(
            _days[day].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : AppTheme.primaryColor,
              letterSpacing: 2,
            ),
          ),
        ),
      );

      // Add rows for each timeslot
      for (var slot in timeSlots) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fixed TimeSlot Header
              Container(
                width: headerWidth,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    right: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Class Cells
              ..._classes.map((c) {
                final course = timeSlotsMap[slot]?[c['id']];
                return Container(
                  width: cellWidth,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                      right: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: _buildCell(course, isDark),
                );
              }).toList(),
            ],
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Column(
      children: [
        // FIXED HEADER ROW (Classes)
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Top-Left empty corner
              Container(
                width: headerWidth,
                height: 50,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'HORAIRES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              // Scrolling Headers
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHorizontalController,
                  physics:
                      const ClampingScrollPhysics(), // Prevent bounce desync
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _classes.map((c) {
                      return Container(
                        width: cellWidth,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Text(
                          c['nom'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // BODY
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalController,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var r in rows)
                      // Provide an intrinsic height to force children to expand
                      IntrinsicHeight(child: r),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(Map<String, dynamic>? course, bool isDark) {
    if (course == null) {
      return Container(
        color: isDark ? Colors.transparent : Colors.grey.shade50,
      );
    }

    // Default color logic when missing color
    Color subjectColor = AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: subjectColor.withOpacity(0.1),
        border: Border.all(color: subjectColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course['matiere_nom'] ?? 'Matière',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: subjectColor.withOpacity(isDark ? 0.9 : 1.0),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Symbols.person,
                size: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  course['enseignant_nom'] != null
                      ? '${course['enseignant_prenom']} ${course['enseignant_nom']}'
                      : 'Non assigné',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
