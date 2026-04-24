import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';
import '../../../../../core/utils/template_engine.dart';

class AppreciationSettingsPage extends StatefulWidget {
  const AppreciationSettingsPage({super.key});

  @override
  State<AppreciationSettingsPage> createState() =>
      _AppreciationSettingsPageState();
}

class _AppreciationSettingsPageState extends State<AppreciationSettingsPage> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;

  // Editeur de modèles
  quill.QuillController _quillController = quill.QuillController.basic();
  final FocusNode _editorFocus = FocusNode();
  String _selectedTemplate = 'fiche_renseignement';
  bool _isTemplateLoading = false;

  int _selectedTabIndex =
      1; // 0 = Fichier, 1 = Accueil, 2 = Insertion, 3 = Mise en page, 4 = Publipostage

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final annee = await _db.getActiveAnnee();
      if (annee != null) {
        await _loadTemplate();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading appreciation data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTemplate() async {
    setState(() => _isTemplateLoading = true);
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final template = await _db.getDocumentTemplate(
        annee['id'],
        _selectedTemplate,
      );
      if (template != null && template['content'] != null) {
        final contentStr = template['content'] as String;
        if (contentStr.isNotEmpty) {
          final doc = quill.Document.fromJson(jsonDecode(contentStr));
          _quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        _quillController = quill.QuillController.basic();
      }
    } catch (e) {
      debugPrint('Error loading template: $e');
      _quillController = quill.QuillController.basic();
    } finally {
      if (mounted) setState(() => _isTemplateLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final contentJson = jsonEncode(
        _quillController.document.toDelta().toJson(),
      );
      await _db.saveDocumentTemplate({
        'annee_scolaire_id': annee['id'],
        'type': _selectedTemplate,
        'content': contentJson,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modèle enregistré avec succès')),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _insertTag(String tag) {
    var index = _quillController.selection.baseOffset;
    if (index < 0) {
      index = _quillController.document.length - 1;
    }
    _quillController.document.insert(index, tag);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + tag.length),
      quill.ChangeSource.local,
    );
    _editorFocus.requestFocus();
  }

  Future<void> _showPreview() async {
    await _saveSettings();

    final annee = await _db.getActiveAnnee();
    if (annee == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aperçu du rendu final'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: FutureBuilder<quill.Document?>(
            future: TemplateEngine().renderTemplate(
              _selectedTemplate,
              annee['id'],
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data == null) {
                return const Center(
                  child: Text("Erreur lors de la génération de l'aperçu."),
                );
              }
              final previewController = quill.QuillController(
                document: snapshot.data!,
                selection: const TextSelection.collapsed(offset: 0),
              );
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(40),
                child: IgnorePointer(
                  ignoring: true,
                  child: quill.QuillEditor.basic(controller: previewController),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print),
            label: const Text('Imprimer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildTabBar(theme),
          Container(height: 1, color: AppTheme.primaryColor),
          _buildActiveRibbon(),
          Container(height: 1, color: theme.dividerColor),
          Expanded(child: _buildA4Canvas()),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.only(top: 8, left: 16),
      child: Row(
        children: [
          const Icon(Icons.document_scanner, color: Colors.white, size: 20),
          const SizedBox(width: 24),
          _buildTabButton('Fichier', 0, theme),
          _buildTabButton('Accueil', 1, theme),
          _buildTabButton('Insertion', 2, theme),
          _buildTabButton('Mise en page', 3, theme),
          _buildTabButton('Publipostage', 4, theme),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, ThemeData theme) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRibbon() {
    return Container(
      color: Theme.of(context).cardColor,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _getRibbonContent(),
      ),
    );
  }

  Widget _getRibbonContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildFileRibbon();
      case 2:
        return _buildInsertRibbon();
      case 3:
        return _buildLayoutRibbon();
      case 4:
        return _buildMailingsRibbon();
      case 1:
      default:
        return _buildHomeRibbon();
    }
  }

  Widget _buildFileRibbon() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        key: const ValueKey('file_tab'),
        children: [
          const Icon(Icons.folder_open, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          const Text('Modèle actif : '),
          const SizedBox(width: 8),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _selectedTemplate,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'fiche_renseignement',
                  child: Text(
                    'Fiche de Renseignement',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                DropdownMenuItem(
                  value: 'bulletin_entete',
                  child: Text(
                    'Entête de Bulletin',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedTemplate = v);
                  _loadTemplate();
                }
              },
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          OutlinedButton.icon(
            onPressed: _showPreview,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Aperçu / Imprimer'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeRibbon() {
    return quill.QuillSimpleToolbar(
      key: const ValueKey('home_tab'),
      controller: _quillController,
    );
  }

  Widget _buildInsertRibbon() {
    return SingleChildScrollView(
      key: const ValueKey('insert_tab'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _insertImage,
            icon: const Icon(Icons.image),
            label: const Text('Image'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _insertTable,
            icon: const Icon(Icons.table_chart),
            label: const Text('Tableau'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _insertLink,
            icon: const Icon(Icons.link),
            label: const Text('Lien web'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _insertLine,
            icon: const Icon(Icons.horizontal_rule),
            label: const Text('Ligne horizontale'),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutRibbon() {
    return SingleChildScrollView(
      key: const ValueKey('layout_tab'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _setOrientation(true),
            icon: const Icon(Icons.crop_portrait),
            label: const Text('Portrait'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _setOrientation(false),
            icon: const Icon(Icons.crop_landscape),
            label: const Text('Paysage'),
          ),
          const SizedBox(width: 8),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Marges ajustées.')));
            },
            icon: const Icon(Icons.margin),
            label: const Text('Marges Normales'),
          ),
        ],
      ),
    );
  }

  Widget _buildMailingsRibbon() {
    return SingleChildScrollView(
      key: const ValueKey('mailings_tab'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Icon(Icons.alternate_email, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Insérer un champ de fusion : ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 16),
          _buildTagChip('{{nom_ecole}}', 'Nom École'),
          const SizedBox(width: 8),
          _buildTagChip('{{logo_ecole}}', 'Logo École'),
          const SizedBox(width: 8),
          _buildTagChip('{{cachet}}', 'Cachet & Signature'),
          const SizedBox(width: 8),
          _buildTagChip('{{nom_eleve}}', 'Nom Élève'),
          const SizedBox(width: 8),
          _buildTagChip('{{prenom_eleve}}', 'Prénom Élève'),
          const SizedBox(width: 8),
          _buildTagChip('{{classe}}', 'Classe'),
          const SizedBox(width: 8),
          _buildTagChip('{{date_naissance}}', 'Date Naiss.'),
          const SizedBox(width: 8),
          _buildTagChip('{{matricule}}', 'Matricule'),
        ],
      ),
    );
  }

  void _insertImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'L\'insertion d\'image locale sera configurée prochainement.',
        ),
      ),
    );
  }

  void _insertTable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Les tableaux complexes nécessitent l\'extension Quill.'),
      ),
    );
  }

  void _insertLink() {
    final tcUrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Insérer un lien'),
        content: TextField(
          controller: tcUrl,
          decoration: const InputDecoration(labelText: 'URL (ex: https://...)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tcUrl.text.isNotEmpty) {
                final txt = "Lien Web";
                final pos = _quillController.selection.baseOffset >= 0
                    ? _quillController.selection.baseOffset
                    : 0;
                _quillController.document.insert(pos, txt);
                _quillController.formatText(
                  pos,
                  txt.length,
                  quill.LinkAttribute(tcUrl.text),
                );
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: pos + txt.length),
                  quill.ChangeSource.local,
                );
              }
              Navigator.pop(c);
            },
            child: const Text('Insérer'),
          ),
        ],
      ),
    );
  }

  void _insertLine() {
    final pos = _quillController.selection.baseOffset >= 0
        ? _quillController.selection.baseOffset
        : 0;
    _quillController.document.insert(
      pos,
      '\n_________________________________________________________________________________\n',
    );
  }

  void _setOrientation(bool isPortrait) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPortrait
              ? 'Format Portrait sélectionné.'
              : 'Format Paysage sélectionné.',
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.blue.shade50,
      side: BorderSide.none,
      avatar: Icon(Icons.data_object, size: 14, color: Colors.blue.shade700),
      onPressed: () => _insertTag(tag),
      tooltip: 'Insérer $tag',
    );
  }

  Widget _buildA4Canvas() {
    if (_isTemplateLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Container(
          width: 794,
          constraints: const BoxConstraints(minHeight: 1123),
          margin: const EdgeInsets.only(bottom: 40),
          padding: const EdgeInsets.all(80),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Arial',
            ),
            child: quill.QuillEditor.basic(
              focusNode: _editorFocus,
              controller: _quillController,
            ),
          ),
        ),
      ),
    );
  }
}
