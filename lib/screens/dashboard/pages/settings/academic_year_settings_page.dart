import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';

class AcademicYearSettingsPage extends StatefulWidget {
  const AcademicYearSettingsPage({super.key});

  @override
  State<AcademicYearSettingsPage> createState() =>
      _AcademicYearSettingsPageState();
}

class _AcademicYearSettingsPageState extends State<AcademicYearSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _yearNameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _academicYears = [];
  int? _editingYearId;
  int? _selectedPreviousYearId;
  String _etat = 'EN_COURS';

  @override
  void initState() {
    super.initState();
    _loadAcademicYears();
  }

  @override
  void dispose() {
    _yearNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicYears() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final years = await db.query(
        'annee_scolaire',
        orderBy: 'date_debut DESC',
      );
      setState(() {
        _academicYears = years;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveAcademicYear() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les dates de début et de fin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final data = {
        'libelle': _yearNameController.text,
        'date_debut': DateFormat('yyyy-MM-dd').format(_startDate!),
        'date_fin': DateFormat('yyyy-MM-dd').format(_endDate!),
        'active': _isActive ? 1 : 0,
        'etat': _etat,
        'annee_precedente_id': _selectedPreviousYearId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      int savedId;
      if (_editingYearId != null) {
        // Mise à jour
        savedId = _editingYearId!;
        await db.update(
          'annee_scolaire',
          data,
          where: 'id = ?',
          whereArgs: [savedId],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Année scolaire modifiée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Création
        data['created_at'] = DateTime.now().toIso8601String();
        savedId = await db.insert('annee_scolaire', data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Année scolaire ajoutée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Si l'année est marquée comme active, désactiver les autres
      if (_isActive) {
        await db.update(
          'annee_scolaire',
          {'active': 0},
          where: 'id != ?',
          whereArgs: [savedId],
        );
        await DatabaseHelper.instance.ensureActiveAnneeCached(
          forceRefresh: true,
        );
      }

      _resetForm();
      _loadAcademicYears();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Refined helper to get ID on insert.
  // ...

  Future<void> _deleteAcademicYear(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette année scolaire ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('annee_scolaire', where: 'id = ?', whereArgs: [id]);
        _loadAcademicYears();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Année scolaire supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _editAcademicYear(Map<String, dynamic> year) {
    setState(() {
      _editingYearId = year['id'] as int;
      _yearNameController.text = year['libelle'] as String;
      _startDate = DateTime.parse(year['date_debut'] as String);
      _endDate = DateTime.parse(year['date_fin'] as String);
      _isActive = (year['active'] == 1);
      _etat = year['etat'] ?? 'EN_COURS'; // Default if null
      _selectedPreviousYearId = year['annee_precedente_id'] as int?;
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _yearNameController.clear();
      _startDate = null;
      _endDate = null;
      _isActive = false;
      _etat = 'EN_COURS';
      _editingYearId = null;
      _selectedPreviousYearId = null;
    });
  }

  void _showAddYearDialog({Map<String, dynamic>? year}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (year != null) {
      _editAcademicYear(year);
    } else {
      _resetForm();
    }

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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            year == null
                                ? 'Nouvelle Année'
                                : 'Modifier l\'Année',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Définissez la période académique',
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

                // Content
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildDialogTextField(
                          controller: _yearNameController,
                          label: 'LIBELLÉ DE L\'ANNÉE',
                          hint: 'Ex: 2024-2025',
                          icon: Icons.label_outline,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'DATE DÉBUT',
                                date: _startDate,
                                icon: Icons.event_available,
                                onTap: () async {
                                  final d = await _selectDateDialog(context);
                                  if (d != null) {
                                    setDialogState(() => _startDate = d);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'DATE FIN',
                                date: _endDate,
                                icon: Icons.event_busy,
                                onTap: () async {
                                  final d = await _selectDateDialog(context);
                                  if (d != null) {
                                    setDialogState(() => _endDate = d);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Dropdown for Previous Year
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ANNÉE PRÉCÉDENTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedPreviousYearId,
                                  isExpanded: true,
                                  hint: const Text(
                                    'Sélectionner l\'année précédente',
                                  ),
                                  items: _academicYears
                                      .where((y) => y['id'] != _editingYearId)
                                      .map(
                                        (y) => DropdownMenuItem<int>(
                                          value: y['id'] as int,
                                          child: Text(y['libelle'] as String),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    setDialogState(
                                      () => _selectedPreviousYearId = val,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Dropdown for Etat
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ÉTAT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _etat,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'EN_COURS',
                                      child: Text('En Cours'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'TERMINEE',
                                      child: Text('Terminée'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => _etat = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DÉFINIR COMME ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    'L\'année scolaire par défaut',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Switch(
                                value: _isActive,
                                onChanged: (v) =>
                                    setDialogState(() => _isActive = v),
                                activeColor: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
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
                            await _saveAcademicYear();
                            if (mounted) Navigator.pop(context);
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
                            year == null ? 'CRÉER L\'ANNÉE' : 'METTRE À JOUR',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
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
      ),
    );
  }

  Future<DateTime?> _selectDateDialog(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
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
                  color: AppTheme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : '--/--/----',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
        TextFormField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Années Scolaires',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF121717),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configurez et gérez les cycles annuels de votre établissement.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddYearDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('NOUVELLE ANNÉE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Main Content Card (Table)
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
                // Table Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Historique des Périodes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dynamic Table
                SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    horizontalMargin: 24,
                    columnSpacing: 40,
                    headingRowColor: MaterialStateProperty.all(
                      isDark
                          ? Colors.grey[900]!.withOpacity(0.3)
                          : Colors.grey[50]!,
                    ),
                    columns: const [
                      DataColumn(label: Text('STATUT')),
                      DataColumn(label: Text('LIBELLÉ')),
                      DataColumn(label: Text('ÉTAT')),
                      DataColumn(label: Text('PÉRIODE')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: _academicYears.map((year) {
                      final isActive = year['active'] == 1;
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              year['libelle'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              year['etat'] ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${DateFormat('dd MMM yyyy').format(DateTime.parse(year['date_debut']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(year['date_fin']))}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _showAddYearDialog(year: year),
                                  icon: const Icon(Icons.edit_note),
                                  color: Colors.blue[400],
                                  tooltip: 'Modifier',
                                ),
                                if (!isActive)
                                  IconButton(
                                    onPressed: () =>
                                        _deleteAcademicYear(year['id'] as int),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red[300],
                                    tooltip: 'Supprimer',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
