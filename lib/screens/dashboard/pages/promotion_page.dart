import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class PromotionPage extends StatefulWidget {
  const PromotionPage({super.key});

  @override
  State<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends State<PromotionPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = false;

  // Filter state
  List<Map<String, dynamic>> _annees = [];
  int? _oldAnneeId;
  int? _newAnneeId;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _destClasses = [];
  int? _oldClasseId;
  int? _newClasseId;
  int? _nextNiveauId;

  // Students list with averages
  List<Map<String, dynamic>> _students = [];
  Set<int> _selectedAdmisIds = {};
  Set<int> _selectedRedoublantIds = {};

  // Cycle pass mark
  double _moyennePassage = 10.0;
  double _noteMax = 20.0;
  bool _isFinalClass = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      _annees = await db.query('annee_scolaire', orderBy: 'date_debut DESC');

      if (_annees.isNotEmpty) {
        // Default: newest year is the destination
        _newAnneeId = _annees.first['id'];
        // Use annee_precedente_id to auto-select the source year
        final prevId = _annees.first['annee_precedente_id'];
        if (prevId != null) {
          _oldAnneeId = prevId as int;
        } else if (_annees.length > 1) {
          _oldAnneeId = _annees[1]['id'];
        } else {
          _oldAnneeId = _annees.first['id'];
        }
      }

      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClasses() async {
    if (_oldAnneeId == null) return;
    try {
      _classes = await _dbHelper.classeDao.getClassesByAnnee(_oldAnneeId!);
      if (_classes.isNotEmpty) {
        _oldClasseId = _classes.first['id'];
        // Charger les classes de destination basées sur le niveau
        await _resolveDestinationClasses(_oldClasseId!);
        await _loadStudentsWithAverages();
      } else {
        _oldClasseId = null;
        _newClasseId = null;
        _destClasses = [];
        _students = [];
        _selectedAdmisIds.clear();
        _selectedRedoublantIds.clear();
      }
      setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// Résout les classes de destination via le lien entre niveaux
  Future<void> _resolveDestinationClasses(int sourceClasseId) async {
    final db = await _dbHelper.database;
    setState(() {
      _destClasses = [];
      _nextNiveauId = null;
      _newClasseId = null;
    });

    // 1. Trouver le niveau de la classe source
    final sourceResult = await db.query(
      'classe',
      columns: ['niveau_id'],
      where: 'id = ?',
      whereArgs: [sourceClasseId],
    );

    if (sourceResult.isNotEmpty && sourceResult.first['niveau_id'] != null) {
      int niveauId = sourceResult.first['niveau_id'] as int;

      // 2. Trouver le niveau suivant
      final niveauResult = await db.query(
        'niveaux',
        columns: ['next_niveau_id'],
        where: 'id = ?',
        whereArgs: [niveauId],
      );

      if (niveauResult.isNotEmpty &&
          niveauResult.first['next_niveau_id'] != null) {
        _nextNiveauId = niveauResult.first['next_niveau_id'] as int;

        // 3. Charger les classes de ce niveau
        _destClasses = await _dbHelper.classeDao.getClassesByNiveau(
          _nextNiveauId!,
        );

        if (_destClasses.isNotEmpty) {
          _newClasseId = _destClasses.first['id'];
        } else {
          _newClasseId = null;
        }
      } else {
        // Pas de niveau suivant défini (classe finale ?)
        _nextNiveauId = null;
        _destClasses = [];
        _newClasseId = null;
      }
    }
  }

  Future<void> _loadStudentsWithAverages() async {
    if (_oldClasseId == null || _oldAnneeId == null) return;
    setState(() => _isLoading = true);
    try {
      // 1. Get the moyenne_passage, note_max and is_final_class from the cycle linked to the class
      final db = await _dbHelper.database;
      final cycleResult = await db.rawQuery(
        '''SELECT cy.moyenne_passage, cy.note_max, c.is_final_class 
           FROM classe c 
           JOIN cycles_scolaires cy ON c.cycle_id = cy.id 
           WHERE c.id = ?''',
        [_oldClasseId],
      );
      if (cycleResult.isNotEmpty) {
        _moyennePassage =
            (cycleResult.first['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
        _noteMax = (cycleResult.first['note_max'] as num?)?.toDouble() ?? 20.0;
        _isFinalClass = cycleResult.first['is_final_class'] == 1;
      } else {
        _moyennePassage = 10.0;
        _noteMax = 20.0;
        _isFinalClass = false;
      }

      // 2. Get students
      final rawStudents = await _dbHelper.eleveDao.getElevesByClasse(
        _oldClasseId!,
        _oldAnneeId!,
      );

      // 3. Calculate average for each student
      final studentsWithAvg = <Map<String, dynamic>>[];
      for (var student in rawStudents) {
        final moyenne = await _dbHelper.notesDao.calculerMoyenneGenerale(
          student['id'] as int,
          _oldAnneeId!,
        );
        studentsWithAvg.add({
          ...student,
          'moyenne': moyenne,
          'isAdmis': moyenne >= _moyennePassage,
        });
      }

      // Sort by average descending
      studentsWithAvg.sort(
        (a, b) => (b['moyenne'] as double).compareTo(a['moyenne'] as double),
      );

      _students = studentsWithAvg;

      // Auto-select: admis go to promotion, redoublants go to redoublement
      _selectedAdmisIds = _students
          .where((s) => s['isAdmis'] == true)
          .map((s) => s['id'] as int)
          .toSet();
      _selectedRedoublantIds = _students
          .where((s) => s['isAdmis'] == false)
          .map((s) => s['id'] as int)
          .toSet();
    } catch (e) {
      debugPrint('Error loading students with averages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executePromotion() async {
    if (_oldAnneeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Promotion bloquée : l\'année sélectionnée n\'a pas d\'historique défini.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedAdmisIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élève admis sélectionné.')),
      );
      return;
    }
    // Validate destination class OR check if it's a final class
    if (!_isFinalClass && (_newClasseId == null || _newAnneeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une classe de destination.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isFinalClass ? 'Confirmer l\'archivage' : 'Confirmer la promotion',
        ),
        content: Text(
          _isFinalClass
              ? 'Archiver ${_selectedAdmisIds.length} élève(s) diplômé(s) ? (Statut: Sorti)'
              : 'Promouvoir ${_selectedAdmisIds.length} élève(s) admis vers la classe de destination ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      if (_isFinalClass) {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          final now = DateTime.now().toIso8601String();
          for (var id in _selectedAdmisIds) {
            // 1. Mettre à jour la décision dans le parcours de l'année sortante pour l'archive
            final existingOld = await txn.query(
              'eleve_parcours',
              where: 'eleve_id = ? AND annee_scolaire_id = ?',
              whereArgs: [id, _oldAnneeId],
            );

            if (existingOld.isNotEmpty) {
              await txn.update(
                'eleve_parcours',
                {'decision': 'Diplômé', 'updated_at': now},
                where: 'id = ?',
                whereArgs: [existingOld.first['id']],
              );
            }

            // 2. Marquer l'élève comme sorti dans la table principale
            await txn.update(
              'eleve',
              {'statut': 'sorti', 'updated_at': now},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        });
      } else {
        // Promotion standard utilisant le DAO pour gérer l'archivage et la nouvelle inscription
        await _dbHelper.eleveDao.executeBulkPromotion(
          eleveIds: _selectedAdmisIds.toList(),
          oldClasseId: _oldClasseId!,
          oldAnneeId: _oldAnneeId!,
          newClasseId: _newClasseId!,
          newAnneeId: _newAnneeId!,
          decision: 'Admis',
          confirmationStatut: 'En attente',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFinalClass
                  ? '${_selectedAdmisIds.length} élève(s) archivé(s) comme diplômé(s).'
                  : '${_selectedAdmisIds.length} élève(s) promu(s) avec succès.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadStudentsWithAverages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRedoublement() async {
    if (_selectedRedoublantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élève redoublant sélectionné.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le redoublement'),
        content: Text(
          'Enregistrer ${_selectedRedoublantIds.length} élève(s) comme redoublant(s) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Utiliser le DAO pour gérer proprement l'archivage de l'année passée (Redoublant)
      // et la réinscription pour la nouvelle année dans la même classe
      await _dbHelper.eleveDao.executeBulkPromotion(
        eleveIds: _selectedRedoublantIds.toList(),
        oldClasseId: _oldClasseId!,
        oldAnneeId: _oldAnneeId!,
        newClasseId: _oldClasseId!, // Garder la même classe
        newAnneeId: _newAnneeId!,
        decision: 'Redoublant',
        confirmationStatut: 'En attente',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedRedoublantIds.length} élève(s) enregistré(s) comme redoublant(s).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _loadStudentsWithAverages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTransferDialog(Map<String, dynamic> student) async {
    final int? result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int? selectedDestId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // Filter out the current class from _classes (must be same level)
            final otherClasses = _classes
                .where((c) => c['id'] != _oldClasseId)
                .toList();

            return AlertDialog(
              title: const Text('Transférer l\'élève'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transférer ${student['nom']} ${student['prenom']} vers une autre classe du même niveau.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Classe de destination',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF374151)
                          : Colors.grey[50],
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.white,
                    value: selectedDestId,
                    items: otherClasses
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nom'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDestId = v),
                  ),
                  if (otherClasses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Aucune autre classe disponible pour ce niveau.',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedDestId == null
                      ? null
                      : () => Navigator.pop(ctx, selectedDestId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Transférer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _dbHelper.eleveDao.transfererEleve(
          eleveId: student['id'] as int,
          newClasseId: result,
          anneeId: _oldAnneeId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Élève transféré avec succès.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadStudentsWithAverages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 1000;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: _isLoading && _annees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildControls(isDark, isNarrow),
                    const SizedBox(height: 12),
                    _buildPassMarkBanner(isDark),
                    const SizedBox(height: 12),
                    _buildActionButtons(isDark, isNarrow),
                    const SizedBox(height: 12),
                    if (_isLoading && _annees.isNotEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      _buildStudentsList(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPassMarkBanner(bool isDark) {
    if (_oldAnneeId == null || _oldClasseId == null)
      return const SizedBox.shrink();

    final admisCount = _students.where((s) => s['isAdmis'] == true).length;
    final redoublantCount = _students.length - admisCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  const TextSpan(text: 'Note de passage du cycle : '),
                  TextSpan(
                    text:
                        '${_moyennePassage.toStringAsFixed(1)} / ${_noteMax.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '  •  '),
                  TextSpan(
                    text: '$admisCount Admis',
                    style: TextStyle(
                      color: Colors.green[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: '  •  '),
                  TextSpan(
                    text: '$redoublantCount Redoublant(s)',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool isNarrow) {
    if (_students.isEmpty) return const SizedBox.shrink();

    final buttons = [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: isNarrow ? const Size(double.infinity, 45) : null,
        ),
        onPressed: _isLoading ? null : _executeRedoublement,
        icon: const Icon(Icons.replay, size: 18),
        label: Text('Redoubler (${_selectedRedoublantIds.length})'),
      ),
      if (!isNarrow) const SizedBox(width: 12) else const SizedBox(height: 8),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: isNarrow ? const Size(double.infinity, 45) : null,
        ),
        onPressed: _isLoading ? null : _executePromotion,
        icon: Icon(
          _isFinalClass ? Icons.archive_rounded : Icons.trending_up,
          size: 18,
        ),
        label: Text(
          _isFinalClass
              ? 'ARCHIVER LES DIPLÔMÉS (${_selectedAdmisIds.length})'
              : 'PROMOUVOIR (${_selectedAdmisIds.length})',
        ),
      ),
    ];

    if (isNarrow) {
      return Column(children: buttons);
    }

    return Row(children: [const Spacer(), ...buttons]);
  }

  Widget _buildControls(bool isDark, bool isNarrow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: isNarrow
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.end,
        children: [
          // FROM block
          if (isNarrow)
            _buildSourceBlock(isDark)
          else
            Expanded(child: _buildSourceBlock(isDark)),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 0 : 20,
              vertical: isNarrow ? 12 : 16,
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNarrow
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_forward_rounded,
                size: 24,
                color: AppTheme.primaryColor,
              ),
            ),
          ),

          // TO block
          if (isNarrow)
            _buildDestinationBlock(isDark, isNarrow)
          else
            Expanded(child: _buildDestinationBlock(isDark, isNarrow)),
        ],
      ),
    );
  }

  Widget _buildSourceBlock(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ORIGINE',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: 'Année de Départ',
            labelStyle: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
          ),
          dropdownColor: isDark ? const Color(0xFF374151) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          value: _oldAnneeId,
          items: _annees
              .map(
                (a) => DropdownMenuItem<int>(
                  value: a['id'] as int,
                  child: Text(a['libelle'].toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _oldAnneeId = v);
            _loadClasses();
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: 'Classe de Départ',
            labelStyle: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
          ),
          dropdownColor: isDark ? const Color(0xFF374151) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          value: _oldClasseId,
          items: _classes
              .map(
                (c) => DropdownMenuItem<int>(
                  value: c['id'] as int,
                  child: Text(c['nom'].toString()),
                ),
              )
              .toList(),
          onChanged: (v) async {
            setState(() => _oldClasseId = v);
            if (v != null) await _resolveDestinationClasses(v);
            await _loadStudentsWithAverages();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDestinationBlock(bool isDark, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'DESTINATION',
                style: TextStyle(
                  color: Colors.green[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: 'Année de Destination',
            labelStyle: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
          ),
          dropdownColor: isDark ? const Color(0xFF374151) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          value: _newAnneeId,
          items: _annees
              .map(
                (a) => DropdownMenuItem<int>(
                  value: a['id'] as int,
                  child: Text(a['libelle'].toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _newAnneeId = v);
            if (v != null) {
              final selectedYear = _annees.firstWhere(
                (a) => a['id'] == v,
                orElse: () => <String, dynamic>{},
              );
              final prevId = selectedYear['annee_precedente_id'];
              if (prevId != null) {
                setState(() => _oldAnneeId = prevId as int);
                _loadClasses();
              }
            }
          },
        ),
        const SizedBox(height: 8),
        if (_isFinalClass)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Classe Terminale : Les élèves admis seront archivés (Statut : Sorti).',
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: 'Classe de Destination',
              labelStyle: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
            ),
            dropdownColor: isDark ? const Color(0xFF374151) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            value: _newClasseId,
            items: _destClasses
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['nom'].toString()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _newClasseId = v),
          ),
          if (_oldClasseId != null && _destClasses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _nextNiveauId == null
                    ? 'Progression non configurée pour ce niveau (Paramètres > Cycles & Niveaux).'
                    : 'Aucune classe trouvée pour le niveau de destination.',
                style: TextStyle(
                  color: _nextNiveauId == null
                      ? Colors.orange[400]
                      : Colors.red[400],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStudentsList(bool isDark) {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun élève trouvé dans cette classe.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width < 800 ? 800 : width - 64,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.swap_horiz,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Élève',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        'Matricule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Moy. Annuelle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Décision',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _students.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final student = _students[index];
                  final isAdmis = student['isAdmis'] as bool;
                  final moyenne = student['moyenne'] as double;
                  final studentId = student['id'] as int;
                  final isSelected = isAdmis
                      ? _selectedAdmisIds.contains(studentId)
                      : _selectedRedoublantIds.contains(studentId);

                  return Container(
                    color: isSelected
                        ? (isAdmis
                              ? Colors.green.withOpacity(0.05)
                              : Colors.red.withOpacity(0.05))
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Tooltip(
                            message: 'Transférer vers une autre classe',
                            child: IconButton(
                              icon: const Icon(Icons.swap_horiz, size: 20),
                              onPressed: () => _showTransferDialog(student),
                              color: AppTheme.primaryColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isAdmis
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                child: Text(
                                  (student['nom']?.toString() ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: isAdmis
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${student['nom']} ${student['prenom']}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            student['matricule']?.toString() ?? '-',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAdmis
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                moyenne.toStringAsFixed(2),
                                style: TextStyle(
                                  color: isAdmis
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAdmis
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isAdmis
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAdmis ? Icons.check_circle : Icons.cancel,
                                    size: 14,
                                    color: isAdmis
                                        ? Colors.green[600]
                                        : Colors.red[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAdmis ? 'Admis' : 'Redoublant',
                                    style: TextStyle(
                                      color: isAdmis
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: isSelected,
                            activeColor: isAdmis ? Colors.green : Colors.red,
                            onChanged: (val) {
                              setState(() {
                                if (isAdmis) {
                                  if (val == true) {
                                    _selectedAdmisIds.add(studentId);
                                  } else {
                                    _selectedAdmisIds.remove(studentId);
                                  }
                                } else {
                                  if (val == true) {
                                    _selectedRedoublantIds.add(studentId);
                                  } else {
                                    _selectedRedoublantIds.remove(studentId);
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
