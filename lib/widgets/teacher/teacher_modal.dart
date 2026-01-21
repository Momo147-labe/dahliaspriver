import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/enseignant.dart';
import '../../theme/app_theme.dart';

class TeacherModal extends StatefulWidget {
  final Enseignant? teacher;
  final VoidCallback onSuccess;

  const TeacherModal({super.key, this.teacher, required this.onSuccess});

  @override
  State<TeacherModal> createState() => _TeacherModalState();
}

class _TeacherModalState extends State<TeacherModal> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedSpecialty;
  List<String> _specialtyOptions = [];
  final _photoController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  String? _selectedSexe;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.teacher != null) {
      _nomController.text = widget.teacher!.nom;
      _prenomController.text = widget.teacher!.prenom;
      _telephoneController.text = widget.teacher!.telephone ?? '';
      _emailController.text = widget.teacher!.email ?? '';
      _selectedSpecialty = widget.teacher!.specialite;
      _photoController.text = widget.teacher!.photo ?? '';
      _dateNaissanceController.text = widget.teacher!.dateNaissance ?? '';
      _selectedSexe = widget.teacher!.sexe;
    }
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await DatabaseHelper.instance.getAllSubjects();
      setState(() {
        _specialtyOptions = [
          'Niveau primaire',
          'Niveau maternelle',
          ...subjects.map((s) => s['nom'] as String),
        ];

        // Ensure _selectedSpecialty is in the list or null
        if (_selectedSpecialty != null &&
            !_specialtyOptions.contains(_selectedSpecialty)) {
          // If it's a legacy value not in the list, we might want to keep it or add it
          _specialtyOptions.insert(0, _selectedSpecialty!);
        }
      });
    } catch (e) {
      debugPrint('Error loading subjects for teacher specialty: $e');
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _photoController.dispose();
    _dateNaissanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final teacher = Enseignant(
      id: widget.teacher?.id,
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: _telephoneController.text.trim(),
      email: _emailController.text.trim(),
      specialite: _selectedSpecialty,
      sexe: _selectedSexe,
      photo: _photoController.text.trim(),
      dateNaissance: _dateNaissanceController.text.trim(),
    );

    try {
      final db = DatabaseHelper.instance;
      if (widget.teacher == null) {
        await db.insert('enseignant', teacher.toMap());
      } else {
        await db.update('enseignant', teacher.toMap(), 'id = ?', [
          widget.teacher!.id,
        ]);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.teacher == null
                    ? 'Ajouter un enseignant'
                    : 'Modifier l\'enseignant',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _prenomController,
                      label: 'Prénom',
                      hint: 'Ex: Jean',
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _nomController,
                      label: 'Nom',
                      hint: 'Ex: Dupont',
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sexe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedSexe,
                          items: const [
                            DropdownMenuItem(
                              value: 'M',
                              child: Text('Masculin'),
                            ),
                            DropdownMenuItem(
                              value: 'F',
                              child: Text('Féminin'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedSexe = val),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _dateNaissanceController,
                          label: 'Date de naissance',
                          hint: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spécialité / Matière principale',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSpecialty,
                    items: _specialtyOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedSpecialty = val),
                    decoration: InputDecoration(
                      hintText: 'Sélectionner une spécialité',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Requis' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _telephoneController,
                label: 'Téléphone',
                hint: 'Numéro de contact',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'adresse@ecole.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.teacher == null
                              ? 'Enregistrer'
                              : 'Sauvegarder',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
