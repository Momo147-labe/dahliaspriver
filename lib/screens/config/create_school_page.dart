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
  final cityCtrl = TextEditingController();

  // Contrôleurs pour l'année académique
  final academicYearCtrl = TextEditingController();
  final startDateCtrl = TextEditingController();
  final endDateCtrl = TextEditingController();

  String? _logoPath;
  String? _stampPath;
  bool _isLoading = false;
  int _currentStep = 0;

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
    final sidePadding = isTablet ? screenWidth * 0.15 : 24.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppTheme.backgroundDark,
                      AppTheme.surfaceDark,
                      AppTheme.backgroundDark.withValues(alpha: 0.9),
                    ]
                  : [
                      AppTheme.backgroundLight,
                      AppTheme.hoverLight,
                      AppTheme.cardLight,
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: isDark ? 0.03 : 0.02,
                  child: Image.asset(
                    'assets/images/bg_pattern.png',
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeat,
                    errorBuilder: (context, error, stackTrace) => Container(),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(isDark),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? sidePadding : 24,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProgressIndicator(isDark),
                                const SizedBox(height: 48),
                                _buildStepContent(isDark),
                                const SizedBox(height: 48),
                                _buildFooter(isTablet, isDark),
                                const SizedBox(height: 32),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.transparent,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Guinée Ecole",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark
                      ? AppTheme.textDarkPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              Text(
                "CONFIGURATION INITIALE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.textDarkSecondary.withValues(alpha: 0.7)
                      : AppTheme.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color: index <= _currentStep
                  ? AppTheme.primaryColor
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              borderRadius: BorderRadius.circular(3),
              boxShadow: index == _currentStep
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 30),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? AppTheme.borderDark.withValues(alpha: 0.5)
                      : AppTheme.borderLight.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: _stepContentWidget(isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _stepContentWidget(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildGeneralInfoStep(isDark);
      case 1:
        return _buildIdentityStep(isDark);
      case 2:
        return _buildAcademicStep(isDark);
      case 3:
        return _buildContactStep(isDark);
      default:
        return _buildGeneralInfoStep(isDark);
    }
  }

  Widget _buildStepHeader(
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? AppTheme.textDarkPrimary
                          : AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Divider(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight.withValues(alpha: 0.5),
          thickness: 1,
        ),
      ],
    );
  }

  Widget _buildGeneralInfoStep(bool isDark) {
    return Column(
      children: [
        _buildStepHeader(
          "Informations",
          "Détails de base de l'école",
          Icons.business_rounded,
          isDark,
        ),
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
          icon: Icons.person_outline,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildIdentityStep(bool isDark) {
    return Column(
      children: [
        _buildStepHeader(
          "Identité",
          "Logo et cachet officiel",
          Icons.verified_rounded,
          isDark,
        ),
        _buildLogoCard(isDark),
        const SizedBox(height: 20),
        _buildStampCard(isDark),
      ],
    );
  }

  Widget _buildContactStep(bool isDark) {
    return Column(
      children: [
        _buildStepHeader(
          "Contact",
          "Coordonnées de l'établissement",
          Icons.contact_phone_rounded,
          isDark,
        ),
        _buildEnhancedTextField(
          controller: addressCtrl,
          label: "Adresse",
          hint: "Adresse complète",
          icon: Icons.location_on,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildEnhancedTextField(
          controller: cityCtrl,
          label: "Ville",
          hint: "Ex: Conakry",
          icon: Icons.location_city,
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
    );
  }

  Widget _buildAcademicStep(bool isDark) {
    return Column(
      children: [
        _buildStepHeader(
          "Année Scolaire",
          "Configuration de l'exercice",
          Icons.calendar_today_rounded,
          isDark,
        ),
        _buildEnhancedTextField(
          controller: academicYearCtrl,
          label: "Année Académique",
          hint: "Ex: 2023-2024",
          icon: Icons.history_edu,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildDateField(
          controller: startDateCtrl,
          label: "Date de début",
          hint: "AAAA-MM-JJ",
          icon: Icons.event_available,
          isDark: isDark,
          onTap: () => _selectDate(context, startDateCtrl, "Date de début"),
        ),
        const SizedBox(height: 20),
        _buildDateField(
          controller: endDateCtrl,
          label: "Date de fin",
          hint: "AAAA-MM-JJ",
          icon: Icons.event_busy,
          isDark: isDark,
          onTap: () => _selectDate(context, endDateCtrl, "Date de fin"),
        ),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark
                  ? AppTheme.textDarkSecondary.withValues(alpha: 0.5)
                  : AppTheme.textMuted,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSecondary,
              size: 20,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.borderDark.withValues(alpha: 0.5)
                    : AppTheme.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.borderDark.withValues(alpha: 0.5)
                    : AppTheme.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoCard(bool isDark) {
    return _buildEnhancedImageUploadCard(
      title: "Logo",
      subtitle: "Image de l'école",
      imagePath: _logoPath,
      onTap: () async {
        final db = await DatabaseHelper.instance.database;
        final path = await pickAndSaveSchoolLogo(db, 0);
        if (path != null) setState(() => _logoPath = path);
      },
      isDark: isDark,
      icon: Icons.business,
    );
  }

  Widget _buildStampCard(bool isDark) {
    return _buildEnhancedImageUploadCard(
      title: "Timbre",
      subtitle: "Cachet officiel",
      imagePath: _stampPath,
      onTap: () async {
        final db = await DatabaseHelper.instance.database;
        final path = await pickAndSaveSchoolStamp(db, 0);
        if (path != null) setState(() => _stampPath = path);
      },
      isDark: isDark,
      icon: Icons.verified,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
              child: imagePath != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                      child: Image.file(File(imagePath), fit: BoxFit.cover),
                    )
                  : Icon(icon, color: AppTheme.primaryColor, size: 32),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isTablet, bool isDark) {
    if (!isTablet) return _buildMobileFooter(isDark);

    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: _buildSecondaryButton(
              onTap: () => setState(() => _currentStep--),
              label: "Précédent",
              icon: Icons.arrow_back_ios_new_rounded,
              isDark: isDark,
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _buildPrimaryButton(
            onTap: _currentStep < 3
                ? () {
                    if (_validateCurrentStep()) {
                      setState(() => _currentStep++);
                    }
                  }
                : _createSchool,
            label: _currentStep < 3 ? "Continuer" : "Finaliser l'installation",
            icon: _currentStep < 3
                ? Icons.arrow_forward_ios_rounded
                : Icons.check_circle_outline_rounded,
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(bool isDark) {
    return Column(
      children: [
        _buildPrimaryButton(
          onTap: _currentStep < 3
              ? () {
                  if (_validateCurrentStep()) {
                    setState(() => _currentStep++);
                  }
                }
              : _createSchool,
          label: _currentStep < 3 ? "Continuer" : "Finaliser l'installation",
          icon: _currentStep < 3
              ? Icons.arrow_forward_ios_rounded
              : Icons.check_circle_outline_rounded,
          isLoading: _isLoading,
        ),
        if (_currentStep > 0) ...[
          const SizedBox(height: 12),
          _buildSecondaryButton(
            onTap: () => setState(() => _currentStep--),
            label: "Précédent",
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : AppTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (schoolNameCtrl.text.trim().isEmpty ||
          founderCtrl.text.trim().isEmpty ||
          directorCtrl.text.trim().isEmpty) {
        _showErrorSnackBar("Veuillez remplir les informations de l'école");
        return false;
      }
    } else if (_currentStep == 2) {
      if (academicYearCtrl.text.trim().isEmpty ||
          startDateCtrl.text.trim().isEmpty ||
          endDateCtrl.text.trim().isEmpty) {
        _showErrorSnackBar("Veuillez configurer l'année académique");
        return false;
      }
    }
    return true;
  }

  Future<void> _createSchool() async {
    if (schoolNameCtrl.text.trim().isEmpty ||
        founderCtrl.text.trim().isEmpty ||
        directorCtrl.text.trim().isEmpty ||
        addressCtrl.text.trim().isEmpty ||
        cityCtrl.text.trim().isEmpty ||
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
        'ville': cityCtrl.text.trim(),
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

        if (!mounted) return;
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
                suffixIcon: const Icon(
                  Icons.calendar_month,
                  color: AppTheme.primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark.withValues(alpha: 0.5)
                        : AppTheme.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark.withValues(alpha: 0.5)
                        : AppTheme.borderLight,
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
                  horizontal: 48,
                  vertical: 15,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
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
        'statut': 'Active',
        'annee_precedente_id': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await db.insert('annee_scolaire', academicYearData);
      debugPrint("Année académique $libelle créée avec succès !");
    } catch (e) {
      debugPrint("Erreur lors de la création de l'année académique: $e");
      rethrow;
    }
  }
}
