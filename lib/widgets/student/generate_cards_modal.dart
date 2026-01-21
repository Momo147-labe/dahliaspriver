import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/database/database_helper.dart';
import '../../utils/pdf/student_id_card_template.dart';
import '../../utils/pdf/withdrawal_card_template.dart';
import 'package:intl/intl.dart';

class GenerateCardsModal extends StatefulWidget {
  const GenerateCardsModal({super.key});

  @override
  State<GenerateCardsModal> createState() => _GenerateCardsModalState();
}

class _GenerateCardsModalState extends State<GenerateCardsModal> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _cardType = 'id'; // 'id' or 'withdrawal'
  String _scope = 'single'; // 'single' or 'class'

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];

  int? _selectedStudentId;
  int? _selectedClassId;

  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final db = await _dbHelper.database;

      // Load students
      final students = await db.rawQuery(
        '''
        SELECT e.*, c.nom as classe_nom
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        WHERE e.annee_scolaire_id = ?
        ORDER BY e.nom, e.prenom
      ''',
        [anneeId],
      );

      // Load classes
      final classes = await db.rawQuery(
        '''
        SELECT DISTINCT c.*
        FROM classe c
        INNER JOIN eleve e ON e.classe_id = c.id
        WHERE e.annee_scolaire_id = ?
        ORDER BY c.nom
      ''',
        [anneeId],
      );

      setState(() {
        _students = students;
        _classes = classes;
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

  Future<void> _generateCards() async {
    if (_scope == 'single' && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un élève')),
      );
      return;
    }

    if (_scope == 'class' && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une classe')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Get school info
      final db = await _dbHelper.database;
      final schoolInfo = await db.query('ecole', limit: 1);

      String schoolName = 'GUINEE ECOLE INTERNATIONALE';
      String schoolCountry = 'RÉPUBLIQUE DE GUINÉE';
      String? schoolLogoPath;

      if (schoolInfo.isNotEmpty) {
        schoolName = schoolInfo.first['nom']?.toString() ?? schoolName;
        schoolLogoPath = schoolInfo.first['logo']?.toString();
      }

      // Get active year for academic year display
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      final anneeInfo = await db.query(
        'annee_scolaire',
        where: 'id = ?',
        whereArgs: [anneeId],
      );
      String academicYear = '2023-2024';
      if (anneeInfo.isNotEmpty) {
        academicYear = anneeInfo.first['libelle']?.toString() ?? academicYear;
      }

      // Determine which students to generate cards for
      List<Map<String, dynamic>> targetStudents = [];
      if (_scope == 'single') {
        targetStudents = _students
            .where((s) => s['id'] == _selectedStudentId)
            .toList();
      } else {
        targetStudents = _students
            .where((s) => s['classe_id'] == _selectedClassId)
            .toList();
      }

      if (targetStudents.isEmpty) {
        throw Exception('Aucun élève trouvé');
      }

      // Generate PDF based on card type
      if (_cardType == 'id') {
        await _generateIdCards(
          targetStudents,
          schoolName,
          schoolCountry,
          academicYear,
          schoolLogoPath,
        );
      } else {
        await _generateWithdrawalCards(targetStudents);
      }

      setState(() => _isGenerating = false);
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateIdCards(
    List<Map<String, dynamic>> students,
    String schoolName,
    String schoolCountry,
    String academicYear,
    String? schoolLogoPath,
  ) async {
    for (var student in students) {
      final studentName = '${student['prenom']} ${student['nom']}';
      final birthDate = student['date_naissance']?.toString() ?? 'N/A';
      final className = student['classe_nom']?.toString() ?? 'N/A';
      final matricule = student['matricule']?.toString() ?? 'N/A';
      final photoPath = student['photo']?.toString();

      // Format birth date
      String formattedBirthDate = birthDate;
      if (birthDate != 'N/A') {
        try {
          final date = DateTime.parse(birthDate);
          formattedBirthDate = DateFormat('dd/MM/yyyy').format(date);
        } catch (_) {}
      }

      final pdf = await StudentIdCardTemplate.generate(
        schoolName: schoolName,
        schoolCountry: schoolCountry,
        academicYear: academicYear,
        studentName: studentName,
        birthDate: formattedBirthDate,
        className: className,
        studentId: matricule,
        studentPhotoPath: photoPath,
        schoolLogoPath: schoolLogoPath,
        parentName: 'Parent/Tuteur', // TODO: Add parent table to database
        parentPhone: '+224 XXX XX XX XX', // TODO: Fetch from parent table
      );

      // Show print preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Carte_${studentName.replaceAll(' ', '_')}.pdf',
      );
    }
  }

  Future<void> _generateWithdrawalCards(
    List<Map<String, dynamic>> students,
  ) async {
    for (var student in students) {
      final studentName = '${student['prenom']} ${student['nom']}';
      final photoPath = student['photo']?.toString();

      // For now, use placeholder data for parent info
      // TODO: Add parent/guardian table to database
      final pdf = await WithdrawalCardTemplate.generate(
        studentName: studentName,
        unitCode: 'A-102',
        authorizedParentName: 'Mme. Parent Autorisé',
        otherAuthorizedPersons: ['Personne 1 (Père)', 'Personne 2 (Tante)'],
        studentPhotoPath: photoPath,
      );

      // Show print preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Autorisation_${studentName.replaceAll(' ', '_')}.pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  _buildCardTypeSelector(isDark),
                  const SizedBox(height: 24),
                  _buildScopeSelector(isDark),
                  const SizedBox(height: 24),
                  _buildTargetSelector(isDark),
                  const SizedBox(height: 32),
                  _buildActions(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C3C3), Color(0xFF1A9B9B)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Générer des Cartes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                'Créez des cartes d\'élève ou d\'autorisation de retrait',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildCardTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de carte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOptionCard(
                title: 'Carte d\'Élève',
                subtitle: 'Identification officielle',
                icon: Icons.badge,
                color: const Color(0xFF22C3C3),
                isSelected: _cardType == 'id',
                onTap: () => setState(() => _cardType = 'id'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionCard(
                title: 'Autorisation de Retrait',
                subtitle: 'Sécurité scolaire',
                icon: Icons.verified_user,
                color: const Color(0xFFFF9966),
                isSelected: _cardType == 'withdrawal',
                onTap: () => setState(() => _cardType = 'withdrawal'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScopeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portée',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Un élève'),
                value: 'single',
                groupValue: _scope,
                onChanged: (value) => setState(() {
                  _scope = value!;
                  _selectedClassId = null;
                }),
                activeColor: const Color(0xFF22C3C3),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Toute une classe'),
                value: 'class',
                groupValue: _scope,
                onChanged: (value) => setState(() {
                  _scope = value!;
                  _selectedStudentId = null;
                }),
                activeColor: const Color(0xFF22C3C3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetSelector(bool isDark) {
    if (_scope == 'single') {
      return DropdownButtonFormField<int>(
        value: _selectedStudentId,
        decoration: InputDecoration(
          labelText: 'Sélectionner un élève',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF374151) : Colors.grey[100],
        ),
        items: _students.map((student) {
          return DropdownMenuItem<int>(
            value: student['id'] as int,
            child: Text(
              '${student['prenom']} ${student['nom']} - ${student['classe_nom']}',
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedStudentId = value),
      );
    } else {
      return DropdownButtonFormField<int>(
        value: _selectedClassId,
        decoration: InputDecoration(
          labelText: 'Sélectionner une classe',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF374151) : Colors.grey[100],
        ),
        items: _classes.map((classe) {
          final studentCount = _students
              .where((s) => s['classe_id'] == classe['id'])
              .length;
          return DropdownMenuItem<int>(
            value: classe['id'] as int,
            child: Text('${classe['nom']} ($studentCount élèves)'),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedClassId = value),
      );
    }
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : (isDark ? const Color(0xFF374151) : Colors.grey[100]),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white : Colors.black),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : _generateCards,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.print),
          label: Text(_isGenerating ? 'Génération...' : 'Générer et Imprimer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C3C3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
