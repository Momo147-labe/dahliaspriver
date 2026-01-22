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
  List<Map<String, dynamic>> _cyclesWithLevels = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cycles = await _db.getCyclesScolaires();
      List<Map<String, dynamic>> enrichedCycles = [];

      for (var cycle in cycles) {
        final levels = await _db.getNiveauxByCycle(cycle['id']);
        enrichedCycles.add({...cycle, 'niveaux': levels});
      }

      setState(() {
        _cyclesWithLevels = enrichedCycles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cycle data: $e');
      setState(() => _isLoading = false);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycles & Niveaux',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF121717),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configurez les cycles scolaires et les niveaux rattachés.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCycleDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Nouveau Cycle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          if (_cyclesWithLevels.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Column(
                  children: [
                    Icon(
                      Icons.layers_clear_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun cycle configuré',
                      style: TextStyle(color: Colors.grey[500], fontSize: 18),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cyclesWithLevels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final cycle = _cyclesWithLevels[index];
                return _buildCycleCard(cycle, isDark);
              },
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCycleCard(Map<String, dynamic> cycle, bool isDark) {
    final levels = cycle['niveaux'] as List<Map<String, dynamic>>;
    final color = AppTheme.primaryColor;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du Cycle
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.school, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cycle['nom'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Notes ${cycle['note_min']} à ${cycle['note_max']} • Moyenne passage: ${cycle['moyenne_passage']}/20',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if ((cycle['is_terminal'] ?? 0) == 1)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Terminal',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _showAddCycleDialog(cycle: cycle),
                  icon: const Icon(Icons.edit_outlined),
                  color: color,
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Supprimer le cycle ?'),
                        content: const Text(
                          'Cette action désactivera le cycle et ses niveaux associés.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ANNULER'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'SUPPRIMER',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _db.deleteCycleScolaire(cycle['id']);
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red[300],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste des niveaux
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NIVEAUX CONFIGURÉS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _showAddLevelDialog(cycleId: cycle['id']),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('AJOUTER UN NIVEAU'),
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (levels.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[900]!.withOpacity(0.3)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Aucun niveau n\'a été ajouté à ce cycle.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: levels
                        .map((lvl) => _buildLevelCard(lvl, isDark))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> lvl, bool isDark) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
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
              Expanded(
                child: Text(
                  lvl['nom'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((lvl['is_examen'] ?? 0) == 1)
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 14,
                  color: Colors.blue,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lvl['moyenne_passage'] != null
                ? 'Seuil: ${lvl['moyenne_passage']}/20'
                : 'Seuil hérité',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () =>
                    _showAddLevelDialog(cycleId: lvl['cycle_id'], level: lvl),
                icon: const Icon(Icons.edit_outlined, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  await _db.deleteNiveau(lvl['id']);
                  _loadData();
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                color: Colors.red[300],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddCycleDialog({Map<String, dynamic>? cycle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: (cycle?['nom'] ?? '').toString(),
    );
    final ordreController = TextEditingController(
      text: (cycle?['ordre'] ?? '').toString(),
    );
    final minController = TextEditingController(
      text: (cycle?['note_min'] ?? 0).toString(),
    );
    final maxController = TextEditingController(
      text: (cycle?['note_max'] ?? 20).toString(),
    );
    final moyController = TextEditingController(
      text: (cycle?['moyenne_passage'] ?? 10.0).toString(),
    );
    bool isTerminal = (cycle?['is_terminal'] ?? 0) == 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(28),
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
                      Text(
                        cycle == null ? 'Nouveau Cycle' : 'Modifier le Cycle',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      _buildDialogTextField(
                        controller: nameController,
                        label: 'NOM DU CYCLE',
                        hint: 'Ex: Primaire',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogTextField(
                              controller: ordreController,
                              label: 'ORDRE',
                              hint: '1',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogTextField(
                              controller: moyController,
                              label: 'MOYENNE PASSAGE',
                              hint: '10.0',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogTextField(
                              controller: minController,
                              label: 'NOTE MIN',
                              hint: '0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogTextField(
                              controller: maxController,
                              label: 'NOTE MAX',
                              hint: '20',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text(
                          'Cycle Terminal (Fin de scolarité)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: isTerminal,
                        onChanged: (v) => setDialogState(() => isTerminal = v),
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ANNULER'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final data = {
                              'nom': nameController.text,
                              'ordre': int.tryParse(ordreController.text) ?? 1,
                              'note_min':
                                  double.tryParse(minController.text) ?? 0.0,
                              'note_max':
                                  double.tryParse(maxController.text) ?? 20.0,
                              'moyenne_passage':
                                  double.tryParse(moyController.text) ?? 10.0,
                              'is_terminal': isTerminal ? 1 : 0,
                            };
                            if (cycle != null) {
                              await _db.updateCycleScolaire(cycle['id'], data);
                            } else {
                              await _db.saveCycleScolaire(data);
                            }
                            Navigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(cycle == null ? 'CRÉER' : 'ENREGISTRER'),
                        ),
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

  void _showAddLevelDialog({
    required int cycleId,
    Map<String, dynamic>? level,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: (level?['nom'] ?? '').toString(),
    );
    final ordreController = TextEditingController(
      text: (level?['ordre'] ?? '').toString(),
    );
    final moyController = TextEditingController(
      text: (level?['moyenne_passage']?.toString() ?? ''),
    );
    bool isExamen = (level?['is_examen'] ?? 0) == 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 450,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      Text(
                        level == null ? 'Nouveau Niveau' : 'Modifier le Niveau',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      _buildDialogTextField(
                        controller: nameController,
                        label: 'NOM DU NIVEAU',
                        hint: 'Ex: CM2',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogTextField(
                              controller: ordreController,
                              label: 'ORDRE GLOBAL',
                              hint: '1',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogTextField(
                              controller: moyController,
                              label: 'SEUIL SPÉCIFIQUE (Optionnel)',
                              hint: 'Ex: 12.0',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text(
                          'Classe d\'examen',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: isExamen,
                        onChanged: (v) => setDialogState(() => isExamen = v),
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ANNULER'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final data = {
                              'id': level?['id'],
                              'nom': nameController.text,
                              'ordre': int.tryParse(ordreController.text) ?? 1,
                              'cycle_id': cycleId,
                              'moyenne_passage': double.tryParse(
                                moyController.text,
                              ),
                              'is_examen': isExamen ? 1 : 0,
                            };
                            await _db.saveNiveau(data);
                            Navigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            level == null ? 'AJOUTER' : 'ENREGISTRER',
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
}
