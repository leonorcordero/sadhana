import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/settings/app_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _customReminderController;
  String _lastBackupActionAt = '';
  String _appVersion = '-';
  String _buildNumber = '-';

  @override
  void initState() {
    super.initState();
    final name = ref.read(appSettingsProvider).name;
    _nameController = TextEditingController(text: name);
    _customReminderController = TextEditingController(
      text: ref.read(appSettingsProvider).customReminderText,
    );
    _lastBackupActionAt =
        (ref
                .read(localStorageDatasourceProvider)
                .getSetting('backup_last_action_at')
            as String?) ??
        '';
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customReminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final selectedPaletteIndex = AppSettings.palettes.indexWhere(
      (palette) => palette.seed == settings.themeColor,
    );
    final paletteIndex = selectedPaletteIndex < 0 ? 0 : selectedPaletteIndex;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toca para desplegar paletas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: paletteIndex,
                  decoration: const InputDecoration(
                    labelText: 'Paleta de color',
                  ),
                  items: List.generate(AppSettings.palettes.length, (index) {
                    final palette = AppSettings.palettes[index];
                    final lightTone = Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.72),
                      palette.seed,
                    );
                    final darkTone = Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.28),
                      palette.seed,
                    );
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Row(
                        children: [
                          _ToneDot(color: lightTone),
                          const SizedBox(width: 6),
                          _ToneDot(color: palette.seed),
                          const SizedBox(width: 6),
                          _ToneDot(color: darkTone),
                          const SizedBox(width: 10),
                          Text('Paleta ${index + 1}'),
                        ],
                      ),
                    );
                  }),
                  onChanged: (index) {
                    if (index == null) return;
                    notifier.setColor(AppSettings.palettes[index].seed);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tipografía ─────────────────────────────────────────────────
          _SectionCard(
            label: 'TAMAÑO DE LETRA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajusta el tamaño del texto en toda la app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Pequeño', style: theme.textTheme.labelSmall),
                    Expanded(
                      child: Slider(
                        value: settings.textScale,
                        min: 0.85,
                        max: 1.15,
                        divisions: 6,
                        label: '${(settings.textScale * 100).round()}%',
                        onChanged: notifier.setTextScale,
                      ),
                    ),
                    Text('Grande', style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Escala actual: ${(settings.textScale * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                  DropdownButtonFormField<String>(
                    initialValue: settings.reminderContentType,
                    decoration: const InputDecoration(
                      labelText: 'Contenido del recordatorio',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'focus',
                        child: Text('Mensaje de enfoque'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Tareas pendientes'),
                      ),
                      DropdownMenuItem(
                        value: 'motivational',
                        child: Text('Frase motivacional'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Texto personalizado'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      notifier.setReminderContentType(value);
                    },
                  ),
                  if (settings.reminderContentType == 'custom') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customReminderController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Texto del recordatorio',
                        hintText: 'Escribe el mensaje de tu notificación',
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () {
                            notifier.setCustomReminderText(
                              _customReminderController.text,
                            );
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                      onSubmitted: notifier.setCustomReminderText,
                    ),
                  ],
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
                if (_lastBackupActionAt.isNotEmpty)
                  Text(
                    'Último backup: $_lastBackupActionAt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionCard(
            label: 'APP',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versión: $_appVersion'),
                const SizedBox(height: 4),
                Text('Compilación: $_buildNumber'),
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
    final now = DateTime.now().toIso8601String();

    await Clipboard.setData(ClipboardData(text: json));
    await ref
        .read(localStorageDatasourceProvider)
        .saveSetting('backup_last_action_at', now);
    if (mounted) {
      setState(() => _lastBackupActionAt = now);
    }

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

                final decoded = jsonDecode(raw);
                if (decoded is! Map) {
                  throw const FormatException('Formato de backup invalido');
                }
                final payload = Map<String, dynamic>.from(decoded);
                final cyclesCount = (payload['cycles'] as List?)?.length ?? 0;
                final tasksCount = (payload['tasks'] as List?)?.length ?? 0;
                final logsCount = (payload['dayLogs'] as List?)?.length ?? 0;
                final settingsCount =
                    (payload['settings'] as Map?)?.length ?? 0;

                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('Confirmar importación'),
                    content: Text(
                      'Este proceso reemplazará todos los datos actuales.\n\n'
                      'Ciclos: $cyclesCount\n'
                      'Tareas: $tasksCount\n'
                      'Registros diarios: $logsCount\n'
                      'Ajustes: $settingsCount',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmCtx, true),
                        child: const Text('Reemplazar todo'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                await repository.importBackupJson(raw);
                final now = DateTime.now().toIso8601String();
                await ref
                    .read(localStorageDatasourceProvider)
                    .saveSetting('backup_last_action_at', now);
                if (mounted) {
                  setState(() => _lastBackupActionAt = now);
                }
                await appController.initialize(
                  remindersEnabled: ref
                      .read(appSettingsProvider)
                      .remindersEnabled,
                  reminderHours: ref.read(appSettingsProvider).reminderHours,
                  reminderContentType: ref
                      .read(appSettingsProvider)
                      .reminderContentType,
                  customReminderText: ref
                      .read(appSettingsProvider)
                      .customReminderText,
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

class _ToneDot extends StatelessWidget {
  const _ToneDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
