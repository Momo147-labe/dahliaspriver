import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';

class CycleLevelSettingsPage extends StatefulWidget {
  const CycleLevelSettingsPage({super.key});

  @override
  State<CycleLevelSettingsPage> createState() => _CycleLevelSettingsPageState();
}

class _CycleLevelSettingsPageState extends State<CycleLevelSettingsPage> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cycles = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cycles = await _db.getCyclesScolaires();
      setState(() {
        _cycles = cycles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cycle data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCycleField(int id, String field, dynamic value) async {
    try {
      await _db.updateCycleScolaire(id, {field: value});
      // Optionally reload or just update local state
    } catch (e) {
      debugPrint('Error updating cycle field: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la page
          Text(
            'Cycles & Niveaux de Passage',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF121717),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configurez les cycles scolaires, les niveaux rattachés et les conditions de réussite pour chaque étape académique.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Section principale (Tableau Premium)
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header du tableau
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.rule_folder,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gestion des Cycles & Niveaux',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Définissez les paliers et critères de transition',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCycleDialog(),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Nouveau Cycle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.15,
                          ),
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tableau
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: theme.copyWith(
                      dividerColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    ),
                    child: DataTable(
                      horizontalMargin: 24,
                      columnSpacing: 40,
                      headingRowColor: MaterialStateProperty.all(
                        isDark
                            ? Colors.grey[900]!.withOpacity(0.3)
                            : Colors.grey[50]!,
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                      ),
                      columns: const [
                        DataColumn(label: Text('CYCLE SCOLAIRE')),
                        DataColumn(label: Text('NIVEAUX ASSOCIÉS')),
                        DataColumn(label: Text('MOYENNE PASSAGE')),
                        DataColumn(label: Text('DROIT REDOUBLEMENT')),
                        DataColumn(label: Text('SEUIL')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: _cycles.map((cycle) {
                        return _buildDataRow(cycle, isDark);
                      }).toList(),
                    ),
                  ),
                ),

                // Footer du tableau
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[900]!.withOpacity(0.3)
                        : Colors.grey[50]!,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dernière mise à jour effectuée le ${_getLastUpdateDate()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[500],
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _loadData,
                            child: const Text('RÉINITIALISER'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Section validée et enregistrée',
                                  ),
                                ),
                              );
                            },
                            child: const Text('VALIDER LA SECTION'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Info Cards du bas (Infos Institutionnelles & Notation)
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.branding_watermark,
                  title: 'Infos Institutionnelles',
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'La Renaissance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'GNE-CON-2024-X8',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.percent,
                  title: 'Système de Notation',
                  child: Row(
                    children: [
                      _buildPill('Sur 10', true),
                      const SizedBox(width: 8),
                      _buildPill('Sur 20', false),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> cycle, bool isDark) {
    final nom = (cycle['nom_cycle'] ?? '').toString();
    final sousTitre = (cycle['sous_titre_cycle'] ?? 'Éducation').toString();
    final min = cycle['niveau_min'] ?? 1;
    final max = cycle['niveau_max'] ?? 6;
    final id = cycle['id'];
    final moyPassage = (cycle['moyenne_passage_cycle'] ?? 10.0) as double;
    final droitRedoublement = (cycle['droit_redoublement'] ?? 1) == 1;
    final seuilRedoublement = (cycle['seuil_redoublement'] ?? 8.0) as double;

    // Détermination de l'icône selon le cycle
    IconData iconData = Icons.school;
    Color iconBg = Colors.blue.withOpacity(0.1);
    Color iconColor = Colors.blue;

    if (nom.toLowerCase().contains('maternelle') ||
        nom.toLowerCase().contains('préscolaire')) {
      iconData = Icons.child_care;
      iconBg = Colors.orange.withOpacity(0.1);
      iconColor = Colors.orange;
    } else if (nom.toLowerCase().contains('collège')) {
      iconData = Icons.architecture;
      iconBg = Colors.teal.withOpacity(0.1);
      iconColor = Colors.teal;
    } else if (nom.toLowerCase().contains('lycée')) {
      iconData = Icons.workspace_premium;
      iconBg = Colors.purple.withOpacity(0.1);
      iconColor = Colors.purple;
    }

    return DataRow(
      cells: [
        // Cycle Scolaire
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    sousTitre.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Niveaux Associés
        DataCell(
          SizedBox(
            width: 180,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._generateLevelBadges(min, max),
                _buildAddLevelButton(),
              ],
            ),
          ),
        ),
        // Moyenne Passage
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 40,
                child: TextField(
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  controller: TextEditingController(
                    text: moyPassage.toStringAsFixed(1),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (v) => _updateCycleField(
                    id,
                    'moyenne_passage_cycle',
                    double.tryParse(v) ?? 10.0,
                  ),
                ),
              ),
              const Text(
                '/20',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        // Droit Redoublement
        DataCell(
          Switch(
            value: droitRedoublement,
            onChanged: (v) {
              setState(() {
                _updateCycleField(id, 'droit_redoublement', v ? 1 : 0);
                _loadData();
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
        ),
        // Seuil
        DataCell(
          SizedBox(
            width: 60,
            height: 40,
            child: TextField(
              textAlign: TextAlign.center,
              enabled: droitRedoublement,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: !droitRedoublement,
                fillColor: Colors.grey[100],
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: droitRedoublement ? null : Colors.grey,
              ),
              controller: TextEditingController(
                text: seuilRedoublement.toStringAsFixed(1),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (v) => _updateCycleField(
                id,
                'seuil_redoublement',
                double.tryParse(v) ?? 8.0,
              ),
            ),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showLevelManagementDialog(cycle),
                icon: const Icon(Icons.list_alt, size: 20),
                color: Colors.grey[400],
                hoverColor: AppTheme.primaryColor.withOpacity(0.05),
                padding: EdgeInsets.zero,
                tooltip: 'Gérer les niveaux',
              ),
              IconButton(
                onPressed: () => _showAddCycleDialog(cycle: cycle),
                icon: const Icon(Icons.edit_note, size: 20),
                color: Colors.grey[400],
                hoverColor: AppTheme.primaryColor.withOpacity(0.05),
                padding: EdgeInsets.zero,
                tooltip: 'Modifier le cycle',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _generateLevelBadges(int min, int max) {
    List<Widget> badges = [];
    for (int i = min; i <= max; i++) {
      badges.add(_buildLevelBadge(i.toString()));
    }
    return badges;
  }

  Widget _buildLevelBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[200]!,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildAddLevelButton() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: const Icon(Icons.add, size: 12, color: AppTheme.primaryColor),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Icon(Icons.open_in_new, color: Colors.grey[400], size: 16),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPill(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primaryColor.withOpacity(0.1)
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: active ? AppTheme.primaryColor : Colors.grey[500],
        ),
      ),
    );
  }

  String _getLastUpdateDate() {
    // Dans un vrai projet, on récupèrerait cela des données
    return '24 Octobre 2024';
  }

  void _showAddCycleDialog({Map<String, dynamic>? cycle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: (cycle?['nom_cycle'] ?? '').toString(),
    );
    final sousTitreController = TextEditingController(
      text: (cycle?['sous_titre_cycle'] ?? '').toString(),
    );
    final codeController = TextEditingController(
      text: (cycle?['code_cycle'] ?? '').toString(),
    );
    final minController = TextEditingController(
      text: (cycle?['niveau_min'] ?? 1).toString(),
    );
    final maxController = TextEditingController(
      text: (cycle?['niveau_max'] ?? 6).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header du Dialog
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.settings_suggest,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cycle == null ? 'Nouveau Cycle' : 'Modifier le Cycle',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Configurez les paramètres du cycle scolaire',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),

              // Contenu du Dialog
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    _buildDialogTextField(
                      controller: nameController,
                      label: 'NOM DU CYCLE',
                      hint: 'Ex: Enseignement Primaire',
                      icon: Icons.label_important_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: sousTitreController,
                      label: 'SOUS-TITRE',
                      hint: 'Ex: Éducation de base',
                      icon: Icons.subtitles_outlined,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            controller: codeController,
                            label: 'CODE',
                            hint: 'Ex: PRIM',
                            icon: Icons.code,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDialogTextField(
                                  controller: minController,
                                  label: 'MIN',
                                  hint: '1',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDialogTextField(
                                  controller: maxController,
                                  label: 'MAX',
                                  hint: '6',
                                  keyboardType: TextInputType.number,
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

              // Actions du Dialog
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'ANNULER',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final newCycle = {
                            'nom_cycle': nameController.text,
                            'sous_titre_cycle': sousTitreController.text,
                            'code_cycle': codeController.text,
                            'niveau_min': int.tryParse(minController.text) ?? 1,
                            'niveau_max': int.tryParse(maxController.text) ?? 6,
                            'ordre_cycle': (cycle?['ordre_cycle'] ?? 1),
                          };
                          if (cycle != null) {
                            await _db.updateCycleScolaire(
                              cycle['id'],
                              newCycle,
                            );
                          } else {
                            await _db.saveCycleScolaire(newCycle);
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cycle == null ? 'CRÉER LE CYCLE' : 'METTRE À JOUR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
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

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: AppTheme.primaryColor.withOpacity(0.5),
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _showLevelManagementDialog(Map<String, dynamic> cycle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nom = cycle['nom_cycle'];
    final min = cycle['niveau_min'] ?? 1;
    final max = cycle['niveau_max'] ?? 6;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 450,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.format_list_bulleted,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niveaux - $nom',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Gérez la liste des niveaux rattachés',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),

              // Liste des niveaux
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NIVEAUX ACTUELS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        max - min + 1,
                        (index) => _buildManageLevelChip(
                          (min + index).toString(),
                          isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'CONFIGURER LA PLAGE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            controller: TextEditingController(
                              text: min.toString(),
                            ),
                            label: 'DE',
                            hint: '1',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogTextField(
                            controller: TextEditingController(
                              text: max.toString(),
                            ),
                            label: 'À',
                            hint: '6',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'FERMER',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCycleDialog(cycle: cycle);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('AJUSTER LA PLAGE'),
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

  Widget _buildManageLevelChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Icon(Icons.remove_circle_outline, size: 14, color: Colors.red[300]),
        ],
      ),
    );
  }
}
