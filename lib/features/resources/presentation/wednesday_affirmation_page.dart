import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/models/wednesday_affirmation_model.dart';

class WednesdayAffirmationPage extends ConsumerStatefulWidget {
  const WednesdayAffirmationPage({super.key});

  @override
  ConsumerState<WednesdayAffirmationPage> createState() =>
      _WednesdayAffirmationPageState();
}

class _WednesdayAffirmationPageState
    extends ConsumerState<WednesdayAffirmationPage> {
  List<WednesdayAffirmationModel> _items = <WednesdayAffirmationModel>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(repositoryProvider);
    setState(() {
      _items = repo.getWednesdayAffirmations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Afirmación miércoles'),
            Text(
              'Lista de afirmaciones cargadas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _items.isEmpty
          ? Center(
              child: Text(
                'No hay afirmaciones cargadas.\nToca + para agregar una.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemBuilder: (context, index) {
                final item = _items[index];
                final title = (item.name ?? '').trim().isEmpty
                    ? 'Sin nombre'
                    : item.name!;
                final subtitle = item.contentType == 'image'
                    ? 'Imagen'
                    : (item.text ?? '').trim();
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () => _showDetail(item),
                    leading: Icon(
                      item.contentType == 'image'
                          ? Icons.image_outlined
                          : Icons.notes_outlined,
                      color: cs.primary,
                    ),
                    title: Text(title),
                    subtitle: Text(
                      '${_formatDateKey(item.meditationDateKey)} · $subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Eliminar afirmación',
                          icon: Icon(
                            Icons.delete_outline,
                            color: cs.error,
                            size: 20,
                          ),
                          onPressed: () => _deleteItem(item),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: _items.length,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  String _formatDateKey(String dateKey) {
    try {
      final date = DateUtilsX.fromDateKey(dateKey);
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year.toString();
      return '$d/$m/$y';
    } catch (_) {
      return dateKey;
    }
  }

  Future<void> _addItem() async {
    final created = await Navigator.of(context).push<WednesdayAffirmationModel>(
      MaterialPageRoute(builder: (_) => const _WednesdayAffirmationFormPage()),
    );
    if (created == null) return;
    await ref.read(repositoryProvider).saveWednesdayAffirmation(created);
    _reload();
  }

  Future<void> _showDetail(WednesdayAffirmationModel item) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxHeight = media.size.height * 0.78;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, media.padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item.name ?? '').trim().isEmpty ? 'Sin nombre' : item.name!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateKey(item.meditationDateKey),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (item.contentType == 'image' &&
                    item.imagePath != null &&
                    File(item.imagePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(item.imagePath!), fit: BoxFit.cover),
                  )
                else
                  Text(
                    item.text?.trim().isNotEmpty == true
                        ? item.text!
                        : 'Sin contenido',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteItem(WednesdayAffirmationModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar afirmación'),
        content: const Text('Esta afirmación de miércoles se eliminará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(repositoryProvider)
        .removeWednesdayAffirmation(updatedAt: item.updatedAt);
    _reload();
  }
}

class _WednesdayAffirmationFormPage extends ConsumerStatefulWidget {
  const _WednesdayAffirmationFormPage();

  @override
  ConsumerState<_WednesdayAffirmationFormPage> createState() =>
      _WednesdayAffirmationFormPageState();
}

class _WednesdayAffirmationFormPageState
    extends ConsumerState<_WednesdayAffirmationFormPage> {
  late DateTime _meditationDate;
  late TextEditingController _nameCtrl;
  late TextEditingController _textCtrl;
  String _contentType = 'text';
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _meditationDate = DateTime.now();
    _nameCtrl = TextEditingController();
    _textCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasImage =
        _imagePath != null &&
        _imagePath!.trim().isNotEmpty &&
        File(_imagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva afirmación')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha de meditación',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_formatDate(_meditationDate)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (opcional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'text',
                        label: Text('Texto largo'),
                        icon: Icon(Icons.notes_outlined),
                      ),
                      ButtonSegment<String>(
                        value: 'image',
                        label: Text('Imagen'),
                        icon: Icon(Icons.image_outlined),
                      ),
                    ],
                    selected: {_contentType},
                    onSelectionChanged: (values) {
                      setState(() => _contentType = values.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_contentType == 'text')
                    TextField(
                      controller: _textCtrl,
                      minLines: 8,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'Texto',
                        hintText: 'Escribe la afirmación...',
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Cargar imagen'),
                            ),
                            if (hasImage)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _imagePath = null),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Quitar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Text(
                            'No hay imagen cargada.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _meditationDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _meditationDate = picked);
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final sourcePath = picked.files.first.path;
    if (sourcePath == null || sourcePath.isEmpty) return;

    final source = File(sourcePath);
    if (!await source.exists()) return;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(docs.path, 'resources', 'special', 'wednesday_affirmation'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(dir.path, filename);
    await source.copy(destPath);
    setState(() => _imagePath = destPath);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final text = _textCtrl.text.trim();
    final hasText = text.isNotEmpty;
    final hasImage =
        _imagePath != null &&
        _imagePath!.trim().isNotEmpty &&
        File(_imagePath!).existsSync();

    if (_contentType == 'text' && !hasText) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega un texto para guardar.')),
      );
      return;
    }
    if (_contentType == 'image' && !hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carga una imagen para guardar.')),
      );
      return;
    }

    final model = WednesdayAffirmationModel(
      meditationDateKey: DateUtilsX.dateKey(_meditationDate),
      name: name.isEmpty ? null : name,
      contentType: _contentType,
      text: _contentType == 'text' ? text : null,
      imagePath: _contentType == 'image' ? _imagePath : null,
      updatedAt: DateTime.now().toIso8601String(),
    );

    Navigator.of(context).pop(model);
  }
}
