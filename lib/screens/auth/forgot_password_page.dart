import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/security_utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final usernameCtrl = TextEditingController();
  final secretCodeCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _verifySecretCode() async {
    if (usernameCtrl.text.trim().isEmpty ||
        secretCodeCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Veuillez remplir tous les champs");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query(
        'user',
        where: 'pseudo = ? AND codesecret = ?',
        whereArgs: [usernameCtrl.text.trim(), secretCodeCtrl.text.trim()],
        limit: 1,
      );

      if (users.isNotEmpty) {
        setState(() {
          _isVerified = true;
        });
      } else {
        _showErrorSnackBar("Identifiants ou code secret incorrects");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur technique: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (newPasswordCtrl.text.isEmpty || confirmPasswordCtrl.text.isEmpty) {
      _showErrorSnackBar("Veuillez remplir les mots de passe");
      return;
    }

    if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      _showErrorSnackBar("Les mots de passe ne correspondent pas");
      return;
    }

    if (newPasswordCtrl.text.length < 6) {
      _showErrorSnackBar("Le mot de passe doit faire au moins 6 caractères");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final hashedUrl = SecurityUtils.hashPassword(newPasswordCtrl.text.trim());

      await db.update(
        'user',
        {'password': hashedUrl},
        where: 'pseudo = ?',
        whereArgs: [usernameCtrl.text.trim()],
      );

      _showSuccessSnackBar("Mot de passe réinitialisé avec succès !");
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la réinitialisation: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : const Color(0xFFF6F8F8),
      appBar: AppBar(
        title: const Text("Réinitialisation"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isVerified ? Icons.lock_open : Icons.security,
                  size: 64,
                  color: const Color(0xFF13DAEC),
                ),
                const SizedBox(height: 24),
                Text(
                  _isVerified
                      ? "Nouveau mot de passe"
                      : "Vérification d'identité",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isVerified
                      ? "Saisissez votre nouveau mot de passe sécurisé."
                      : "Entrez votre nom d'utilisateur et votre code secret.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF618689),
                  ),
                ),
                const SizedBox(height: 32),

                if (!_isVerified) ...[
                  _buildTextField(
                    label: "Nom d'utilisateur",
                    controller: usernameCtrl,
                    placeholder: "ex: m.camara",
                    prefixIcon: Icons.person,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Code Secret",
                    controller: secretCodeCtrl,
                    placeholder: "Votre code de récupération",
                    prefixIcon: Icons.vpn_key,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    onPressed: _isLoading ? null : _verifySecretCode,
                    label: "Vérifier",
                    isLoading: _isLoading,
                  ),
                ] else ...[
                  _buildTextField(
                    label: "Nouveau mot de passe",
                    controller: newPasswordCtrl,
                    placeholder: "••••••••",
                    prefixIcon: Icons.lock,
                    isDark: isDark,
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Confirmer le mot de passe",
                    controller: confirmPasswordCtrl,
                    placeholder: "••••••••",
                    prefixIcon: Icons.check_circle,
                    isDark: isDark,
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    label: "Réinitialiser",
                    isLoading: _isLoading,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF13DAEC),
          foregroundColor: const Color(0xFF111718),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF13DAEC).withOpacity(0.2),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
