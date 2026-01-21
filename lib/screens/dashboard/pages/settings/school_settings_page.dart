import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/file_service.dart';
import '../../../../models/ecole.dart';
import '../../../../theme/app_theme.dart';

class SchoolSettingsPage extends StatefulWidget {
  const SchoolSettingsPage({super.key});

  @override
  State<SchoolSettingsPage> createState() => _SchoolSettingsPageState();
}

class _SchoolSettingsPageState extends State<SchoolSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _directorController = TextEditingController();
  final _founderController = TextEditingController();

  String? _logoPath;
  String? _timbrePath;
  Ecole? _currentEcole;
  bool _isLoading = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEcoleData();
  }

  Future<void> _loadEcoleData() async {
    setState(() => _isLoading = true);
    try {
      final ecole = await DatabaseHelper.instance.getEcole();
      if (ecole != null) {
        setState(() {
          _currentEcole = ecole;
          _nameController.text = ecole.nom;
          _addressController.text = ecole.adresse ?? '';
          _phoneController.text = ecole.telephone ?? '';
          _emailController.text = ecole.email ?? '';
          _directorController.text = ecole.directeur;
          _founderController.text = ecole.fondateur;
          _logoPath = ecole.logo;
          _timbrePath = ecole.timbre;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur lors du chargement: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _directorController.dispose();
    _founderController.dispose();
    super.dispose();
  }

  Future<void> _selectLogo() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final savedPath = await FileService.instance.saveImage(
        File(image.path),
        FileService.schoolAssetsDir,
      );
      setState(() {
        _logoPath = savedPath;
      });
    }
  }

  Future<void> _selectTimbre() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final savedPath = await FileService.instance.saveImage(
        File(image.path),
        FileService.schoolAssetsDir,
      );
      setState(() {
        _timbrePath = savedPath;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final ecole = Ecole(
          id: _currentEcole?.id,
          nom: _nameController.text,
          fondateur: _founderController.text,
          directeur: _directorController.text,
          adresse: _addressController.text,
          telephone: _phoneController.text,
          email: _emailController.text,
          logo: _logoPath,
          timbre: _timbrePath,
        );

        await DatabaseHelper.instance.upsertEcole(ecole);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informations sauvegardées avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadEcoleData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la sauvegarde: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la page
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identité de l\'Établissement',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF121717),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez les informations officielles, logos et signatures de votre école.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('ENREGISTRER LES MODIFICATIONS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne Gauche: Identité & Logo
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildPremiumCard(
                        title: 'Identité Visuelle',
                        icon: Icons.branding_watermark_outlined,
                        child: Row(
                          children: [
                            _buildImageUploader(
                              label: 'LOGO OFFICIEL',
                              imagePath: _logoPath,
                              onTap: _selectLogo,
                              isDark: isDark,
                              icon: Icons.school,
                            ),
                            const SizedBox(width: 32),
                            _buildImageUploader(
                              label: 'TIMBRE / SCEAU',
                              imagePath: _timbrePath,
                              onTap: _selectTimbre,
                              isDark: isDark,
                              icon: Icons.workspace_premium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPremiumCard(
                        title: 'Informations Générales',
                        icon: Icons.info_outline,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'NOM DE L\'ÉTABLISSEMENT',
                              hint: 'Ex: Groupe Scolaire La Renaissance',
                              icon: Icons.school_outlined,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _founderController,
                                    label: 'FONDATEUR / PRÉSIDENT',
                                    hint: 'Nom Complet',
                                    icon: Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _directorController,
                                    label: 'DIRECTEUR GÉNÉRAL',
                                    hint: 'Nom Complet',
                                    icon: Icons.person_pin_outlined,
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
                const SizedBox(width: 24),
                // Colonne Droite: Contact & Localisation
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPremiumCard(
                        title: 'Contact & Réseaux',
                        icon: Icons.contact_mail_outlined,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _emailController,
                              label: 'EMAIL DE CONTACT',
                              hint: 'contact@ecole.com',
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'NUMÉRO DE TÉLÉPHONE',
                              hint: '+224 6XX XX XX XX',
                              icon: Icons.phone_android,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPremiumCard(
                        title: 'Localisation',
                        icon: Icons.map_outlined,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _addressController,
                              label: 'ADRESSE PHYSIQUE',
                              hint: 'Quartier, Commune, Ville',
                              icon: Icons.location_on_outlined,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildImageUploader({
    required String label,
    required String? imagePath,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: imagePath != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 32, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Cliquez pour uploader',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
