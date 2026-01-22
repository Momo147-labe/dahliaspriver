import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/uploadImage.dart';
import '../../theme/app_theme.dart';
import 'create_admin_page.dart';

class CreateSchoolPage extends StatefulWidget {
  const CreateSchoolPage({super.key});

  @override
  State<CreateSchoolPage> createState() => _CreateSchoolPageState();
}

class _CreateSchoolPageState extends State<CreateSchoolPage> {
  final schoolNameCtrl = TextEditingController();
  final founderCtrl = TextEditingController();
  final directorCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // Contrôleurs pour l'année académique
  final academicYearCtrl = TextEditingController();
  final startDateCtrl = TextEditingController();
  final endDateCtrl = TextEditingController();

  String? _logoPath;
  String? _stampPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAcademicYearDefaults();
  }

  void _initializeAcademicYearDefaults() {
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;

    academicYearCtrl.text = "$currentYear-$nextYear";
    startDateCtrl.text = "${currentYear}-09-01";
    endDateCtrl.text = "${nextYear}-06-30";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1F2E),
                    const Color(0xFF2D3748),
                    const Color(0xFF4A5568),
                  ]
                : [
                    const Color(0xFFF7FAFC),
                    const Color(0xFFEDF2F7),
                    const Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 1200 : screenWidth,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 20,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec animation
                    _buildAnimatedHeader(isTablet, isDark),
                    const SizedBox(height: 40),

                    // Main Content
                    isTablet
                        ? _buildTabletLayout(isDark)
                        : _buildMobileLayout(isDark),
                    const SizedBox(height: 40),

                    // Footer Actions
                    _buildFooter(isTablet, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(bool isTablet, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icône animé
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF13DAEC).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school,
                      color: Colors.white,
                      size: isTablet ? 32.0 : 24.0,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ÉTAPE 1 SUR 2",
                          style: TextStyle(
                            fontSize: isTablet ? 14.0 : 12.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF13DAEC),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Création de l'établissement",
                          style: TextStyle(
                            fontSize: isTablet ? 28.0 : 22.0,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A202C),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Configurez les informations essentielles de votre école",
                          style: TextStyle(
                            fontSize: isTablet ? 16.0 : 14.0,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        _buildSchoolInfoCard(isDark),
        const SizedBox(height: 24),
        _buildContactInfoCard(isDark),
        const SizedBox(height: 24),
        _buildAcademicYearCard(isDark),
        const SizedBox(height: 24),
        _buildLogoCard(isDark),
        const SizedBox(height: 24),
        _buildStampCard(isDark),
      ],
    );
  }

  Widget _buildTabletLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildSchoolInfoCard(isDark),
              const SizedBox(height: 24),
              _buildContactInfoCard(isDark),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildAcademicYearCard(isDark),
              const SizedBox(height: 24),
              _buildLogoCard(isDark),
              const SizedBox(height: 24),
              _buildStampCard(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolInfoCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 30),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF13DAEC).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "🏫 Informations de l'école",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildEnhancedTextField(
                    controller: schoolNameCtrl,
                    label: "Nom de l'école",
                    hint: "Ex: Lycée de Conakry",
                    icon: Icons.school,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildEnhancedTextField(
                    controller: founderCtrl,
                    label: "Fondateur",
                    hint: "Nom du fondateur",
                    icon: Icons.person,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildEnhancedTextField(
                    controller: directorCtrl,
                    label: "Directeur",
                    hint: "Nom du directeur",
                    icon: Icons.admin_panel_settings,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactInfoCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 40),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF13DAEC).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.contact_phone,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "📞 Coordonnées",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildEnhancedTextField(
                    controller: addressCtrl,
                    label: "Adresse",
                    hint: "Adresse complète de l'école",
                    icon: Icons.location_on,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildEnhancedTextField(
                    controller: phoneCtrl,
                    label: "Téléphone",
                    hint: "Numéro de téléphone",
                    icon: Icons.phone,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF374151),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: const Color(0xFF13DAEC), size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF13DAEC), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF9FAFB),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicYearCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 50),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF13DAEC).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "📅 Année Académique",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Configurez la première année académique de votre établissement.",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildEnhancedTextField(
                    controller: academicYearCtrl,
                    label: "Libellé de l'année",
                    hint: "Ex: 2024-2025",
                    icon: Icons.calendar_today,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          controller: startDateCtrl,
                          label: "Date de début",
                          hint: "AAAA-MM-JJ",
                          icon: Icons.play_arrow,
                          isDark: isDark,
                          onTap: () => _selectDate(
                            context,
                            startDateCtrl,
                            "Début de l'année académique",
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          controller: endDateCtrl,
                          label: "Date de fin",
                          hint: "AAAA-MM-JJ",
                          icon: Icons.stop,
                          isDark: isDark,
                          onTap: () => _selectDate(
                            context,
                            endDateCtrl,
                            "Fin de l'année académique",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF13DAEC).withOpacity(0.1),
                          const Color(0xFF13DAEC).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF13DAEC).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: const Color(0xFF13DAEC),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Cette année académique sera automatiquement activée lors de la création de l'école.",
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF13DAEC),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 60),
          child: Opacity(
            opacity: value,
            child: _buildEnhancedImageUploadCard(
              title: "📷 Logo de l'école",
              subtitle:
                  "Le logo sera affiché sur l'interface principale et les documents officiels.",
              imagePath: _logoPath,
              onTap: () async {
                final db = await DatabaseHelper.instance.database;
                final path = await pickAndSaveSchoolLogo(db, 0);
                if (path != null) {
                  setState(() {
                    _logoPath = path;
                  });
                }
              },
              isDark: isDark,
              icon: Icons.business,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStampCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 70),
          child: Opacity(
            opacity: value,
            child: _buildEnhancedImageUploadCard(
              title: "🏷️ Timbre officiel",
              subtitle:
                  "Le timbre sera utilisé pour générer automatiquement les bulletins et documents officiels.",
              imagePath: _stampPath,
              onTap: () async {
                final db = await DatabaseHelper.instance.database;
                final path = await pickAndSaveSchoolStamp(db, 0);
                if (path != null) {
                  setState(() {
                    _stampPath = path;
                  });
                }
              },
              isDark: isDark,
              icon: Icons.verified,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedImageUploadCard({
    required String title,
    required String subtitle,
    required String? imagePath,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF13DAEC).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF13DAEC).withOpacity(0.2),
                      const Color(0xFF13DAEC).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF13DAEC), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Stack(
                children: [
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder(isDark);
                        },
                      ),
                    )
                  else
                    _buildImagePlaceholder(isDark),

                  // Overlay avec icône
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13DAEC),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_upload,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
            isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFE2E8F0),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            "Cliquez pour ajouter une image",
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isTablet, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 80),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: const Color(0xFF13DAEC).withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isTablet
                  ? _buildTabletFooter(isDark)
                  : _buildMobileFooter(isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletFooter(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.95 + (value * 0.05),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Précédent",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.95 + (value * 0.05),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13DAEC).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _createSchool,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Continuer vers l'administrateur",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(bool isDark) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (value * 0.05),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Précédent",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (value * 0.05),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF13DAEC), Color(0xFF0EA5E9)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13DAEC).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _createSchool,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Continuer vers l'administrateur",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _createSchool() async {
    if (schoolNameCtrl.text.trim().isEmpty ||
        founderCtrl.text.trim().isEmpty ||
        directorCtrl.text.trim().isEmpty ||
        addressCtrl.text.trim().isEmpty ||
        phoneCtrl.text.trim().isEmpty ||
        academicYearCtrl.text.trim().isEmpty ||
        startDateCtrl.text.trim().isEmpty ||
        endDateCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Veuillez remplir tous les champs obligatoires");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final schoolData = {
        'nom': schoolNameCtrl.text.trim(),
        'fondateur': founderCtrl.text.trim(),
        'directeur': directorCtrl.text.trim(),
        'adresse': addressCtrl.text.trim(),
        'telephone': phoneCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final schoolId = await createSchoolWithImages(
        db,
        schoolData,
        _logoPath,
        _stampPath,
      );

      if (schoolId != null) {
        // Créer la première année académique active
        await _createFirstAcademicYear(db);

        _showSuccessSnackBar("École créée avec succès !");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CreateAdminPage()),
        );
      } else {
        _showErrorSnackBar("Erreur lors de la création de l'école");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textDarkPrimary : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF618689),
                ),
                prefixIcon: Icon(
                  icon,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF618689),
                ),
                suffixIcon: Icon(
                  Icons.calendar_month,
                  color: const Color(0xFF13DAEC),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFDBE5E6),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFDBE5E6),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF13DAEC),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 15,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.surfaceDark : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
    String title,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: title,
      cancelText: 'Annuler',
      confirmText: 'Valider',
      fieldLabelText: title,
      fieldHintText: 'AAAA-MM-JJ',
    );

    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _createFirstAcademicYear(Database db) async {
    try {
      // Utiliser les valeurs saisies par l'utilisateur
      final libelle = academicYearCtrl.text.trim().isEmpty
          ? "${DateTime.now().year}-${DateTime.now().year + 1}"
          : academicYearCtrl.text.trim();

      // Parser les dates ou utiliser les valeurs par défaut
      DateTime dateDebut;
      DateTime dateFin;

      try {
        dateDebut = DateTime.parse(startDateCtrl.text.trim());
      } catch (e) {
        dateDebut = DateTime(
          DateTime.now().year,
          9,
          1,
        ); // 1er septembre par défaut
      }

      try {
        dateFin = DateTime.parse(endDateCtrl.text.trim());
      } catch (e) {
        dateFin = DateTime(
          DateTime.now().year + 1,
          6,
          30,
        ); // 30 juin année suivante par défaut
      }

      final academicYearData = {
        'libelle': libelle,
        'date_debut': dateDebut.toIso8601String(),
        'date_fin': dateFin.toIso8601String(),
        'active': 1, // 1 pour actif, 0 pour inactif
        'etat': 'EN_COURS',
        'annee_precedente_id': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await db.insert('annee_scolaire', academicYearData);
      print("Année académique $libelle créée avec succès !");
    } catch (e) {
      print("Erreur lors de la création de l'année académique: $e");
      throw e;
    }
  }
}
