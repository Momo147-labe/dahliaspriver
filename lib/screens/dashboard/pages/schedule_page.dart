import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/emploi_du_temps.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/schedule/add_schedule_modal.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  int? _selectedClasseId;
  List<Map<String, dynamic>> _classes = [];
  List<EmploiDuTemps> _scheduleEntries = [];
  bool _isLoading = true;
  late AnimationController _animationController;

  final List<String> _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final classes = await db.queryAll('classe');

      if (mounted) {
        setState(() {
          _classes = classes;
          if (classes.isNotEmpty) {
            _selectedClasseId = classes.first['id'] as int;
          }
          _isLoading = false;
        });
        if (_selectedClasseId != null) {
          _loadSchedule();
        }
      }
    } catch (e) {
      _showError('Erreur lors du chargement des classes: $e');
    }
  }

  Future<void> _loadSchedule() async {
    if (_selectedClasseId == null) return;

    try {
      final db = DatabaseHelper.instance;
      final anneeId = await db.ensureActiveAnneeCached();
      if (anneeId == null) return;

      final entries = await db.getEmploiDuTempsByClasse(
        _selectedClasseId!,
        anneeId,
      );

      if (mounted) {
        setState(() {
          _scheduleEntries = entries
              .map((e) => EmploiDuTemps.fromMap(e))
              .toList();
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      _showError('Erreur lors du chargement de l\'emploi du temps: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  _buildControls(isDark),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _selectedClasseId == null
                        ? _buildNoClassState(isDark)
                        : _buildScheduleGrid(isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emploi du temps',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      Colors.purple.shade600,
                      Colors.pink.shade500,
                    ],
                  ).createShader(const Rect.fromLTWH(0.0, 0.0, 400.0, 70.0)),
              ),
            ),
            Text(
              'Gérez le planning hebdomadaire des cours par classe',
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white70 : Colors.blueGrey.shade600,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openAddModal(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un cours'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Symbols.filter_list, size: 24),
          const SizedBox(width: 16),
          const Text('Classe:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedClasseId,
                items: _classes.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['nom'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedClasseId = val;
                    _loadSchedule();
                  });
                },
              ),
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: () => _loadSchedule(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _days.asMap().entries.map((entry) {
        int index = entry.key + 1; // 1-indexed for jour_semaine
        String day = entry.value;
        return Expanded(child: _buildDayColumn(day, index, isDark));
      }).toList(),
    );
  }

  Widget _buildDayColumn(String day, int dayIndex, bool isDark) {
    final entries = _scheduleEntries
        .where((e) => e.jourSemaine == dayIndex)
        .toList();
    entries.sort((a, b) => a.heureDebut.compareTo(b.heureDebut));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _buildEntryCard(entries[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(EmploiDuTemps entry, bool isDark) {
    return GestureDetector(
      onTap: () => _openEditModal(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.matiereNom ?? 'Matière',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${entry.heureDebut} - ${entry.heureFin}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Symbols.person, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.enseignantNomComplet,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (entry.salle != null && entry.salle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Symbols.room, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    entry.salle!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoClassState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.error, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune classe configurée',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _openAddModal() {
    if (_selectedClasseId == null) {
      _showError('Veuillez sélectionner une classe d\'abord.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleModal(
        classeId: _selectedClasseId!,
        onSuccess: _loadSchedule,
      ),
    );
  }

  void _openEditModal(EmploiDuTemps entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleModal(
        classeId: _selectedClasseId!,
        entry: entry,
        onSuccess: _loadSchedule,
      ),
    );
  }
}
