import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  final _matriculeController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  String? _selectedSexe;
  String _typeRemuneration = 'Fixe';
  final _salaireBaseController = TextEditingController(text: '0');
  bool _isSaving = false;

  // Autocomplete data
  List<String> _prenomsSuggestions = [];
  List<String> _nomsSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadAutocompleteData();
    if (widget.teacher != null) {
      _nomController.text = widget.teacher!.nom;
      _prenomController.text = widget.teacher!.prenom;
      _matriculeController.text = widget.teacher!.matricule ?? '';
      _telephoneController.text = widget.teacher!.telephone ?? '';
      _emailController.text = widget.teacher!.email ?? '';
      _selectedSpecialty = widget.teacher!.specialite;
      _photoController.text = widget.teacher!.photo ?? '';
      _dateNaissanceController.text = widget.teacher!.dateNaissance ?? '';
      _selectedSexe = widget.teacher!.sexe;
      _typeRemuneration = widget.teacher!.typeRemuneration ?? 'Fixe';
      _salaireBaseController.text = (widget.teacher!.salaireBase ?? 0)
          .toString();
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

  Future<void> _loadAutocompleteData() async {
    try {
      final String prenomsJson = await rootBundle.loadString(
        'assets/prenoms_guinee.json',
      );
      final String nomsJson = await rootBundle.loadString(
        'assets/ListeNomFamilles.json',
      );

      final prenomsData = json.decode(prenomsJson);
      final nomsData = json.decode(nomsJson);

      if (mounted) {
        setState(() {
          _prenomsSuggestions = List<String>.from(
            prenomsData['prenoms_guinee'] ?? [],
          );
          _nomsSuggestions = List<String>.from(
            nomsData['noms_famille_guinee'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des autocomplétions: $e');
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _photoController.dispose();
    _matriculeController.dispose();
    _dateNaissanceController.dispose();
    _salaireBaseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String matricule = _matriculeController.text.trim();

    if (widget.teacher == null && matricule.isEmpty) {
      final yearStr = DateTime.now().year.toString().substring(2);
      final nom = _nomController.text.trim().toUpperCase();
      final prenom = _prenomController.text.trim().toUpperCase();

      final nomPart = nom.length >= 2
          ? nom.substring(0, 2)
          : nom.padRight(2, 'X');
      final prenomPart = prenom.length >= 2
          ? prenom.substring(0, 2)
          : prenom.padRight(2, 'X');

      final randomValue = Random().nextInt(9000) + 1000;
      matricule = 'ENS$yearStr-$nomPart$prenomPart-$randomValue';
    }

    final teacher = Enseignant(
      id: widget.teacher?.id,
      matricule: matricule,
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: _telephoneController.text.trim(),
      email: _emailController.text.trim(),
      specialite: _selectedSpecialty,
      sexe: _selectedSexe,
      photo: _photoController.text.trim(),
      dateNaissance: _dateNaissanceController.text.trim(),
      typeRemuneration: _typeRemuneration,
      salaireBase: double.tryParse(_salaireBaseController.text) ?? 0,
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
              _buildTextField(
                controller: _matriculeController,
                label: 'Matricule',
                hint: 'Laisser vide pour génération automatique',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAutocompleteField(
                      controller: _prenomController,
                      label: 'Prénom',
                      hintText: 'Ex: Jean',
                      icon: Icons.person_outline,
                      isRequired: true,
                      suggestions: _prenomsSuggestions,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAutocompleteField(
                      controller: _nomController,
                      label: 'Nom',
                      hintText: 'Ex: Dupont',
                      icon: Icons.person,
                      isRequired: true,
                      suggestions: _nomsSuggestions,
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Paramètres de Rémunération',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Type de Salaire',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _typeRemuneration,
                          items: const [
                            DropdownMenuItem(
                              value: 'Fixe',
                              child: Text('Mensuel Fixe'),
                            ),
                            DropdownMenuItem(
                              value: 'Horaire',
                              child: Text('Taux Horaire'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _typeRemuneration = val!),
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
                    child: _buildTextField(
                      controller: _salaireBaseController,
                      label: _typeRemuneration == 'Fixe'
                          ? 'Salaire Mensuel'
                          : 'Taux Horaire',
                      hint: 'Ex: 50000',
                      keyboardType: TextInputType.number,
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
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
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, color: AppTheme.primaryColor)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
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

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? icon,
    required bool isRequired,
    required List<String> suggestions,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return suggestions.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (mounted) setState(() {});
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: textController,
              focusNode: focusNode,
              onFieldSubmitted: (value) => onFieldSubmitted(),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: icon != null
                    ? Icon(
                        icon,
                        size: 20,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              validator: (value) {
                if (isRequired && (value == null || value.isEmpty)) {
                  return 'Requis';
                }
                return null;
              },
            ),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            child: Container(
              width: 250,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: () => onSelected(option),
                    hoverColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
