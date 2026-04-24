import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/security_utils.dart';
import 'login_page.dart';

class AdminRegistrationPage extends StatefulWidget {
  const AdminRegistrationPage({super.key});

  @override
  State<AdminRegistrationPage> createState() => _AdminRegistrationPageState();
}

class _AdminRegistrationPageState extends State<AdminRegistrationPage> {
  final nameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final secretCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  Future<void> _registerAdmin() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final hashedPassword = SecurityUtils.hashPassword(
        passwordCtrl.text.trim(),
      );

      final adminData = {
        'pseudo': usernameCtrl.text.trim(),
        'email': '${usernameCtrl.text.trim()}@guinerschools.com',
        'password': hashedPassword,
        'codesecret': secretCtrl.text.trim(),
        'role': 'admin',
        'created_at': DateTime.now().toIso8601String(),
      };

      await db.insert('user', adminData);

      if (mounted) {
        _showSuccessSnackBar("Compte administrateur créé avec succès !");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = "Erreur lors de la création : $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateForm() {
    if (nameCtrl.text.trim().isEmpty ||
        usernameCtrl.text.trim().isEmpty ||
        passwordCtrl.text.trim().isEmpty ||
        confirmCtrl.text.trim().isEmpty ||
        secretCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Veuillez remplir tous les champs");
      return false;
    }

    if (passwordCtrl.text != confirmCtrl.text) {
      setState(() => _errorMessage = "Les mots de passe ne correspondent pas");
      return false;
    }

    if (passwordCtrl.text.length < 6) {
      setState(
        () => _errorMessage =
            "Le mot de passe doit contenir au moins 6 caractères",
      );
      return false;
    }

    return true;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : const Color(0xFFF6F8F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: Color(0xFF13DAEC),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Créer le compte Administrateur",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "L'école est configurée. Veuillez maintenant créer le premier compte administrateur.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _buildField("Nom complet", nameCtrl, Icons.person),
                const SizedBox(height: 16),
                _buildField(
                  "Nom d'utilisateur",
                  usernameCtrl,
                  Icons.alternate_email,
                ),
                const SizedBox(height: 16),
                _buildField(
                  "Mot de passe",
                  passwordCtrl,
                  Icons.lock,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "Confirmer le mot de passe",
                  confirmCtrl,
                  Icons.key,
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "Code Secret (Récupération)",
                  secretCtrl,
                  Icons.security,
                  hint: "Ex: 8824-0012",
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13DAEC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            "Créer le compte et Continuer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
    String? hint,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
