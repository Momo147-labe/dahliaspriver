import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../services/pdf/master_schedule_pdf_service.dart';
import '../../../models/emploi_du_temps.dart';
import '../../../widgets/schedule/add_schedule_modal.dart';

int _toInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

class MasterSchedulePage extends StatefulWidget {
  const MasterSchedulePage({super.key});

  @override
  State<MasterSchedulePage> createState() => _MasterSchedulePageState();
}

Map<String, dynamic> _buildMatrixIsolate(List<dynamic> args) {
  final schedule = args[0] as List<Map<String, dynamic>>;

  final Map<int, Map<String, Map<int, Map<String, dynamic>>>> matrix = {};
  final Map<int, Map<String, Map<int, List<int>>>> teacherConflicts = {};

  for (var course in schedule) {
    final jour = _toInt(course['jour_semaine'], 1);
    final timeSlot = '${course['heure_debut']} - ${course['heure_fin']}';
    final classeId = _toInt(course['classe_id']);
    final enseignantId = course['enseignant_id'] != null
        ? _toInt(course['enseignant_id'])
        : null;

    matrix.putIfAbsent(jour, () => {});
    matrix[jour]!.putIfAbsent(timeSlot, () => {});
    matrix[jour]![timeSlot]![classeId] = course;

    if (enseignantId != null) {
      teacherConflicts.putIfAbsent(jour, () => {});
      teacherConflicts[jour]!.putIfAbsent(timeSlot, () => {});
      teacherConflicts[jour]![timeSlot]!.putIfAbsent(enseignantId, () => []);
      teacherConflicts[jour]![timeSlot]![enseignantId]!.add(classeId);
    }
  }

  return {'matrix': matrix, 'conflicts': teacherConflicts};
}

class _MasterSchedulePageState extends State<MasterSchedulePage> {
  bool _isLoading = true;
  bool _hideEmptyClasses = false;
  List<Map<String, dynamic>> _classes = [];

  Map<int, Map<String, Map<int, Map<String, dynamic>>>> _matrix = {};
  Map<int, Map<String, Map<int, List<int>>>> _teacherConflicts = {};

  List<Map<String, dynamic>> get _visibleClasses {
    if (!_hideEmptyClasses) return _classes;
    return _classes.where((c) {
      for (var dayData in _matrix.values) {
        for (var timeSlotData in dayData.values) {
          if (timeSlotData.containsKey(c['id'])) return true;
        }
      }
      return false;
    }).toList();
  }

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

      final result = await compute(_buildMatrixIsolate, [schedule]);

      if (mounted) {
        setState(() {
          _classes = classes;
          _matrix =
              result['matrix']
                  as Map<int, Map<String, Map<int, Map<String, dynamic>>>>;
          _teacherConflicts =
              result['conflicts'] as Map<int, Map<String, Map<int, List<int>>>>;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToToday();
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

  void _openEditModal(Map<String, dynamic> courseData, int classeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleModal(
        classeId: classeId,
        entry: EmploiDuTemps.fromMap(courseData),
        onSuccess: _loadData,
      ),
    );
  }

  void _scrollToToday() {
    if (!_verticalController.hasClients) return;
    final today = DateTime.now().weekday;
    if (today > 7) return;

    double offset = 0.0;
    final cellHeight = 80.0;
    final dayHeaderHeight = 50.0;

    for (int day = 1; day < today; day++) {
      if (!_matrix.containsKey(day)) continue;
      final timeSlots = _matrix[day]!.keys.length;
      offset += 16.0 + dayHeaderHeight + (timeSlots * cellHeight);
    }

    _verticalController.animateTo(
      offset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
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
          Row(
            children: [
              Text(
                'Masquer vides',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch(
                value: _hideEmptyClasses,
                onChanged: (val) => setState(() => _hideEmptyClasses = val),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Préparation du PDF, veuillez patienter...'),
                  ),
                );
                final yearProvider = context.read<AcademicYearProvider>();
                final activeYearLabel =
                    yearProvider.selectedAnnee?['periode'] ?? '2024-2025';
                await MasterSchedulePdfService.generateAndPrint(
                  classes: _visibleClasses,
                  matrix: _matrix,
                  schoolName: 'Dahlias Priver',
                  schoolYear: activeYearLabel,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur PDF: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            tooltip: 'Exporter en PDF',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
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
    final List<Widget> leftRows = [];
    final List<Widget> rightRows = [];
    final cellWidth = 160.0;
    final headerWidth = 140.0;
    final cellHeight = 80.0;
    final dayHeaderHeight = 50.0;

    for (int day = 1; day <= 7; day++) {
      if (!_matrix.containsKey(day)) continue; // Skip empty days

      final timeSlotsMap = _matrix[day]!;
      final timeSlots = timeSlotsMap.keys.toList()
        ..sort(); // Sort chronologically

      // Add Day Header Row spanning the whole table
      // Left side (Day Name)
      leftRows.add(
        Container(
          width: headerWidth,
          height: dayHeaderHeight,
          color: isDark ? Colors.white10 : Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(top: 16),
          alignment: Alignment.centerLeft,
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
      // Right side (Blank continuation of the bar)
      rightRows.add(
        Container(
          width: cellWidth * _visibleClasses.length,
          height: dayHeaderHeight,
          color: isDark ? Colors.white10 : Colors.blue.shade50,
          margin: const EdgeInsets.only(top: 16),
        ),
      );

      // Add rows for each timeslot
      for (var slot in timeSlots) {
        // Left side: Fixed TimeSlot Header
        leftRows.add(
          Container(
            width: headerWidth,
            height: cellHeight,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Symbols.schedule, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // Right side: Class Cells
        rightRows.add(
          Row(
            children: _visibleClasses.map((c) {
              final course = timeSlotsMap[slot]?[c['id']];

              bool hasConflict = false;
              if (course != null && course['enseignant_id'] != null) {
                final profId = _toInt(course['enseignant_id']);
                if (_teacherConflicts[day] != null &&
                    _teacherConflicts[day]![slot] != null &&
                    _teacherConflicts[day]![slot]![profId] != null &&
                    _teacherConflicts[day]![slot]![profId]!.length > 1) {
                  hasConflict = true;
                }
              }

              return Container(
                width: cellWidth,
                height: cellHeight,
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
                child: InkWell(
                  onTap: course != null
                      ? () => _openEditModal(course, _toInt(c['id']))
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCell(course, isDark, hasConflict),
                ),
              );
            }).toList(),
          ),
        );
      }
    }

    if (leftRows.isEmpty) {
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
                color: Colors.black.withValues(alpha: 0.05),
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
                    children: _visibleClasses.map((c) {
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT FIXED COLUMN
                Container(
                  width: headerWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: leftRows,
                  ),
                ),
                // RIGHT SCROLLABLE MATRIX
                Expanded(
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rightRows,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(
    Map<String, dynamic>? course,
    bool isDark,
    bool hasConflict,
  ) {
    if (course == null) {
      return Container(
        color: isDark ? Colors.transparent : Colors.grey.shade50,
      );
    }

    // Default color logic when missing color
    Color subjectColor = AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hasConflict
            ? Colors.red.withValues(alpha: 0.1)
            : subjectColor.withValues(alpha: 0.1),
        border: Border.all(
          color: hasConflict
              ? Colors.red.withValues(alpha: 0.8)
              : subjectColor.withValues(alpha: 0.3),
          width: hasConflict ? 2.0 : 1.0,
        ),
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
              color: subjectColor.withValues(alpha: isDark ? 0.9 : 1.0),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
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
