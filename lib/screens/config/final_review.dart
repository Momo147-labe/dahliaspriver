import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../core/database/daos/config_dao.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/license_service.dart';
import '../../core/services/trial_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/dashboard/trial_countdown.dart';

class FinalReviewPage extends StatefulWidget {
  const FinalReviewPage({super.key});

  @override
  State<FinalReviewPage> createState() => _FinalReviewPageState();
}

class _FinalReviewPageState extends State<FinalReviewPage> {
  bool maternelle = true;
  bool primaire = true;
  bool college = false;
  bool lycee = false;
  bool _isLoading = true;
  bool _isValidatingLicense = false;
  bool _isLicenseValidated = false;
  Map<String, dynamic>? schoolData;
  final TextEditingController _licenseController = TextEditingController();

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
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur chargement école: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    "Chargement des informations...",
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF618689),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 960 : screenWidth,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Section
                      _buildProgressSection(isTablet, isDark),
                      const SizedBox(height: 16),
                      Center(child: TrialCountdown()),
                      const SizedBox(height: 16),

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
                  "DERNIÈRE ÉTAPE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF13DAEC).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Révision Finale & Structure",
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
                  "Étape 3 sur 3",
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : const Color(0xFF111718),
                  ),
                ),
                const Text(
                  "100% Complété",
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
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13DAEC),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Vérifiez vos informations et configurez vos niveaux d'enseignement",
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

  Widget _buildTabletLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSchoolSummary(isDark),
              const SizedBox(height: 24),
              _buildTeachingStructure(isDark),
              const SizedBox(height: 24),
              _buildLicenseSection(isDark),
              const SizedBox(height: 24),
              _buildReadyCard(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        _buildSchoolSummary(isDark),
        const SizedBox(height: 24),
        _buildTeachingStructure(isDark),
        const SizedBox(height: 24),
        _buildLicenseSection(isDark),
        const SizedBox(height: 24),
        _buildReadyCard(isDark),
      ],
    );
  }

  Widget _buildSchoolSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Résumé de l'établissement",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.textDarkPrimary
                      : const Color(0xFF111718),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "Modifier",
                  style: TextStyle(
                    color: Color(0xFF13DAEC),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // School Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark
                      : const Color(0xFFF6F8F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFDBE5E6),
                  ),
                ),
                child: schoolData != null && schoolData!['logo'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(schoolData!['logo']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.school,
                              color: Color(0xFF618689),
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.school, color: Color(0xFF618689)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolData?['nom'] ?? "Nom de l'école",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textDarkPrimary
                            : const Color(0xFF111718),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [schoolData?['adresse'], schoolData?['ville']]
                              .where(
                                (e) =>
                                    e != null && e.toString().trim().isNotEmpty,
                              )
                              .join(" - ")
                              .isEmpty
                          ? "Adresse non spécifiée"
                          : [schoolData?['adresse'], schoolData?['ville']]
                                .where(
                                  (e) =>
                                      e != null &&
                                      e.toString().trim().isNotEmpty,
                                )
                                .join(" - "),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF618689),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildInfoItem(
                "FONDATEUR",
                schoolData?['fondateur'] ?? "Non spécifié",
                isDark,
              ),
              _buildInfoItem(
                "DIRECTEUR",
                schoolData?['directeur'] ?? "Non spécifié",
                isDark,
              ),
              _buildInfoItem(
                "CONTACT",
                schoolData?['telephone'] ?? "Non spécifié",
                isDark,
              ),
              _buildInfoItem(
                "IDENTITÉ VISUELLE",
                (schoolData?['logo'] != null && schoolData?['timbre'] != null)
                    ? "Logo & Timbre chargés"
                    : "Images manquantes",
                isDark,
                isPrimary:
                    (schoolData?['logo'] != null &&
                    schoolData?['timbre'] != null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    bool isDark, {
    bool isPrimary = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF618689),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPrimary
                ? const Color(0xFF13DAEC)
                : isDark
                ? AppTheme.textDarkPrimary
                : const Color(0xFF111718),
          ),
        ),
      ],
    );
  }

  Widget _buildTeachingStructure(bool isDark) {
    bool isTablet = MediaQuery.of(context).size.width > 768;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13DAEC).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_tree,
                  color: Color(0xFF13DAEC),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Structure d'enseignement",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.textDarkPrimary
                          : const Color(0xFF111718),
                    ),
                  ),
                  Text(
                    "Sélectionnez les cycles disponibles",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF618689),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isTablet ? 2 : 1,
            childAspectRatio: isTablet ? 4 : 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildCycleTile(
                title: "Préscolaire",
                subtitle: "Petite, Moyenne et Grande section",
                icon: Icons.child_care,
                value: maternelle,
                onChanged: (val) => setState(() => maternelle = val),
                isDark: isDark,
              ),
              _buildCycleTile(
                title: "Primaire",
                subtitle: "De la 1ère à la 6ème année",
                icon: Icons.backpack,
                value: primaire,
                onChanged: (val) => setState(() => primaire = val),
                isDark: isDark,
              ),
              _buildCycleTile(
                title: "Collège",
                subtitle: "De la 7ème à la 10ème année",
                icon: Icons.school_outlined,
                value: college,
                onChanged: (val) => setState(() => college = val),
                isDark: isDark,
              ),
              _buildCycleTile(
                title: "Lycée",
                subtitle: "11ème, 12ème et Terminale",
                icon: Icons.account_balance,
                value: lycee,
                onChanged: (val) => setState(() => lycee = val),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isLicenseValidated
              ? AppTheme.successColor
              : (isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLicenseValidated ? Icons.verified : Icons.vpn_key,
                color: _isLicenseValidated
                    ? AppTheme.successColor
                    : const Color(0xFF13DAEC),
              ),
              const SizedBox(width: 12),
              Text(
                "Activation de Licence",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.textDarkPrimary
                      : const Color(0xFF111718),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Entrez votre clé de 24 caractères (XXXX-XXXX-XXXX) pour activer votre logiciel scolaire.",
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF618689),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _licenseController,
                  enabled: !_isLicenseValidated && !_isValidatingLicense,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", // 24 chars
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.surfaceDark
                        : const Color(0xFFF6F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLicenseValidated || _isValidatingLicense)
                      ? null
                      : _validateLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isValidatingLicense
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLicenseValidated ? "ACTIVÉ" : "VALIDER"),
                ),
              ),
            ],
          ),
          if (!_isLicenseValidated) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text("Essayer gratuitement pendant 7 jours"),
                onPressed: () async {
                  final success = await TrialService.activateTrial();
                  final status = await TrialService.checkTrialStatus();

                  if (success ||
                      (status['isTrial'] == true && !status['expired'])) {
                    if (mounted) {
                      await _completeConfiguration();
                    }
                  } else {
                    _showErrorSnackBar(
                      status['expired'] == true
                          ? status['message']
                          : "La période d'essai a déjà été épuisée sur cette machine.",
                    );
                  }
                },
              ),
            ),
          ],
          if (_isLicenseValidated) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "Licence validée et liée à cet appareil.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFDBE5E6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Besoin d'acheter une licence ?",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Contactez-nous pour obtenir votre clé d'activation.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (!_isLicenseValidated) ...[
                  FutureBuilder<bool>(
                    future: TrialService.isTrialActive(),
                    builder: (context, snapshot) {
                      final isActive = snapshot.data ?? false;
                      if (isActive) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.timer, color: Colors.blue, size: 20),
                              SizedBox(width: 12),
                              Text(
                                "Période d'essai activée (7 jours)",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return SizedBox();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildSupportBadge(
                      icon: Icons.chat,
                      label: "WhatsApp: 627172530",
                      color: Colors.green,
                      onTap: () => _launchURL("https://wa.me/224627172530"),
                    ),
                    const SizedBox(width: 8),
                    _buildSupportBadge(
                      icon: Icons.phone,
                      label: "Appel: 627172530 / 666761076",
                      color: Colors.orange,
                      onTap: () => _launchURL("tel:224627172530"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.deepOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Paiement Orange Money : *144*6*674698#",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: "674698"),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Code Marchand copié !"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportBadge({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validateLicense() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      _showErrorSnackBar("Veuillez saisir votre clé de licence.");
      return;
    }

    setState(() => _isValidatingLicense = true);

    try {
      final service = LicenseService();
      final result = await service.verifyAndActivateLicense(
        licenseKey: key,
        schoolData: schoolData ?? {},
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLicenseValidated', true);
        await prefs.setString('licenseKey', key);

        setState(() {
          _isLicenseValidated = true;
          _isValidatingLicense = false;
        });
        _showSuccessSnackBar(result['message']);
      } else {
        setState(() => _isValidatingLicense = false);
        _showErrorSnackBar(result['message']);
      }
    } catch (e) {
      setState(() => _isValidatingLicense = false);
      _showErrorSnackBar("Erreur de connexion au serveur de licence.");
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar("Impossible d'ouvrir : $url");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur : $e");
    }
  }

  Widget _buildReadyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13DAEC).withValues(alpha: 0.05),
        border: Border.all(
          color: const Color(0xFF13DAEC).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF13DAEC).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user, color: Color(0xFF13DAEC)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Prêt pour le déploiement",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111718),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Toutes les informations obligatoires ont été saisies. L'application générera votre base de données locale sécurisée dès la validation finale.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF618689),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF13DAEC).withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: value
                ? const Color(0xFF13DAEC)
                : isDark
                ? AppTheme.borderDark
                : const Color(0xFFDBE5E6),
            width: value ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF13DAEC).withValues(alpha: 0.2)
                    : isDark
                    ? AppTheme.surfaceDark
                    : const Color(0xFFF0F4F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: value
                    ? const Color(0xFF13DAEC)
                    : isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF618689),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.textDarkPrimary
                          : const Color(0xFF111718),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF618689),
                    ),
                  ),
                ],
              ),
            ),
            value
                ? const Icon(Icons.check_circle, color: Color(0xFF13DAEC))
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppTheme.borderDark
                            : const Color(0xFFDBE5E6),
                      ),
                    ),
                  ),
          ],
        ),
      ),
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
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _completeConfiguration,
          icon: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.rocket_launch),
          label: Text(
            _isLoading ? "Configuration..." : "Terminer la configuration",
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13DAEC),
            foregroundColor: const Color(0xFF102022),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: const Color(0xFF13DAEC).withValues(alpha: 0.2),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _completeConfiguration,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(
              _isLoading ? "Configuration..." : "Terminer la configuration",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13DAEC),
              foregroundColor: const Color(0xFF102022),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF13DAEC).withValues(alpha: 0.2),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text("Précédent"),
          style: TextButton.styleFrom(
            foregroundColor: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF618689),
          ),
        ),
      ],
    );
  }

  Future<void> _completeConfiguration() async {
    setState(() {
      _isLoading = true;
    });

    if (!_isLicenseValidated) {
      final isTrial = await TrialService.isTrialActive();
      if (!isTrial) {
        _showErrorSnackBar(
          "Veuillez valider votre licence ou activer l'essai de 7 jours.",
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      final configDao = ConfigDao(await DatabaseHelper.instance.database);
      await configDao.initializeTeachingStructure(
        prescolaire: maternelle,
        primaire: primaire,
        college: college,
        lycee: lycee,
      );

      _showSuccessSnackBar("Configuration terminée avec succès !");

      // Rediriger vers la page de login
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la configuration: $e");
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
