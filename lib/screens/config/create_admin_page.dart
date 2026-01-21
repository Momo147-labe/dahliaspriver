import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/security_utils.dart';
import 'final_review.dart';

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final nameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final secretCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : const Color(0xFFF6F8F8),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isTablet ? 720 : screenWidth),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Section
                _buildProgressSection(isTablet, isDark),
                const SizedBox(height: 40),

                // Main Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFDBE5E6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13DAEC).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Color(0xFF13DAEC),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Profil Administrateur",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.textDarkPrimary
                                      : const Color(0xFF111718),
                                ),
                              ),
                              Text(
                                "Ces informations vous permettront de gérer l'école en toute sécurité.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF618689),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Form Fields
                      Column(
                        children: [
                          _buildTextField(
                            label: "Nom complet",
                            controller: nameCtrl,
                            placeholder: "Ex: Moussa Camara",
                            prefixIcon: Icons.person,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            label: "Nom d'utilisateur",
                            controller: usernameCtrl,
                            placeholder: "ex: m.camara",
                            prefixIcon: Icons.alternate_email,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),
                          isTablet
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: "Mot de passe",
                                        controller: passwordCtrl,
                                        placeholder: "••••••••",
                                        prefixIcon: Icons.lock,
                                        obscureText: true,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildTextField(
                                        label: "Confirmation du mot de passe",
                                        controller: confirmCtrl,
                                        placeholder: "••••••••",
                                        prefixIcon: Icons.key,
                                        obscureText: true,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildTextField(
                                      label: "Mot de passe",
                                      controller: passwordCtrl,
                                      placeholder: "••••••••",
                                      prefixIcon: Icons.lock,
                                      obscureText: true,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildTextField(
                                      label: "Confirmation du mot de passe",
                                      controller: confirmCtrl,
                                      placeholder: "••••••••",
                                      prefixIcon: Icons.key,
                                      obscureText: true,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 24),

                          // Divider
                          Divider(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFDBE5E6),
                          ),
                          const SizedBox(height: 24),

                          // Secret Code Section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13DAEC).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF13DAEC).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Code Secret de récupération",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppTheme.textDarkPrimary
                                            : const Color(0xFF111718),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message:
                                          "Ce code est indispensable pour récupérer votre compte hors-ligne",
                                      child: Icon(
                                        Icons.help_outline,
                                        size: 16,
                                        color: const Color(0xFF13DAEC),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: secretCtrl,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    letterSpacing: 2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Ex: 8824-0012",
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF618689),
                                      fontFamily: 'monospace',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.security,
                                      color: Color(0xFF13DAEC),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF13DAEC,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF13DAEC,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF13DAEC),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(15),
                                    filled: true,
                                    fillColor: isDark
                                        ? AppTheme.cardDark
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Note: Gardez ce code précieusement. Il permet de réinitialiser vos accès sans connexion internet.",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF618689),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Warning Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.offline_pin, color: Colors.amber.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Comme Guinée École fonctionne hors-ligne, vos identifiants sont chiffrés et stockés sur cet appareil uniquement. Assurez-vous d'utiliser un mot de passe dont vous vous souviendrez.",
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Footer Actions
                _buildFooter(isTablet, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(bool isTablet, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CONFIGURATION",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF13DAEC).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Création du compte Administrateur",
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : const Color(0xFF111718),
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Étape 2 sur 3",
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : const Color(0xFF111718),
                  ),
                ),
                const Text(
                  "66% Complété",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF13DAEC),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.66,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF13DAEC),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Section actuelle: Sécurité et identifiants de l'administrateur principal",
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF618689),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData prefixIcon,
    required bool isDark,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textDarkPrimary : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF618689),
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF618689),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF13DAEC), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 15,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.surfaceDark : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isTablet, bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
          ),
        ),
      ),
      child: isTablet ? _buildTabletFooter(isDark) : _buildMobileFooter(isDark),
    );
  }

  Widget _buildTabletFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text("Précédent"),
          style: TextButton.styleFrom(
            foregroundColor: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF618689),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAdminData,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.surfaceDark
                    : const Color(0xFFF0F4F4),
                foregroundColor: isDark
                    ? AppTheme.textDarkPrimary
                    : const Color(0xFF111718),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF13DAEC),
                        ),
                      ),
                    )
                  : const Text(
                      "Sauvegarder",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _createAdminAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13DAEC),
                foregroundColor: const Color(0xFF102022),
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF13DAEC).withOpacity(0.2),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Suivant",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFooter(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createAdminAndContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13DAEC),
              foregroundColor: const Color(0xFF102022),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF13DAEC).withOpacity(0.2),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    "Suivant",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("Précédent"),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF618689),
                ),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAdminData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.surfaceDark
                      : const Color(0xFFF0F4F4),
                  foregroundColor: isDark
                      ? AppTheme.textDarkPrimary
                      : const Color(0xFF111718),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF13DAEC),
                          ),
                        ),
                      )
                    : const Text(
                        "Sauvegarder",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveAdminData() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _createAdminInDatabase();
      _showSuccessSnackBar("Administrateur sauvegardé avec succès !");
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la sauvegarde: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAdminAndContinue() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _createAdminInDatabase();
      _showSuccessSnackBar("Administrateur créé avec succès !");

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FinalReviewPage()),
      );
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la création: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (nameCtrl.text.trim().isEmpty ||
        usernameCtrl.text.trim().isEmpty ||
        passwordCtrl.text.trim().isEmpty ||
        confirmCtrl.text.trim().isEmpty ||
        secretCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Veuillez remplir tous les champs");
      return false;
    }

    if (passwordCtrl.text != confirmCtrl.text) {
      _showErrorSnackBar("Les mots de passe ne correspondent pas");
      return false;
    }

    if (passwordCtrl.text.length < 6) {
      _showErrorSnackBar("Le mot de passe doit contenir au moins 6 caractères");
      return false;
    }

    if (secretCtrl.text.length < 4) {
      _showErrorSnackBar("Le code secret doit contenir au moins 4 caractères");
      return false;
    }

    return true;
  }

  Future<void> _createAdminInDatabase() async {
    final db = await DatabaseHelper.instance.database;

    final hashedPassword = SecurityUtils.hashPassword(passwordCtrl.text.trim());

    final adminData = {
      'pseudo': usernameCtrl.text.trim(),
      'email':
          '${usernameCtrl.text.trim()}@guinerschools.com', // Email généré automatiquement
      'password': hashedPassword,
      'codesecret': secretCtrl.text.trim(),
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    };

    await db.insert('user', adminData);
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
}
