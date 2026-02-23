import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/settings/app_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final name = ref.read(appSettingsProvider).name;
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ajustes'),
            Text(
              'Personalización y backup',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ── Nombre ─────────────────────────────────────────────────────
          _SectionCard(
            label: 'NOMBRE',
            child: TextField(
              controller: _nameController,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: AppSettings.defaultName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    notifier.setName(_nameController.text);
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              onSubmitted: (v) => notifier.setName(v),
            ),
          ),
          const SizedBox(height: 16),

          // ── Color ──────────────────────────────────────────────────────
          _SectionCard(
            label: 'COLOR',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppSettings.presetColors.map((color) {
                final isSelected = settings.themeColor == color;
                final checkColor =
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87;
                return GestureDetector(
                  onTap: () => notifier.setColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outlineVariant,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: checkColor, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Notificaciones ─────────────────────────────────────────────
          _SectionCard(
            label: 'NOTIFICACIONES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recordatorios diarios'),
                  value: settings.remindersEnabled,
                  onChanged: (value) => notifier.setRemindersEnabled(value),
                ),
                if (settings.remindersEnabled) ...[
                  const SizedBox(height: 8),
                  _HourPickerRow(
                    title: 'Hora 1',
                    value: settings.reminderHours.isNotEmpty
                        ? settings.reminderHours[0]
                        : 9,
                    onChanged: (value) {
                      final next = List<int>.from(settings.reminderHours);
                      while (next.length < 3) {
                        next.add(9);
                      }
                      next[0] = value;
                      notifier.setReminderHours(next);
                    },
                  ),
                  _HourPickerRow(
                    title: 'Hora 2',
                    value: settings.reminderHours.length > 1
                        ? settings.reminderHours[1]
                        : 14,
                    onChanged: (value) {
                      final next = List<int>.from(settings.reminderHours);
                      while (next.length < 3) {
                        next.add(14);
                      }
                      next[1] = value;
                      notifier.setReminderHours(next);
                    },
                  ),
                  _HourPickerRow(
                    title: 'Hora 3',
                    value: settings.reminderHours.length > 2
                        ? settings.reminderHours[2]
                        : 20,
                    onChanged: (value) {
                      final next = List<int>.from(settings.reminderHours);
                      while (next.length < 3) {
                        next.add(20);
                      }
                      next[2] = value;
                      notifier.setReminderHours(next);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Backup ─────────────────────────────────────────────────────
          _SectionCard(
            label: 'BACKUP',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportBackup,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Exportar JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: _importBackup,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Importar JSON'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    final repository = ref.read(repositoryProvider);
    final json = await repository.exportBackupJson();

    await Clipboard.setData(ClipboardData(text: json));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup exportado'),
        content: const Text(
          'El JSON se copio al portapapeles. Pegalo y guardalo en un archivo seguro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final repository = ref.read(repositoryProvider);
    final appController = ref.read(appControllerProvider.notifier);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar backup JSON'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(hintText: '{ ...json... }'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final raw = controller.text.trim();
                if (raw.isEmpty) return;

                // Quick validation feedback before import.
                jsonDecode(raw);
                await repository.importBackupJson(raw);
                await appController.initialize(
                  remindersEnabled: ref
                      .read(appSettingsProvider)
                      .remindersEnabled,
                  reminderHours: ref.read(appSettingsProvider).reminderHours,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('JSON inválido o incompatible')),
                );
              }
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HourPickerRow extends StatelessWidget {
  const _HourPickerRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(title)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: value.clamp(0, 23).toInt(),
          items: List.generate(
            24,
            (h) => DropdownMenuItem<int>(
              value: h,
              child: Text('${h.toString().padLeft(2, '0')}:00'),
            ),
          ),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}
