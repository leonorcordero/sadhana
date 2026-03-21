import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/note_model.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _searchCtrl = TextEditingController();
  String _selectedTag = 'Todas';

  static const _suggestedTags = [
    'Sadhana',
    'Sueños',
    'Procesos',
    'Patrones a trabajar',
    'Autobswervación',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final allNotes = repo.getNotes();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final allTags = <String>{
      ..._suggestedTags,
      for (final n in allNotes) ...n.tags,
    }.toList(growable: false);

    final query = _searchCtrl.text.trim().toLowerCase();
    final notes = allNotes
        .where((n) {
          final matchesTag =
              _selectedTag == 'Todas' || n.tags.any((t) => t == _selectedTag);
          if (!matchesTag) return false;
          if (query.isEmpty) return true;
          return (n.title ?? '').toLowerCase().contains(query) ||
              n.content.toLowerCase().contains(query) ||
              n.tags.any((t) => t.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notas'),
            Text(
              'Tus apuntes personales',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar notas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _TagChip(
                  label: 'Todas',
                  selected: _selectedTag == 'Todas',
                  onTap: () => setState(() => _selectedTag = 'Todas'),
                ),
                for (final tag in allTags)
                  _TagChip(
                    label: tag,
                    selected: _selectedTag == tag,
                    onTap: () => setState(() => _selectedTag = tag),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 56,
                      color: cs.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sin notas para este filtro.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: notes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) => _NoteCard(
                  note: notes[i],
                  onEdit: () => _openEditor(note: notes[i]),
                  onPinToggle: () async {
                    await repo.saveNote(
                      notes[i].copyWith(isPinned: !notes[i].isPinned),
                    );
                    setState(() {});
                  },
                  onDelete: () async {
                    await repo.deleteNote(notes[i].id);
                    setState(() {});
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Nueva nota',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openEditor({
    NoteModel? note,
    String? initialTitle,
    String? initialContent,
  }) async {
    final titleCtrl = TextEditingController(
      text: note?.title ?? initialTitle ?? '',
    );
    final contentCtrl = TextEditingController(
      text: note?.content ?? initialContent ?? '',
    );
    final tagsCtrl = TextEditingController(text: (note?.tags ?? []).join(', '));
    final repo = ref.read(repositoryProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(note == null ? 'Nueva nota' : 'Editar nota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Título (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              autofocus: true,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Escribe aquí...'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Etiquetas separadas por coma',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final content = contentCtrl.text.trim();
              if (content.isEmpty) return;
              final tags = tagsCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(growable: false);
              final updated = note == null
                  ? NoteModel.create(
                      title: titleCtrl.text.trim(),
                      content: content,
                      tags: tags,
                    )
                  : note.copyWith(
                      title: titleCtrl.text.trim().isEmpty
                          ? null
                          : titleCtrl.text.trim(),
                      content: content,
                      tags: tags,
                    );
              await repo.saveNote(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onPinToggle,
  });

  final NoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final hour = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$day/$month/${d.year}  $hour:$min';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.title != null && note.title!.isNotEmpty)
                          Expanded(
                            child: Text(
                              note.title!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        IconButton(
                          onPressed: onPinToggle,
                          icon: Icon(
                            note.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 18,
                            color: note.isPinned ? cs.primary : cs.outline,
                          ),
                          tooltip: note.isPinned ? 'Desfijar' : 'Fijar',
                        ),
                      ],
                    ),
                    if (note.title != null && note.title!.isNotEmpty)
                      const SizedBox(height: 4),
                    Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: note.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(note.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
