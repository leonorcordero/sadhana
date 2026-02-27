import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:url_launcher/url_launcher.dart';

class LinksPage extends ConsumerStatefulWidget {
  const LinksPage({super.key});

  @override
  ConsumerState<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends ConsumerState<LinksPage> {
  static const _linksKey = 'utility_links_v1';
  final List<Map<String, String>> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  void _loadLinks() {
    final ds = ref.read(localStorageDatasourceProvider);
    final raw = ds.getSetting(_linksKey) as List?;
    _links
      ..clear()
      ..addAll(
        (raw ?? const [])
            .whereType<Map>()
            .map(
              (e) => {
                'title': (e['title'] ?? '').toString(),
                'url': (e['url'] ?? '').toString(),
              },
            )
            .where((e) => e['url']!.isNotEmpty),
      );
  }

  Future<void> _saveLinks() async {
    await ref
        .read(localStorageDatasourceProvider)
        .saveSetting(_linksKey, _links);
  }

  Future<void> _addLink() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
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
              final title = titleCtrl.text.trim();
              var url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://$url';
              }
              _links.add({'title': title.isEmpty ? url : title, 'url': url});
              await _saveLinks();
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String rawUrl) async {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return;
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link inválido')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el link')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Links'),
        actions: [
          IconButton(
            onPressed: _addLink,
            icon: const Icon(Icons.add_link),
            tooltip: 'Agregar link',
          ),
        ],
      ),
      body: _links.isEmpty
          ? const Center(child: Text('No hay links guardados.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _links.length,
              itemBuilder: (context, index) {
                final item = _links[index];
                final url = item['url']!;
                final title = item['title']!;
                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(url),
                    onTap: () => _openLink(url),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'copy') {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Link copiado')),
                          );
                        } else if (value == 'delete') {
                          _links.removeAt(index);
                          await _saveLinks();
                          if (mounted) setState(() {});
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'copy', child: Text('Copiar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLink,
        icon: const Icon(Icons.add),
        label: const Text('Agregar link'),
      ),
    );
  }
}
