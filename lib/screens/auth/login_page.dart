import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../main_layout.dart';
import '../../core/utils/security_utils.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  Map<String, dynamic>? schoolData;

  @override
  void initState() {
    super.initState();
    _loadSchoolData();
  }

  Future<void> _loadSchoolData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final schools = await db.query('ecole', limit: 1);

      if (schools.isNotEmpty) {
        setState(() {
          schoolData = schools.first;
        });
      }
    } catch (e) {
      print('Erreur chargement école: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 1024;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : const Color(0xFFF6F8F8),
      body: Row(
        children: [
          // Left Side - Illustration (only on tablet/desktop)
          if (isTablet) _buildLeftSide(isDark),

          // Right Side - Login Form
          Expanded(
            flex: isTablet ? 2 : 1,
            child: _buildLoginForm(isTablet, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSide(bool isDark) {
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13DAEC).withOpacity(0.1),
        ),
        child: Stack(
          children: [
            // Background SVG Pattern
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),

            // Content
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // School Image
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF13DAEC).withOpacity(0.3),
                                const Color(0xFF13DAEC).withOpacity(0.1),
                              ],
                            ),
                          ),
                          child:
                              schoolData != null && schoolData!['logo'] != null
                              ? Image.file(
                                  File(schoolData!['logo']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.school,
                                      size: 120,
                                      color: Color(0xFF13DAEC),
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.school,
                                  size: 120,
                                  color: Color(0xFF13DAEC),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      schoolData?['nom'] ?? "Guinée École",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textDarkPrimary
                            : const Color(0xFF111718),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    const Text(
                      "L'éducation connectée, même hors ligne. Gérez votre établissement avec simplicité et efficacité.",
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF618689),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Offline Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13DAEC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: Color(0xFF13DAEC),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Mode Local Activé",
                            style: TextStyle(
                              color: Color(0xFF13DAEC),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool isTablet, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        boxShadow: isTablet
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 30,
                  offset: const Offset(-10, 0),
                ),
              ]
            : null,
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 48 : 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13DAEC),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13DAEC).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: schoolData != null && schoolData!['logo'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(schoolData!['logo']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : const Icon(Icons.school, color: Colors.white, size: 32),
                ),

                const SizedBox(height: 32),

                // Header
                Column(
                  children: [
                    Text(
                      "Se connecter",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textDarkPrimary
                            : const Color(0xFF111718),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Heureux de vous revoir ! Veuillez entrer vos identifiants.",
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF618689),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Login Form
                Column(
                  children: [
                    // Username Field
                    _buildTextField(
                      label: "Nom d'utilisateur",
                      controller: usernameCtrl,
                      placeholder: "nom.prenom",
                      prefixIcon: Icons.person,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mot de passe",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.textDarkPrimary
                                : const Color(0xFF111718),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Entrez votre mot de passe",
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF618689),
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF618689),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF618689),
                              ),
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
                            fillColor: isDark
                                ? AppTheme.surfaceDark
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(
                            color: Color(0xFF13DAEC),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13DAEC),
                          foregroundColor: const Color(0xFF111718),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Se connecter",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Footer
                Text.rich(
                  TextSpan(
                    text: "Besoin d'aide ? ",
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF618689),
                      fontSize: 14,
                    ),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Implement contact admin
                          },
                          child: const Text(
                            "Contactez l'administration",
                            style: TextStyle(
                              color: Color(0xFF13DAEC),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                // Mobile Offline Status
                if (!isTablet) ...[
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13DAEC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: Color(0xFF13DAEC),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Application optimisée pour l'usage hors ligne",
                          style: TextStyle(
                            color: Color(0xFF13DAEC),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
        TextFormField(
          controller: controller,
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

  Future<void> _handleLogin() async {
    if (usernameCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Veuillez remplir tous les champs");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      // Rechercher l'utilisateur dans la base de données
      final hashedInput = SecurityUtils.hashPassword(passwordCtrl.text.trim());

      final users = await db.query(
        'user',
        where: 'pseudo = ? AND password = ?',
        whereArgs: [usernameCtrl.text.trim(), hashedInput],
        limit: 1,
      );

      if (users.isNotEmpty) {
        final user = users.first;

        // Save session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', user['id'] as int);
        await prefs.setString('userRole', user['role'] as String);
        await prefs.setString('userName', user['pseudo'] as String);

        // Vérifier si c'est un administrateur
        if (user['role'] == 'admin') {
          _showSuccessSnackBar("Connexion réussie !");

          // Rediriger vers le tableau de bord principal
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainLayout()),
            );
          }
        } else {
          _showErrorSnackBar("Accès réservé aux administrateurs");
        }
      } else {
        _showErrorSnackBar("Identifiants incorrects");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la connexion: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF13DAEC).withOpacity(0.2),
          const Color(0xFF13DAEC).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.2, 0, size.width * 0.5, 0);
    path.quadraticBezierTo(size.width, 0, size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
