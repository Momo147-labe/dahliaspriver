import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/emploi_du_temps.dart';
import '../../models/enseignant.dart';
import '../../models/matiere.dart';
import '../../theme/app_theme.dart';
import '../teacher/teacher_modal.dart';

class AddScheduleModal extends StatefulWidget {
  final int classeId;
  final EmploiDuTemps? entry;
  final VoidCallback onSuccess;

  const AddScheduleModal({
    super.key,
    required this.classeId,
    this.entry,
    required this.onSuccess,
  });

  @override
  State<AddScheduleModal> createState() => _AddScheduleModalState();
}

class _ScheduleEntryFormData {
  int? matiereId;
  int? enseignantId;
  int day;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _ScheduleEntryFormData({
    this.matiereId,
    this.enseignantId,
    this.day = 1,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 10, minute: 0),
  });

  void dispose() {}
}

class _AddScheduleModalState extends State<AddScheduleModal> {
  final _formKey = GlobalKey<FormState>();

  final List<_ScheduleEntryFormData> _entries = [];

  List<Matiere> _matieres = [];
  List<Enseignant> _enseignants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _entries.add(
        _ScheduleEntryFormData(
          matiereId: widget.entry!.matiereId,
          enseignantId: widget.entry!.enseignantId,
          day: widget.entry!.jourSemaine,
          startTime: _parseTime(widget.entry!.heureDebut),
          endTime: _parseTime(widget.entry!.heureFin),
        ),
      );
    } else {
      _entries.add(_ScheduleEntryFormData());
    }
    _loadData();
  }

  @override
  void dispose() {
    for (var entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final anneeId = await db.ensureActiveAnneeCached();
      final matieres = await db.getMatieresByAnnee(anneeId!);
      final enseignantsData = await db.getEnseignants();

      if (mounted) {
        setState(() {
          _matieres = matieres;
          _enseignants = enseignantsData
              .map((e) => Enseignant.fromMap(e))
              .toList();
          _isLoading = false;

          // Valider les IDs pour chaque entrée
          for (var entry in _entries) {
            if (!_matieres.any((m) => m.id == entry.matiereId)) {
              entry.matiereId = null;
            }
            if (!_enseignants.any((e) => e.id == entry.enseignantId)) {
              entry.enseignantId = null;
            }
          }
        });
      }
    } catch (e) {
      _showError('Erreur lors du chargement des données: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    _ScheduleEntryFormData entry,
    bool isStart,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? entry.startTime : entry.endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          entry.startTime = picked;
          // Set end time to +2 hours by default if invalid
          if (entry.endTime.hour < entry.startTime.hour ||
              (entry.endTime.hour == entry.startTime.hour &&
                  entry.endTime.minute <= entry.startTime.minute)) {
            entry.endTime = TimeOfDay(
              hour: (entry.startTime.hour + 2) % 24,
              minute: entry.startTime.minute,
            );
          }
        } else {
          entry.endTime = picked;
        }
      });
    }
  }

  void _addEntry() {
    setState(() {
      _entries.add(_ScheduleEntryFormData());
    });
  }

  void _removeEntry(int index) {
    if (_entries.length <= 1) return;
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  void _duplicateEntry(int index) {
    final original = _entries[index];
    setState(() {
      _entries.add(
        _ScheduleEntryFormData(
          matiereId: original.matiereId,
          enseignantId: original.enseignantId,
          day: original.day,
          startTime: original.startTime,
          endTime: original.endTime,
        ),
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation rapide
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].matiereId == null) {
        _showError(
          'Veuillez sélectionner une matière pour le créneau #${i + 1}.',
        );
        return;
      }
    }

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    try {
      await db.transaction((txn) async {
        for (var entryData in _entries) {
          final debut = _formatTime(entryData.startTime);
          final fin = _formatTime(entryData.endTime);

          // Conflict check
          final conflicts = await dbHelper.timetableDao.checkConflicts(
            entryData.day,
            debut,
            fin,
            enseignantId: entryData.enseignantId,
            classeId: widget.classeId,
            excludeId: widget.entry?.id,
            txn: txn,
          );

          if (conflicts > 0) {
            throw Exception(
              'Conflit détecté le ${_getDayName(entryData.day)} à $debut : l\'enseignant ou la classe est déjà occupé(e).',
            );
          }

          final entry = EmploiDuTemps(
            id: widget.entry?.id,
            classeId: widget.classeId,
            matiereId: entryData.matiereId!,
            enseignantId: entryData.enseignantId,
            jourSemaine: entryData.day,
            heureDebut: debut,
            heureFin: fin,
            anneeScolaireId: DatabaseHelper.activeAnneeId!,
          );

          if (widget.entry == null) {
            await txn.insert('emploi_du_temps', entry.toMap());
          } else {
            await txn.update(
              'emploi_du_temps',
              {
                ...entry.toMap(),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [widget.entry!.id!],
            );
          }
        }
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(
        'Erreur lors de l\'enregistrement: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  String _getDayName(int day) {
    const days = [
      '',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return days[day];
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer ce cours ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.timetableDao.deleteTimetableEntry(
          widget.entry!.id!,
        );
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showError('Erreur lors de la suppression: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.entry == null
                            ? 'Emploi du temps'
                            : 'Modifier le cours',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.entry == null)
                            FilledButton.icon(
                              onPressed: _addEntry,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Ajouter'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          if (widget.entry != null)
                            IconButton(
                              onPressed: _delete,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  Expanded(
                    child: ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 24),
                      itemBuilder: (context, index) => _buildEntryItem(index),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.entry == null
                            ? 'Enregistrer tout le planning'
                            : 'Sauvegarder les modifications',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (widget.entry != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Supprimer ce cours',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryItem(int index) {
    final entryData = _entries[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Créneau #${index + 1}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _duplicateEntry(index),
                    icon: Icon(
                      Icons.copy_all_outlined,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    tooltip: 'Dupliquer ce créneau',
                  ),
                  if (widget.entry == null && _entries.length > 1)
                    IconButton(
                      onPressed: () => _removeEntry(index),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Matiere & Enseignant
          Row(
            children: [
              Expanded(child: _buildFieldLabel('Matière', true)),
              const SizedBox(width: 16),
              Expanded(child: _buildFieldLabel('Enseignant', false)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdown<int>(
                  value: entryData.matiereId,
                  hint: 'Matière',
                  items: _matieres
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.nom)),
                      )
                      .toList(),
                  onChanged: (val) async {
                    setState(() => entryData.matiereId = val);
                    if (val != null) {
                      final teacherRecord = await DatabaseHelper
                          .instance
                          .enseignantDao
                          .getAssignedTeacher(widget.classeId, val);
                      if (teacherRecord != null && mounted) {
                        setState(() {
                          entryData.enseignantId = teacherRecord['id'] as int;
                        });
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown<int>(
                  value: entryData.enseignantId,
                  hint: 'Enseignant',
                  items: _enseignants
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.nomComplet),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => entryData.enseignantId = val),
                  onActionPressed: _openTeacherModal,
                  actionIcon: Icons.person_add_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Jour & Salle
          // Jour
          _buildFieldLabel('Jour', true),
          const SizedBox(height: 8),
          _buildDropdown<int>(
            value: entryData.day,
            hint: 'Jour',
            items: [
              const DropdownMenuItem(value: 1, child: Text('Lundi')),
              const DropdownMenuItem(value: 2, child: Text('Mardi')),
              const DropdownMenuItem(value: 3, child: Text('Mercredi')),
              const DropdownMenuItem(value: 4, child: Text('Jeudi')),
              const DropdownMenuItem(value: 5, child: Text('Vendredi')),
              const DropdownMenuItem(value: 6, child: Text('Samedi')),
            ],
            onChanged: (val) => setState(() => entryData.day = val!),
          ),
          const SizedBox(height: 16),

          // Heures
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Début', true),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectTime(context, entryData, true),
                      child: _buildTimeDisplay(
                        _formatTime(entryData.startTime),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Fin', true),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectTime(context, entryData, false),
                      child: _buildTimeDisplay(_formatTime(entryData.endTime)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool required) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: 13,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(time), const Icon(Icons.access_time, size: 20)],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    VoidCallback? onActionPressed,
    IconData? actionIcon,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                hint: Text(
                  hint,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                items: items,
                onChanged: onChanged,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : Colors.white,
              ),
            ),
          ),
          if (onActionPressed != null && actionIcon != null)
            IconButton(
              icon: Icon(actionIcon, size: 20, color: AppTheme.primaryColor),
              onPressed: onActionPressed,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  void _openTeacherModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherModal(onSuccess: _loadData),
    );
  }
}
