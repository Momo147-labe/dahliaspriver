import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _ecoleInfo;
  Map<String, dynamic>? _anneeScolaire;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Charger les informations de l'école
      final ecoles = await db.query('ecole');
      final annees = await db.query('annee_scolaire', orderBy: 'created_at DESC', limit: 1);
      final users = await db.query('user');
      
      setState(() {
        _ecoleInfo = ecoles.isNotEmpty ? ecoles.first : null;
        _anneeScolaire = annees.isNotEmpty ? annees.first : null;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section École
                  _buildSection(
                    'Informations de l\'École',
                    Icons.school,
                    [
                      _buildInfoCard(
                        'Nom de l\'école',
                        _ecoleInfo?['nom'] ?? 'Non défini',
                        Icons.business,
                      ),
                      _buildInfoCard(
                        'Fondateur',
                        _ecoleInfo?['fondateur'] ?? 'Non défini',
                        Icons.person,
                      ),
                      _buildInfoCard(
                        'Directeur',
                        _ecoleInfo?['directeur'] ?? 'Non défini',
                        Icons.admin_panel_settings,
                      ),
                      _buildInfoCard(
                        'Téléphone',
                        _ecoleInfo?['telephone'] ?? 'Non défini',
                        Icons.phone,
                      ),
                      _buildInfoCard(
                        'Email',
                        _ecoleInfo?['email'] ?? 'Non défini',
                        Icons.email,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Section Année Scolaire
                  _buildSection(
                    'Année Scolaire Active',
                    Icons.calendar_today,
                    [
                      _buildInfoCard(
                        'Libellé',
                        _anneeScolaire?['libelle'] ?? 'Non défini',
                        Icons.label,
                      ),
                      _buildInfoCard(
                        'Statut',
                        _anneeScolaire?['statut'] ?? 'Non défini',
                        Icons.info,
                      ),
                      _buildInfoCard(
                        'Date de début',
                        _anneeScolaire?['date_debut'] ?? 'Non défini',
                        Icons.play_arrow,
                      ),
                      _buildInfoCard(
                        'Date de fin',
                        _anneeScolaire?['date_fin'] ?? 'Non défini',
                        Icons.stop,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Section Utilisateurs
                  _buildSection(
                    'Utilisateurs',
                    Icons.people,
                    [
                      ..._users.map((user) => _buildUserCard(user)).toList(),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddUserDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un utilisateur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.cardDark
            : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.cardDark
            : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              user['pseudo']?.toString().substring(0, 2).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['pseudo']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user['role']?.toString()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getRoleLabel(user['role']?.toString()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditUserDialog(user);
              } else if (value == 'delete') {
                _showDeleteUserDialog(user);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'enseignant':
        return Colors.blue;
      case 'comptable':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'enseignant':
        return 'Enseignant';
      case 'comptable':
        return 'Comptable';
      default:
        return 'Inconnu';
    }
  }

  void _showAddUserDialog() {
    // TODO: Implémenter l'ajout d'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajout d\'utilisateur à implémenter')),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    // TODO: Implémenter la modification d'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification d\'utilisateur à implémenter')),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer l\'utilisateur ${user['pseudo']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final db = await DatabaseHelper.instance.database;
                await db.delete('user', where: 'id = ?', whereArgs: [user['id']]);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Utilisateur supprimé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
