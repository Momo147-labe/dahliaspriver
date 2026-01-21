import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../core/services/file_service.dart';

class AddStudentModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onStudentAdded;

  const AddStudentModal({Key? key, required this.onStudentAdded})
    : super(key: key);

  @override
  _AddStudentModalState createState() => _AddStudentModalState();
}

class _AddStudentModalState extends State<AddStudentModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final _matriculeController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();
  final _nomPereController = TextEditingController();
  final _nomMereController = TextEditingController();

  // Variables
  String? _selectedSexe;
  int? _selectedClasseId;
  String? _selectedStatut;
  File? _selectedImage;
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadClasses();
    _initializeForm();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  void _initializeForm() {
    _selectedSexe = 'M';
    _selectedStatut = 'inscrit';
  }

  Future<void> _loadClasses() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final classes = await db.query('classe');
      setState(() {
        _classes = classes;
      });
    } catch (e) {
      _showError('Erreur lors du chargement des classes: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        final savedPath = await FileService.instance.saveImage(
          File(pickedFile.path),
          FileService.studentPhotosDir,
        );

        setState(() {
          _selectedImage = File(savedPath);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  void _showImagePicker() {
    _pickImage(ImageSource.gallery);
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClasseId == null) {
      _showError('Veuillez sélectionner une classe');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      // Vérifier si le matricule existe déjà
      final existingStudent = await db.query(
        'eleve',
        where: 'matricule = ?',
        whereArgs: [_matriculeController.text],
      );

      if (existingStudent.isNotEmpty) {
        _showError('Ce matricule existe déjà');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Préparer les données de l'étudiant
      final studentData = {
        'matricule': _matriculeController.text.trim(),
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'date_naissance': _dateNaissanceController.text.trim(),
        'lieu_naissance': _lieuNaissanceController.text.trim(),
        'sexe': _selectedSexe,
        'nom_pere': _nomPereController.text.trim(),
        'nom_mere': _nomMereController.text.trim(),
        'classe_id': _selectedClasseId,
        'statut': _selectedStatut,
        'photo': _selectedImage?.path ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insérer l'étudiant
      final studentId = await db.insert('eleve', studentData);

      // Créer le parcours de l'étudiant
      await db.insert('parcours_eleve', {
        'eleve_id': studentId,
        'classe_id': _selectedClasseId,
        'annee_scolaire_id': DatabaseHelper.activeAnneeId!,
        'type_inscription': 'nouveau',
        'date_inscription': DateTime.now().toIso8601String(),
      });

      setState(() {
        _isLoading = false;
      });

      widget.onStudentAdded(studentData);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Étudiant ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Erreur lors de l\'ajout de l\'étudiant: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _matriculeController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _dateNaissanceController.dispose();
    _lieuNaissanceController.dispose();
    _nomPereController.dispose();
    _nomMereController.dispose();
    super.dispose();
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        height: 150,
        width: 150,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(75),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(75),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 40, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Ajouter photo',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Appuyer pour choisir',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        keyboardType: keyboardType,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ce champ est obligatoire';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
    bool required,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: items,
        onChanged: onChanged,
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Ce champ est obligatoire';
                }
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.person_add,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ajouter un étudiant',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Photo
                  Center(child: _buildPhotoSection()),
                  const SizedBox(height: 24),

                  // Informations personnelles
                  _buildSectionTitle('Informations personnelles'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _matriculeController,
                          'Matricule',
                          'Ex: MAT001',
                          icon: Icons.badge,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          _nomController,
                          'Nom',
                          'Nom de famille',
                          icon: Icons.person,
                          required: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _prenomController,
                          'Prénom',
                          'Prénom',
                          icon: Icons.person,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          _dateNaissanceController,
                          'Date de naissance',
                          'JJ/MM/AAAA',
                          icon: Icons.calendar_today,
                          required: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _lieuNaissanceController,
                          'Lieu de naissance',
                          'Ville de naissance',
                          icon: Icons.location_on,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField(
                          'Sexe',
                          _selectedSexe,
                          [
                            const DropdownMenuItem(
                              value: 'M',
                              child: Text('Masculin'),
                            ),
                            const DropdownMenuItem(
                              value: 'F',
                              child: Text('Féminin'),
                            ),
                          ],
                          (value) => setState(() => _selectedSexe = value),
                          true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Informations des parents
                  _buildSectionTitle('Informations des parents'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _nomPereController,
                          'Nom du père',
                          'Nom complet du père',
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          _nomMereController,
                          'Nom de la mère',
                          'Nom complet de la mère',
                          icon: Icons.person,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Informations scolaires
                  _buildSectionTitle('Informations scolaires'),
                  _buildDropdownField(
                    'Classe',
                    _selectedClasseId?.toString(),
                    _classes
                        .map(
                          (classe) => DropdownMenuItem(
                            value: classe['id'].toString(),
                            child: Text(
                              '${classe['nom']} - ${classe['niveau']}',
                            ),
                          ),
                        )
                        .toList(),
                    (value) => setState(
                      () => _selectedClasseId = int.tryParse(value ?? ''),
                    ),
                    true,
                  ),
                  _buildDropdownField(
                    'Statut',
                    _selectedStatut,
                    [
                      const DropdownMenuItem(
                        value: 'inscrit',
                        child: Text('Inscrit'),
                      ),
                      const DropdownMenuItem(
                        value: 'reinscrit',
                        child: Text('Réinscrit'),
                      ),
                    ],
                    (value) => setState(() => _selectedStatut = value),
                    true,
                  ),

                  const SizedBox(height: 32),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
