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

class _AddScheduleModalState extends State<AddScheduleModal> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedMatiereId;
  int? _selectedEnseignantId;
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final _salleController = TextEditingController();

  List<Matiere> _matieres = [];
  List<Enseignant> _enseignants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _selectedMatiereId = widget.entry!.matiereId;
      _selectedEnseignantId = widget.entry!.enseignantId;
      _selectedDay = widget.entry!.jourSemaine;
      _startTime = _parseTime(widget.entry!.heureDebut);
      _endTime = _parseTime(widget.entry!.heureFin);
      _salleController.text = widget.entry!.salle ?? '';
    }
    _loadData();
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

          // If editing, ensure IDs are still valid
          if (widget.entry != null) {
            if (!_matieres.any((m) => m.id == _selectedMatiereId))
              _selectedMatiereId = null;
            if (!_enseignants.any((e) => e.id == _selectedEnseignantId))
              _selectedEnseignantId = null;
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

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Set end time to +2 hours by default
          if (_endTime.hour < _startTime.hour ||
              (_endTime.hour == _startTime.hour &&
                  _endTime.minute <= _startTime.minute)) {
            _endTime = TimeOfDay(
              hour: (_startTime.hour + 2) % 24,
              minute: _startTime.minute,
            );
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMatiereId == null) {
      _showError('Veuillez sélectionner une matière.');
      return;
    }

    final db = DatabaseHelper.instance;
    final debut = _formatTime(_startTime);
    final fin = _formatTime(_endTime);

    // Conflict check
    final conflicts = await db.checkConflicts(
      _selectedDay,
      debut,
      fin,
      enseignantId: _selectedEnseignantId,
      classeId: widget.classeId,
      excludeId: widget.entry?.id,
    );

    if (conflicts > 0) {
      _showError(
        'Conflit détecté : l\'enseignant ou la classe est déjà occupé(e) à ce créneau.',
      );
      return;
    }

    final entry = EmploiDuTemps(
      id: widget.entry?.id,
      classeId: widget.classeId,
      matiereId: _selectedMatiereId!,
      enseignantId: _selectedEnseignantId,
      jourSemaine: _selectedDay,
      heureDebut: debut,
      heureFin: fin,
      salle: _salleController.text,
      anneeScolaireId: DatabaseHelper.activeAnneeId!,
    );

    try {
      if (widget.entry == null) {
        await db.insert('emploi_du_temps', entry.toMap());
      } else {
        await db.update('emploi_du_temps', entry.toMap(), 'id = ?', [
          widget.entry!.id,
        ]);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Erreur lors de l\'enregistrement: $e');
    }
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
        await DatabaseHelper.instance.delete('emploi_du_temps', 'id = ?', [
          widget.entry!.id,
        ]);
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
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.entry == null
                              ? 'Ajouter un cours'
                              : 'Modifier le cours',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
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
                      ],
                    ),
                    const Divider(height: 32),

                    // Matiere
                    const Text(
                      'Matière',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown<int>(
                      value: _selectedMatiereId,
                      hint: 'Sélectionner une matière',
                      items: _matieres
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.nom),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedMatiereId = val),
                    ),
                    const SizedBox(height: 16),

                    // Enseignant
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enseignant',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => _openTeacherModal(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nouveau'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildDropdown<int>(
                      value: _selectedEnseignantId,
                      hint: 'Sélectionner un enseignant (optionnel)',
                      items: _enseignants
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.nomComplet),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedEnseignantId = val),
                    ),
                    const SizedBox(height: 16),

                    // Jour
                    const Text(
                      'Jour',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown<int>(
                      value: _selectedDay,
                      hint: 'Jour',
                      items: [
                        const DropdownMenuItem(value: 1, child: Text('Lundi')),
                        const DropdownMenuItem(value: 2, child: Text('Mardi')),
                        const DropdownMenuItem(
                          value: 3,
                          child: Text('Mercredi'),
                        ),
                        const DropdownMenuItem(value: 4, child: Text('Jeudi')),
                        const DropdownMenuItem(
                          value: 5,
                          child: Text('Vendredi'),
                        ),
                        const DropdownMenuItem(value: 6, child: Text('Samedi')),
                      ],
                      onChanged: (val) => setState(() => _selectedDay = val!),
                    ),
                    const SizedBox(height: 24),

                    // Temps
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Début',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectTime(context, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatTime(_startTime)),
                                      const Icon(Icons.access_time, size: 20),
                                    ],
                                  ),
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
                              const Text(
                                'Fin',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectTime(context, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatTime(_endTime)),
                                      const Icon(Icons.access_time, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Salle
                    const Text(
                      'Salle',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _salleController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Salle 101, Labo...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.entry == null
                              ? 'Ajouter au planning'
                              : 'Sauvegarder les modifications',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
        ),
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
