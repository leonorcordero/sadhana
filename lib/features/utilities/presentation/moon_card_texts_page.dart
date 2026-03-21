import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';

class MoonCardTextsPage extends ConsumerStatefulWidget {
  const MoonCardTextsPage({super.key});

  @override
  ConsumerState<MoonCardTextsPage> createState() => _MoonCardTextsPageState();
}

class _MoonCardTextsPageState extends ConsumerState<MoonCardTextsPage> {
  late final TextEditingController _nightController;
  late final TextEditingController _dayController;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    final texts = repo.getMoonCardTexts();
    _nightController = TextEditingController(text: texts.nightWarningText);
    _dayController = TextEditingController(text: texts.dayOnlyText);
  }

  @override
  void dispose() {
    _nightController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    await repo.saveMoonCardTexts(
      nightWarningText: _nightController.text,
      dayOnlyText: _dayController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Textos guardados')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Caja lunar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Texto para "No se recomienda"',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nightController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'No se recomienda hacer sadhana PM',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Texto para "Solo de día"',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dayController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Sadhana solo de día.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
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
}
