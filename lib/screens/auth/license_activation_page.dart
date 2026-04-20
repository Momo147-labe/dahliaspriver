import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/license_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding_page.dart';
import 'login_page.dart';
import '../../core/database/database_helper.dart';

class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({super.key});

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final _licenseController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _activateLicense() async {
    final key = _licenseController.text.trim();
    if (key.length < 10) {
      setState(() => _errorMessage = "Format de clé invalide.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Pour une activation au démarrage, on n'a pas forcément les infos de l'école
      // On passe des données vides, le service gérera si la licence est déjà active
      final result = await LicenseService().verifyAndActivateLicense(
        licenseKey: key,
        schoolData: {},
      );

      if (result['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLicenseValidated', true);
        await prefs.setString('licenseKey', key);

        if (mounted) {
          // Vérifier si une école existe pour savoir où rediriger
          final hasEcoles = await DatabaseHelper.instance.hasEcoles();
          if (hasEcoles) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingPage()),
            );
          }
        }
      } else {
        setState(() => _errorMessage = result['message']);
      }
    } catch (e) {
      setState(() => _errorMessage = "Erreur de connexion : $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _errorMessage = "Impossible d'ouvrir : $url");
      }
    } catch (e) {
      setState(() => _errorMessage = "Erreur : $e");
    }
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
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key, size: 64, color: Color(0xFF13DAEC)),
                const SizedBox(height: 24),
                const Text(
                  "Activation de Licence",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Veuillez entrer votre clé de licence pour continuer.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: "Clé de licence (XXXX-XXXX-XXXX)",
                    hintText: "Entrez votre clé ici",
                    prefixIcon: const Icon(Icons.key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorMessage,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _activateLicense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13DAEC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("Activer maintenant"),
                  ),
                ),
                const SizedBox(height: 24),

                // Section Support
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.surfaceDark
                        : const Color(0xFFF0F4F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFDBE5E6),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Besoin d'aide pour votre licence ?",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSupportIcon(
                            icon: Icons.chat,
                            color: Colors.green,
                            onTap: () =>
                                _launchURL("https://wa.me/224627172530"),
                            tooltip: "WhatsApp",
                          ),
                          _buildSupportIcon(
                            icon: Icons.email,
                            color: Colors.blue,
                            onTap: () =>
                                _launchURL("mailto:fodemomos11@gmail.com"),
                            tooltip: "Email",
                          ),
                          _buildSupportIcon(
                            icon: Icons.phone,
                            color: Colors.orange,
                            onTap: () => _launchURL("tel:224627172530"),
                            tooltip: "Appel",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
