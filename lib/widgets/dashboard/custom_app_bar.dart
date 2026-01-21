import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onRefreshPressed;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.onSettingsPressed,
    this.onRefreshPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  Map<String, dynamic>? _ecoleInfo;
  Map<String, dynamic>? _anneeScolaire;
  int _userCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTopBarData();
  }

  Future<void> _loadTopBarData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Charger les informations de l'école
      final ecoles = await db.query('ecole');
      final annees = await db.query('annee_scolaire', orderBy: 'created_at DESC', limit: 1);
      final users = await db.query('user');
      
      setState(() {
        _ecoleInfo = ecoles.isNotEmpty ? ecoles.first : null;
        _anneeScolaire = annees.isNotEmpty ? annees.first : null;
        _userCount = users.length;
      });
    } catch (e) {
      print('Erreur lors du chargement des données de la top bar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.8),
            AppTheme.primaryColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne supérieure avec titre et actions
              Row(
                children: [
                  // Logo et nom de l'école
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _ecoleInfo != null && _ecoleInfo!['logo'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    _ecoleInfo!['logo'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.school, color: AppTheme.primaryColor),
                                  ),
                                )
                              : const Icon(Icons.school, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ecoleInfo?['nom'] ?? 'Gestion Scolaire',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Année: ${_anneeScolaire?['libelle'] ?? 'Non définie'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Actions à droite
                  Row(
                    children: [
                      if (widget.onRefreshPressed != null)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: widget.onRefreshPressed,
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: 'Actualiser',
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: widget.onSettingsPressed,
                          icon: const Icon(Icons.settings, color: Colors.white),
                          tooltip: 'Paramètres',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Ligne inférieure avec les 4 informations
              Row(
                children: [
                  Expanded(
                    child: _buildInfoBox(
                      'École',
                      _ecoleInfo?['nom'] ?? 'Non configurée',
                      Icons.business,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoBox(
                      'Année Scolaire',
                      _anneeScolaire?['libelle'] ?? 'Non définie',
                      Icons.calendar_today,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoBox(
                      'Configuration',
                      'Paramètres système',
                      Icons.settings,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoBox(
                      'Utilisateurs',
                      '$_userCount utilisateur${_userCount > 1 ? 's' : ''}',
                      Icons.people,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
