import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../core/services/license_service.dart';
import '../../main.dart'; // Import pour AuthWrapper

class LicenseBlockedPage extends StatefulWidget {
  const LicenseBlockedPage({super.key});

  @override
  State<LicenseBlockedPage> createState() => _LicenseBlockedPageState();
}

class _LicenseBlockedPageState extends State<LicenseBlockedPage> {
  bool _isChecking = false;

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir l'URL: $e");
    }
  }

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);

    try {
      final licenseService = LicenseService();
      // On force une synchro avec le serveur
      await licenseService.syncLicenseWithServer();

      // On vérifie si c'est débloqué
      final isBlocked = await licenseService.isLicenseBlocked();

      if (!isBlocked) {
        if (mounted) {
          // Si plus bloqué, on recharge l'application vers AuthWrapper
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La licence est toujours marquée comme bloquée sur le serveur.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur lors de la vérification. Vérifiez votre connexion internet.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0C0C)
          : const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_flipped,
                    color: Colors.red,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'ACCÈS BLOQUÉ',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isDark ? Colors.white : const Color(0xFF121717),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Votre licence a été désactivée par un administrateur. Vous n\'avez plus accès aux fonctionnalités de l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                // Bouton de ré-activation
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _checkAgain,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isChecking
                          ? 'VÉRIFICATION EN COURS...'
                          : 'VÉRIFIER À NOUVEAU MON STATUT',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'CONTACTER LE DÉVELOPPEUR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildContactItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Fodé Momo Soumah',
                  subtitle: 'Développeur Logiciel',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildContactItem(
                  context,
                  icon: Icons.alternate_email,
                  title: 'fodemomos11@gmail.com',
                  onTap: () => _launchURL('mailto:fodemomos11@gmail.com'),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildContactItem(
                  context,
                  icon: Icons.phone_android,
                  title: '627 17 25 30 / 666 76 10 76',
                  onTap: () => _launchURL('tel:+224627172530'),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildContactItem(
                  context,
                  icon: Icons.chat_outlined,
                  title: 'WhatsApp: 627 17 25 30',
                  color: Colors.green,
                  onTap: () => _launchURL('https://wa.me/224627172530'),
                  isDark: isDark,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _launchURL('tel:+224627172530'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'APPELER LE SUPPORT MAINTENANT',
                      style: TextStyle(fontWeight: FontWeight.w900),
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

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[900]?.withValues(alpha: 0.5)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: color ?? (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color ?? (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
