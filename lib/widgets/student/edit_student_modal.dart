import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/file_service.dart';
import '../../../theme/app_theme.dart';
import '../../../models/student.dart';

class EditStudentModal extends StatefulWidget {
  final Student student;
  final VoidCallback onSuccess;
  final VoidCallback onClose;

  const EditStudentModal({
    super.key,
    required this.student,
    required this.onSuccess,
    required this.onClose,
  });

  @override
  State<EditStudentModal> createState() => _EditStudentModalState();
}

class _EditStudentModalState extends State<EditStudentModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _matriculeController;
  late TextEditingController _dateNaissanceController;
  late TextEditingController _lieuNaissanceController;
  late TextEditingController _personneAPrevenirController;
  late TextEditingController _contactUrgenceController;
  late TextEditingController _nomPereController;
  late TextEditingController _prenomPereController;
  late TextEditingController _nomMereController;
  late TextEditingController _prenomMereController;

  late String _selectedSexe;
  File? _selectedImage;
  File? _tempCapturedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.student.nom);
    _prenomController = TextEditingController(text: widget.student.prenom);
    _matriculeController = TextEditingController(
      text: widget.student.matricule,
    );
    _dateNaissanceController = TextEditingController(
      text: widget.student.dateNaissance,
    );
    _lieuNaissanceController = TextEditingController(
      text: widget.student.lieuNaissance,
    );
    _nomPereController = TextEditingController(text: widget.student.nomPere);
    _prenomPereController = TextEditingController(
      text: widget.student.prenomPere,
    );
    _nomMereController = TextEditingController(text: widget.student.nomMere);
    _prenomMereController = TextEditingController(
      text: widget.student.prenomMere,
    );
    _personneAPrevenirController = TextEditingController(
      text: widget.student.personneAPrevenir,
    );
    _contactUrgenceController = TextEditingController(
      text: widget.student.contactUrgence,
    );
    _selectedSexe = widget.student.sexe;

    if (widget.student.photo.isNotEmpty &&
        File(widget.student.photo).existsSync()) {
      _selectedImage = File(widget.student.photo);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _matriculeController.dispose();
    _dateNaissanceController.dispose();
    _lieuNaissanceController.dispose();
    _personneAPrevenirController.dispose();
    _contactUrgenceController.dispose();
    _nomPereController.dispose();
    _prenomPereController.dispose();
    _nomMereController.dispose();
    _prenomMereController.dispose();
    _tempCapturedImage?.delete().catchError((_) => File(''));
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (image != null) {
        final tempFile = File(image.path);
        setState(() {
          _tempCapturedImage = tempFile;
          _selectedImage = tempFile;
        });
      }
    } catch (e) {
      print('Erreur picking image: $e');
    }
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now().subtract(
      const Duration(days: 365 * 10),
    );
    try {
      if (_dateNaissanceController.text.isNotEmpty) {
        initialDate = DateFormat(
          'yyyy-MM-dd',
        ).parse(_dateNaissanceController.text);
      }
    } catch (e) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryColor,
            ),
          ),
          child: child!,
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

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      String finalPhotoPath =
          widget.student.photo; // Garder l'ancienne par défaut

      if (_tempCapturedImage != null && await _tempCapturedImage!.exists()) {
        // Supprimer définitivement l'ancienne photo
        if (widget.student.photo.isNotEmpty) {
          await FileService.instance.deleteFile(widget.student.photo);
        }

        final ext = '.jpg';
        final fileName = '${_matriculeController.text}$ext';
        finalPhotoPath = await FileService.instance.saveImageWithName(
          _tempCapturedImage!,
          FileService.studentPhotosDir,
          fileName,
        );
        // Supprimer le fichier temporaire d'origine
        await _tempCapturedImage!.delete().catchError((_) => File(''));
        _tempCapturedImage = null;
      }

      final updatedData = {
        'matricule': _matriculeController.text,
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'date_naissance': _dateNaissanceController.text,
        'lieu_naissance': _lieuNaissanceController.text,
        'sexe': _selectedSexe,
        'photo': finalPhotoPath,
        'personne_a_prevenir': _personneAPrevenirController.text.trim(),
        'contact_urgence': _contactUrgenceController.text.trim(),
        'nom_pere': _nomPereController.text.trim(),
        'prenom_pere': _prenomPereController.text.trim(),
        'nom_mere': _nomMereController.text.trim(),
        'prenom_mere': _prenomMereController.text.trim(),
      };

      await db.update(
        'eleve',
        updatedData,
        where: 'id = ?',
        whereArgs: [widget.student.id],
      );

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations de l\'élève mises à jour !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCameraCapture() async {
    // Protection pour Linux (camera non supportée par le plugin Windows/Linux actuel sans config complexe)
    if (Platform.isLinux) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La capture caméra n\'est pas encore supportée sur Linux. Veuillez utiliser la galerie.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune caméra trouvée'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final XFile? capturedFile = await showDialog<XFile>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CameraPreviewModal(cameras: cameras),
      );

      if (capturedFile != null) {
        final tempFile = File(capturedFile.path);
        setState(() {
          _tempCapturedImage = tempFile;
          _selectedImage = tempFile;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo capturée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on CameraException catch (e) {
      String message = 'Erreur caméra : ${e.description}';
      if (e.code == 'cameraNotFound') message = 'Aucune caméra trouvée';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Gestion spécifique du MissingPluginException sur Linux/Web
      String errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') ||
          errorMsg.contains('UnimplementedError')) {
        errorMsg = 'Fonctionnalité caméra non disponible sur cette plateforme.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              offset: const Offset(0, 20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPersonalInfo(),
                      const SizedBox(height: 32),
                      _buildParentsInfo(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modifier Élève',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Mise à jour des informations personnelles',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
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
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              hoverColor: Colors.white.withValues(alpha: 0.2),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            isReadOnly: false,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _personneAPrevenirController,
                            label: 'Personne à prévenir',
                            hintText: 'Ex: Père, Mère...',
                            icon: Icons.person_pin_rounded,
                            isRequired: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _contactUrgenceController,
                            label: 'Contact d\'urgence',
                            hintText: 'Ex: +224...',
                            icon: Icons.phone_android_rounded,
                            isRequired: false,
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
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
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
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
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
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
            _buildPickerBtn(
              icon: Icons.camera_alt,
              label: 'Caméra',
              onTap: _handleCameraCapture,
              isDark: isDark,
              color: Colors.teal,
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
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _handleCameraCapture();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onClose,
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
          const SizedBox(width: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
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
                : const Text(
                    'Enregistrer les modifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    required IconData icon,
    required bool isRequired,
    bool isReadOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${isRequired ? '*' : ''}',
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
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
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
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
          ),
          validator: isRequired
              ? (value) => (value == null || value.isEmpty)
                    ? 'Ce champ est obligatoire'
                    : null
              : null,
        ),
      ],
    );
  }

  Widget _buildParentsInfo() {
    return _buildSection(
      title: 'Informations des Parents',
      icon: Icons.family_restroom,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _nomPereController,
                  label: 'Nom du Père',
                  hintText: 'Nom',
                  icon: Icons.person,
                  isRequired: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _prenomPereController,
                  label: 'Prénom du Père',
                  hintText: 'Prénom',
                  icon: Icons.person_outline,
                  isRequired: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _nomMereController,
                  label: 'Nom de la Mère',
                  hintText: 'Nom',
                  icon: Icons.person,
                  isRequired: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _prenomMereController,
                  label: 'Prénom de la Mère',
                  hintText: 'Prénom',
                  icon: Icons.person_outline,
                  isRequired: false,
                ),
              ),
            ],
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${isRequired ? '*' : ''}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedValue,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.wc_rounded,
              size: 20,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
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
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
          ),
          items: List.generate(
            values.length,
            (i) => DropdownMenuItem(
              value: values[i],
              child: Text(displayValues[i]),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CameraPreviewModal extends StatefulWidget {
  final List<CameraDescription> cameras;

  const _CameraPreviewModal({required this.cameras});

  @override
  State<_CameraPreviewModal> createState() => _CameraPreviewModalState();
}

class _CameraPreviewModalState extends State<_CameraPreviewModal> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Prendre une photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CameraPreview(_controller),
                      ),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 56,
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _isTakingPicture ? null : _takePicture,
                      icon: _isTakingPicture
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera),
                      label: Text(_isTakingPicture ? 'Capture...' : 'Capturer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  Future<void> _takePicture() async {
    try {
      setState(() => _isTakingPicture = true);
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      if (mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la capture : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
    }
  }
}
