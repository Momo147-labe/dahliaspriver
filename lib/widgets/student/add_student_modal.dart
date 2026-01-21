import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/file_service.dart';
import '../../../theme/app_theme.dart';

class AddStudentModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onClose;

  const AddStudentModal({
    super.key,
    required this.onSuccess,
    required this.onClose,
  });

  @override
  State<AddStudentModal> createState() => _AddStudentModalState();
}

class _AddStudentModalState extends State<AddStudentModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();
  final TextEditingController _lieuNaissanceController =
      TextEditingController();
  final TextEditingController _montantPayeController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _anneeScolaireController =
      TextEditingController();

  String _selectedSexe = 'M';
  String _selectedAnneeScolaire = '';
  String _selectedClasse = '';
  String _selectedTypeInscription = 'nouveau';
  String _selectedTypePaiement = 'inscription';
  String _selectedModePaiement = 'especes';
  File? _selectedImage;
  bool _isLoading = false;

  // Données chargées depuis SQLite
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _anneesScolaires = [];
  double _fraisScolariteTotal = 1200.00;
  int?
  _fraisId; // ID des frais de scolarité pour la classe et année sélectionnées

  @override
  void initState() {
    super.initState();
    _loadData();
    // Générer la référence initiale
    _generateReference(_selectedModePaiement).then((ref) {
      if (mounted) {
        setState(() {
          _referenceController.text = ref;
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final activeAnnee = await DatabaseHelper.instance.getActiveAnnee();

      setState(() {
        if (activeAnnee != null) {
          _anneesScolaires = [activeAnnee];
          _selectedAnneeScolaire =
              activeAnnee['libelle']?.toString() ?? '2024-2025';
          _anneeScolaireController.text = _selectedAnneeScolaire;
        }
      });

      // Charger les classes pour l'année scolaire active uniquement
      await _loadClassesForAnnee();

      // Charger les frais de scolarité pour la classe sélectionnée
      _loadFraisScolarite();
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
    }
  }

  Future<void> _loadClassesForAnnee() async {
    if (_selectedAnneeScolaire.isEmpty) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final anneeScolaireId = _getAnneeScolaireId(_selectedAnneeScolaire);

      if (anneeScolaireId == 0) return;

      final classesData = await db.query(
        'classe',
        where: 'annee_scolaire_id = ?',
        whereArgs: [anneeScolaireId],
      );

      setState(() {
        _classes = classesData;
        if (classesData.isNotEmpty && _selectedClasse.isEmpty) {
          _selectedClasse = classesData.first['nom']?.toString() ?? '';
        } else if (classesData.isEmpty) {
          _selectedClasse = '';
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des classes: $e');
    }
  }

  Future<void> _loadFraisScolarite() async {
    if (_selectedClasse.isEmpty || _selectedAnneeScolaire.isEmpty) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final classeId = _getClasseId(_selectedClasse);
      final anneeScolaireId = _getAnneeScolaireId(_selectedAnneeScolaire);

      if (classeId == 0 || anneeScolaireId == 0) return;

      final fraisData = await db.query(
        'frais_scolarite',
        where: 'classe_id = ? AND annee_scolaire_id = ?',
        whereArgs: [classeId, anneeScolaireId],
      );

      if (fraisData.isNotEmpty) {
        setState(() {
          _fraisId = fraisData.first['id'] as int?;
          _fraisScolariteTotal =
              (fraisData.first['montant_total'] as num?)?.toDouble() ?? 0.0;

          // Si le montant total est 0, calculer à partir des tranches
          if (_fraisScolariteTotal == 0) {
            final inscription =
                (fraisData.first['inscription'] as num?)?.toDouble() ?? 0.0;
            final tranche1 =
                (fraisData.first['tranche1'] as num?)?.toDouble() ?? 0.0;
            final tranche2 =
                (fraisData.first['tranche2'] as num?)?.toDouble() ?? 0.0;
            final tranche3 =
                (fraisData.first['tranche3'] as num?)?.toDouble() ?? 0.0;
            _fraisScolariteTotal = inscription + tranche1 + tranche2 + tranche3;
          }
        });
      } else {
        setState(() {
          _fraisId = null;
          _fraisScolariteTotal = 0.0;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des frais: $e');
      setState(() {
        _fraisId = null;
        _fraisScolariteTotal = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _matriculeController.dispose();
    _dateNaissanceController.dispose();
    _lieuNaissanceController.dispose();
    _montantPayeController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        // Sauvegarder l'image localement via FileService
        final String savedPath = await FileService.instance.saveImage(
          File(image.path),
          FileService.studentPhotosDir,
        );

        setState(() => _selectedImage = File(savedPath));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo sélectionnée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 10),
      ), // 10 ans par défaut
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('fr', 'FR'),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                onSurface: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier que la classe et l'année sont sélectionnées
    if (_selectedClasse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une classe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier que les frais sont chargés
    if (_fraisId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun frais de scolarité trouvé pour cette classe et cette année',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final classeId = _getClasseId(_selectedClasse);
      final anneeScolaireId = _getAnneeScolaireId(_selectedAnneeScolaire);

      // Générer matricule automatiquement si non fourni
      if (_matriculeController.text.isEmpty) {
        final year = DateTime.now().year;
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM eleve');
        final studentCount = ((count.first['count'] as int?) ?? 0) + 1;
        _matriculeController.text =
            '$year-STUD-${studentCount.toString().padLeft(4, '0')}';
      }

      // Calculer le montant payé et restant
      final montantPayeText = _montantPayeController.text.trim();
      final montantPaye = montantPayeText.isEmpty
          ? 0.0
          : (double.tryParse(montantPayeText.replaceAll(',', '.')) ?? 0.0);
      final montantRestant = (_fraisScolariteTotal - montantPaye).clamp(
        0.0,
        double.infinity,
      );

      // Générer la référence si elle n'est pas déjà remplie
      if (_referenceController.text.isEmpty) {
        _referenceController.text = await _generateReference(
          _selectedModePaiement,
        );
      }

      // Insérer l'élève avec les champs requis selon le schéma
      final eleveData = {
        'matricule': _matriculeController.text,
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'date_naissance': _dateNaissanceController.text,
        'lieu_naissance': _lieuNaissanceController.text,
        'sexe': _selectedSexe,
        'classe_id': classeId,
        'annee_scolaire_id': anneeScolaireId,
        'frais_id': _fraisId,
        'photo': _selectedImage?.path ?? '',
        'statut': _selectedTypeInscription == 'reinscrit'
            ? 'reinscrit'
            : 'inscrit',
        'created_at': DateTime.now().toIso8601String(),
      };

      final eleveId = await db.insert('eleve', eleveData);

      // Insérer le parcours de l'élève
      await db.insert('eleve_parcours', {
        'eleve_id': eleveId,
        'classe_id': classeId,
        'annee_scolaire_id': anneeScolaireId,
        'type_inscription': _selectedTypeInscription,
        'date_inscription': DateTime.now().toIso8601String(),
      });

      // Insérer le paiement avec le frais_id
      await db.insert('paiement', {
        'eleve_id': eleveId,
        'classe_id': classeId,
        'frais_id': _fraisId,
        'montant_total': _fraisScolariteTotal,
        'montant_paye': montantPaye,
        'montant_restant': montantRestant,
        'mode_paiement': _selectedModePaiement,
        'reference_paiement': _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        'date_paiement': DateTime.now().toIso8601String(),
        'type_paiement': _selectedTypePaiement == 'inscription'
            ? 'inscription'
            : 'reinscription',
        'statut': montantRestant <= 0 ? 'complet' : 'partiel',
        'created_at': DateTime.now().toIso8601String(),
        'annee_scolaire_id': anneeScolaireId,
      });

      // AJOUT: Insérer le premier paiement dans paiement_detail pour le suivi
      if (montantPaye > 0) {
        await db.insert('paiement_detail', {
          'eleve_id': eleveId,
          'montant': montantPaye,
          'date_paiement': DateTime.now().toIso8601String(),
          'mode_paiement': _selectedModePaiement,
          'type_frais': _selectedTypePaiement == 'inscription'
              ? 'inscription'
              : 'reinscription',
          'observation': _referenceController.text.isNotEmpty
              ? 'Paiement initial (${_referenceController.text})'
              : 'Paiement initial à l\'inscription',
          'classe_id': classeId,
          'frais_id': _fraisId,
          'annee_scolaire_id': anneeScolaireId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Élève inscrit avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Générer automatiquement la référence selon le mode de paiement
  Future<String> _generateReference(String modePaiement) async {
    final db = await DatabaseHelper.instance.database;
    final year = DateTime.now().year;

    // Préfixe selon le mode de paiement
    String prefix;
    switch (modePaiement) {
      case 'especes':
        prefix = 'ESP';
        break;
      case 'virement':
        prefix = 'VIR';
        break;
      case 'cheque':
        prefix = 'CHQ';
        break;
      case 'mobile_money':
        prefix = 'MOB';
        break;
      default:
        prefix = 'PAY';
    }

    // Compter les paiements de ce type cette année
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM paiement WHERE mode_paiement = ? AND date_paiement LIKE ?',
      [modePaiement, '$year%'],
    );
    final count = ((countResult.first['count'] as int?) ?? 0) + 1;

    // Format: PREFIX-YYYY-NNNN (ex: ESP-2024-0001)
    return '$prefix-$year-${count.toString().padLeft(4, '0')}';
  }

  int _getClasseId(String classeNom) {
    if (classeNom.isEmpty) return 0;
    try {
      final classe = _classes.firstWhere(
        (c) => c['nom']?.toString() == classeNom,
        orElse: () => {},
      );
      return classe['id'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  int _getAnneeScolaireId(String anneeLibelle) {
    if (anneeLibelle.isEmpty) return 0;
    try {
      final annee = _anneesScolaires.firstWhere(
        (a) => a['libelle']?.toString() == anneeLibelle,
        orElse: () => {},
      );
      return annee['id'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 900),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPersonalInfo(),
                      const SizedBox(height: 32),
                      _buildAcademicInfo(),
                      const SizedBox(height: 32),
                      _buildFinancialInfo(),
                      const SizedBox(height: 40),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E40AF), const Color(0xFF7E22CE)]
              : [const Color(0xFF2563EB), const Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inscription Élève',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Nouveau formulaire d\'admission scolaire',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              hoverColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return _buildSection(
      title: 'Informations Personnelles',
      icon: Icons.person,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildPhotoSection()),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nomController,
                            label: 'Nom',
                            hintText: 'Ex: DUPONT',
                            icon: Icons.person,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _prenomController,
                            label: 'Prénom',
                            hintText: 'Ex: Jean-Luc',
                            icon: Icons.person_outline,
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _matriculeController,
                            label: 'Matricule',
                            hintText: '',
                            icon: Icons.badge,
                            isRequired: false,
                            isReadOnly: true,
                            prefixText: 'Auto',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Sexe',
                            selectedValue: _selectedSexe,
                            values: ['M', 'F'],
                            displayValues: ['Masculin (M)', 'Féminin (F)'],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedSexe = v);
                            },
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDateField()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _lieuNaissanceController,
                            label: 'Lieu de naissance',
                            hintText: 'Ex: Conakry, Guinée',
                            icon: Icons.location_on,
                            isRequired: true,
                          ),
                        ),
                      ],
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

  Widget _buildDateField() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date de naissance *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateNaissanceController,
          readOnly: true,
          onTap: _selectDate,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Sélectionner une date',
            prefixIcon: Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Ce champ est obligatoire';
            try {
              final date = DateFormat('yyyy-MM-dd').parse(value);
              if (date.isAfter(DateTime.now())) return 'Date dans le futur';
            } catch (e) {
              return 'Format invalide';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const Text(
          'Photo de l\'élève',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipOval(
                child: _selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 140,
                        height: 140,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.person_rounded,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildPickerBtn(
              icon: Icons.photo_library,
              label: 'Galerie',
              onTap: () => _pickImage(source: ImageSource.gallery),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPickerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.blue.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    _pickImage(source: ImageSource.gallery);
  }

  Widget _buildAcademicInfo() {
    return _buildSection(
      title: 'Inscription Académique',
      icon: Icons.school,
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _anneeScolaireController,
              label: 'Année Scolaire',
              hintText: '',
              icon: Icons.calendar_today,
              isRequired: false,
              isReadOnly: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdownField(
              label: 'Classe',
              selectedValue: _selectedClasse,
              values: _classes.map((c) => c['nom']?.toString() ?? '').toList(),
              displayValues: _classes
                  .map((c) => c['nom']?.toString() ?? '')
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedClasse = v);
                  _loadFraisScolarite();
                }
              },
              isRequired: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdownField(
              label: 'Type d\'inscription',
              selectedValue: _selectedTypeInscription,
              values: ['nouveau', 'redoublant', 'reinscrit'],
              displayValues: ['Nouveau', 'Redoublant', 'Réinscrit'],
              onChanged: (v) {
                if (v != null) setState(() => _selectedTypeInscription = v);
              },
              isRequired: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildSection(
      title: 'Informations Financières (Paiement Initial)',
      icon: Icons.account_balance_wallet,
      child: Column(
        children: [
          // Affichage des frais de scolarité
          if (_fraisId == null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: const Text(
                      'Veuillez sélectionner une classe pour afficher les frais.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E3A8A).withOpacity(0.3),
                          const Color(0xFF1E40AF).withOpacity(0.3),
                        ]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.shade100,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frais de Scolarité Total',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_fraisScolariteTotal.toStringAsFixed(0)} GNF',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                '$_selectedClasse',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Champs de paiement
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _montantPayeController,
                  label: 'Montant Payé',
                  hintText: '0.00',
                  icon: Icons.euro,
                  isRequired: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: 'GNF ',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildMontantRestantField()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Type de paiement',
                  selectedValue: _selectedTypePaiement,
                  values: ['inscription', 'reinscription'],
                  displayValues: ['Inscription', 'Réinscription'],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedTypePaiement = v);
                  },
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Mode de paiement',
                  selectedValue: _selectedModePaiement,
                  values: ['especes', 'virement', 'cheque', 'mobile_money'],
                  displayValues: [
                    'Espèces',
                    'Virement bancaire',
                    'Chèque',
                    'Mobile Money',
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      setState(() => _selectedModePaiement = v);
                      // Générer automatiquement la référence
                      final reference = await _generateReference(v);
                      setState(() {
                        _referenceController.text = reference;
                      });
                    }
                  },
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _referenceController,
            label: 'Référence Transaction',
            hintText: 'Générée automatiquement',
            icon: Icons.qr_code,
            isRequired: false,
            isReadOnly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: isDark ? Colors.white70 : Colors.blueGrey,
          ),
          child: const Text(
            'Annuler',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Finaliser l\'Inscription',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }

  Widget _buildMontantRestantField() {
    final montantPayeText = _montantPayeController.text.trim();
    final montantPaye = montantPayeText.isEmpty
        ? 0.0
        : (double.tryParse(montantPayeText.replaceAll(',', '.')) ?? 0.0);

    final montantRestant = (_fraisScolariteTotal - montantPaye).clamp(
      0.0,
      double.infinity,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant Restant',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          readOnly: true,
          controller: TextEditingController(
            text: montantRestant.toStringAsFixed(0),
          ),
          style: TextStyle(
            color: montantRestant > 0
                ? Colors.orange.shade700
                : Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.account_balance_rounded,
              size: 20,
              color: (montantRestant > 0 ? Colors.orange : Colors.green)
                  .withOpacity(0.7),
            ),
            prefixText: 'GNF ',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: montantRestant > 0 ? Colors.orange : Colors.green,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    required IconData icon,
    required bool isRequired,
    bool isReadOnly = false,
    TextInputType? keyboardType,
    TextStyle? style,
    String? prefixText,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType ?? TextInputType.text,
          style:
              style ??
              TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
          maxLines: maxLines,
          onChanged: (_) {
            if (mounted) setState(() {});
          },
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
            prefixText: prefixText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isReadOnly
                ? (isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.grey.shade100)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Ce champ est obligatoire';
            }
            if (label.toLowerCase().contains('montant payé')) {
              if (value != null && value.isNotEmpty) {
                final montant = double.tryParse(value);
                if (montant == null) return 'Montant invalide';
                if (montant < 0) return 'Le montant ne peut pas être négatif';
                if (montant > _fraisScolariteTotal) {
                  return 'Dépasse le total (${_fraisScolariteTotal.toStringAsFixed(0)} GNF)';
                }
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String selectedValue,
    required List<String> values,
    required List<String> displayValues,
    required ValueChanged<String?> onChanged,
    required bool isRequired,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedValue.isNotEmpty ? selectedValue : null,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.arrow_drop_down_circle_rounded,
              size: 20,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          ),
          dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          items: values.asMap().entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Text(
                displayValues[entry.key],
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black87,
                ),
              ),
            );
          }).toList(),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty))
              return 'Ce champ est obligatoire';
            return null;
          },
        ),
      ],
    );
  }
}
