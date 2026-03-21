import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/core/utils/responsive_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/calendar/presentation/calendar_page.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/resources/presentation/wednesday_affirmation_page.dart';
import 'package:sadhana/features/settings/presentation/settings_page.dart';

// ── Nombres localizados ────────────────────────────────────────────────────────

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _affirmationOptions = <String>[];
const _emanationOptions = <String>[];
const _legacyAffirmationOptions = [
  'Hoy sostengo mi disciplina con calma.',
  'Mi constancia diaria transforma mi vida.',
  'Elijo presencia, enfoque y devoción.',
  'Cada acción consciente fortalece mi sankalpa.',
  'Soy estable en mi práctica, incluso en días difíciles.',
];
const _legacyEmanationOptions = [
  'Emano serenidad y claridad en cada paso.',
  'Emano gratitud, paciencia y buena voluntad.',
  'Emano luz interior para sostener mi práctica.',
  'Emano disciplina amorosa, sin rigidez.',
  'Emano coherencia entre lo que siento, pienso y hago.',
];

String _formatWeekday(DateTime d) => _weekdays[d.weekday - 1];
String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

// ── Página ────────────────────────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _scheduleClockTick();
  }

  void _scheduleClockTick() {
    _clockTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _clockTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleClockTick();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    if (state.isLoading) {
      return const SafeArea(child: _DashboardLoadingSkeleton());
    }
    final settings = ref.watch(appSettingsProvider);
    final cycles = state.activeCycles;
    final repo = ref.read(repositoryProvider);
    final today = _now;
    final calendarDay = state.selectedDate;

    final moonName = MoonPhaseUtils.phaseName(today);
    final isNewMoon = MoonPhaseUtils.phaseEmoji(today) == '🌑';
    final moonCardTexts = repo.getMoonCardTexts();
    final calendarDayEventTitles = repo.getVisibleEventTitlesForDate(
      calendarDay,
    );
    final diaryEntry = repo.getDiaryEntry(today);
    final completedMandalaCount = repo
        .getCompletedMandalaTasksForDay(today)
        .length;
    final isCompactLayout = ResponsiveUtils.isNarrowPhone(context);
    final spacingScale = ResponsiveUtils.spacingScale(context);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                cs.primary.withValues(alpha: 0.08),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16 * spacingScale,
            20 * spacingScale,
            16 * spacingScale,
            132 * spacingScale,
          ),
          children: [
            _DashboardReveal(
              index: 0,
              child: _Header(
                appName: settings.name,
                date: today,
                appIconPath: settings.iconPath,
              ),
            ),
            SizedBox(height: 24 * spacingScale),
            if (isCompactLayout) ...[
              _DashboardReveal(
                index: 1,
                child: _MoonCard(
                  moonName: moonName,
                  showNightWarning: moonName.toLowerCase().contains(
                    'creciente',
                  ),
                  showDayOnlyHint: isNewMoon,
                  nightWarningText: moonCardTexts.nightWarningText,
                  dayOnlyText: moonCardTexts.dayOnlyText,
                ),
              ),
              SizedBox(height: 10 * spacingScale),
              _DashboardReveal(
                index: 2,
                child: _SpecialDayCard(
                  date: calendarDay,
                  eventTitles: calendarDayEventTitles,
                ),
              ),
            ] else
              _DashboardReveal(
                index: 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MoonCard(
                        moonName: moonName,
                        showNightWarning: moonName.toLowerCase().contains(
                          'creciente',
                        ),
                        showDayOnlyHint: isNewMoon,
                        nightWarningText: moonCardTexts.nightWarningText,
                        dayOnlyText: moonCardTexts.dayOnlyText,
                      ),
                    ),
                    SizedBox(width: 10 * spacingScale),
                    Expanded(
                      child: _SpecialDayCard(
                        date: calendarDay,
                        eventTitles: calendarDayEventTitles,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12 * spacingScale),
            const _DashboardReveal(index: 3, child: _AffirmationsCard()),
            SizedBox(height: 12 * spacingScale),
            _DashboardReveal(
              index: 4,
              child: _DiaryTodayCard(
                taskCount: completedMandalaCount,
                extraTaskCount: diaryEntry.extraTasks.length,
                noteCount: diaryEntry.manualEntries.length,
              ),
            ),
            SizedBox(height: 20 * spacingScale),
            const _DashboardReveal(index: 5, child: _MandalasSectionBand()),
            SizedBox(height: 12 * spacingScale),

            // ── Ciclos activos ───────────────────────────────────────────────
            if (cycles.isEmpty)
              _DashboardReveal(
                index: 6,
                child: _EmptyState(
                  onCreateTap: () => showCreateCycleSheet(context, ref),
                ),
              )
            else
              for (var index = 0; index < cycles.length; index++) ...[
                _CycleBadge(cycle: cycles[index]),
                SizedBox(height: 10 * spacingScale),
                _DashboardReveal(
                  index: 6 + index,
                  child: _CycleCard(
                    cycle: cycles[index],
                    snapshot: repo.getDashboardSnapshotForCycle(
                      cycleId: cycles[index].id,
                      date: state.selectedDate,
                    ),
                  ),
                ),
                SizedBox(height: 16 * spacingScale),
              ],
          ],
        ),
      ),
    );
  }
}

// ── Cabecera ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.appName,
    required this.date,
    required this.appIconPath,
  });

  final String appName;
  final DateTime date;
  final String? appIconPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeScale = ResponsiveUtils.typographyScale(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: _buildName(theme: theme, typeScale: typeScale),
            ),
            Flexible(
              flex: 4,
              child: _buildDateTime(
                context: context,
                theme: theme,
                alignEnd: true,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Ajustes',
              icon: Icon(
                Icons.settings_outlined,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildName({required ThemeData theme, required double typeScale}) {
    return Row(
      children: [
        if (appIconPath != null && appIconPath!.trim().isNotEmpty) ...[
          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Image.file(
              File(appIconPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_not_supported_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                appName,
                maxLines: 1,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  fontSize: 34 * typeScale,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTime({
    required BuildContext context,
    required ThemeData theme,
    required bool alignEnd,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              '${_capitalize(_formatWeekday(date))}, ${date.day} De ${_capitalize(_months[date.month - 1])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: (theme.textTheme.titleSmall?.fontSize ?? 15) - 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de fase lunar ─────────────────────────────────────────────────────

class _MoonCard extends StatelessWidget {
  const _MoonCard({
    required this.moonName,
    required this.showNightWarning,
    required this.showDayOnlyHint,
    required this.nightWarningText,
    required this.dayOnlyText,
  });

  final String moonName;
  final bool showNightWarning;
  final bool showDayOnlyHint;
  final String nightWarningText;
  final String dayOnlyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleSmallSize = theme.textTheme.titleSmall?.fontSize ?? 15;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoonPhaseUtils.phaseEmoji(DateTime.now()),
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanMoonName(moonName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: titleSmallSize - 1,
                    height: 1.1,
                  ),
                ),
                if (showNightWarning) ...[
                  const SizedBox(height: 4),
                  Text(
                    nightWarningText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.8,
                      height: 1.15,
                    ),
                  ),
                ],
                if (showDayOnlyHint) ...[
                  const SizedBox(height: 4),
                  Text(
                    dayOnlyText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.8,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanMoonName(String value) {
  return value
      .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
      .trimLeft();
}

class _SpecialDayCard extends StatelessWidget {
  const _SpecialDayCard({required this.date, required this.eventTitles});

  final DateTime date;
  final List<String> eventTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_outlined, size: 20, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HOY',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateUtilsX.dateKey(date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (eventTitles.isNotEmpty) ...[
                  for (final title in eventTitles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $title',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ] else ...[
                  Text(
                    'Sin actividades para este día.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ciclo ──────────────────────────────────────────────────────────

class _CycleCard extends ConsumerWidget {
  const _CycleCard({required this.cycle, required this.snapshot});

  final CycleModel cycle;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ratio = snapshot.completionRatio;
    final totalTasks = snapshot.tasks.length;
    final completedTasks =
        snapshot.todayLog?.completedTaskIds.length.clamp(0, totalTasks) ?? 0;
    final progressLabel = '${(ratio * 100).toStringAsFixed(0)}%';

    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final pending = snapshot.tasks
        .where(
          (t) => !(snapshot.todayLog?.completedTaskIds.contains(t.id) ?? false),
        )
        .toList();
    final displayName = _normalizedMandalaName(cycle.name);

    final stripeColor =
        archetype?.softHeaderColor(cs) ?? cs.primary.withValues(alpha: 0.22);
    final archetypeIcon =
        archetype?.minimalIcon ?? Icons.self_improvement_outlined;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CyclesPage()));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 70,
              color: stripeColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(archetypeIcon, size: 20, color: cs.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Día ${cycle.currentDay}/${cycle.duration}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ratio >= 1) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.workspace_premium,
                      color: cs.onPrimaryContainer,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: pending.isNotEmpty
                            ? Text(
                                'Pendientes: ${pending.map((t) => t.title).take(2).join(' • ')}'
                                '${pending.length > 2 ? '...' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'Todas las tareas completas hoy.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 12),
                      _ProgressBadge(ratio: ratio, label: progressLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        icon: Icons.task_alt_outlined,
                        label: '$completedTasks/$totalTasks tareas',
                        color: cs.primary,
                      ),
                      _MetricChip(
                        icon: pending.isEmpty
                            ? Icons.check_circle_outline
                            : Icons.pending_actions_outlined,
                        label: pending.isEmpty
                            ? 'Sin pendientes'
                            : '${pending.length} pendientes',
                        color: pending.isEmpty ? cs.tertiary : cs.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 10,
                        color: cs.surfaceContainerHighest,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: value >= 1
                                      ? [cs.tertiary, cs.primary]
                                      : [cs.primary, cs.secondary],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pending.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CyclesPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.playlist_add_check, size: 16),
                        label: const Text('Completar ahora'),
                      ),
                    ),
                  if (pending.isNotEmpty) const SizedBox(height: 8),
                  if ((snapshot.todayLog?.closed ?? false) == false &&
                      pending.isEmpty)
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(appControllerProvider.notifier)
                            .closeTodayForActiveCycles();
                      },
                      child: const Text('Cerrar día'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.ratio, required this.label});

  final double ratio;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 54,
      height: 54,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 1 ? cs.tertiary : cs.primary,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: value >= 1 ? cs.tertiary : cs.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.all_inclusive,
                      color: cs.primary,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aún no tienes mandalas activos.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Crear primer mandala'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardReveal extends StatelessWidget {
  const _DashboardReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = index.clamp(0, 10);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (clamped * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
    );
  }
}

class _DashboardLoadingSkeleton extends StatefulWidget {
  const _DashboardLoadingSkeleton();

  @override
  State<_DashboardLoadingSkeleton> createState() =>
      _DashboardLoadingSkeletonState();
}

class _DashboardLoadingSkeletonState extends State<_DashboardLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spacingScale = ResponsiveUtils.spacingScale(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final shimmerT = _controller.value;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16 * spacingScale,
              20 * spacingScale,
              16 * spacingScale,
              132 * spacingScale,
            ),
            children: [
              _DashboardSkeletonCard(
                shimmerT: shimmerT,
                child: const Column(
                  children: [
                    _DashboardShimmerBlock(height: 24, widthFactor: 0.4),
                    SizedBox(height: 12),
                    _DashboardShimmerBlock(height: 14, widthFactor: 0.6),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DashboardSkeletonCard(
                shimmerT: shimmerT,
                child: const Column(
                  children: [
                    _DashboardShimmerBlock(height: 18, widthFactor: 0.55),
                    SizedBox(height: 10),
                    _DashboardShimmerBlock(height: 12, widthFactor: 0.8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DashboardSkeletonCard(
                shimmerT: shimmerT,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardShimmerBlock(height: 14, widthFactor: 0.34),
                    SizedBox(height: 12),
                    _DashboardShimmerBlock(height: 12, widthFactor: 0.7),
                    SizedBox(height: 8),
                    _DashboardShimmerBlock(height: 12, widthFactor: 0.58),
                    SizedBox(height: 8),
                    _DashboardShimmerBlock(height: 10, widthFactor: 1),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DashboardSkeletonCard(
                shimmerT: shimmerT,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardShimmerBlock(height: 14, widthFactor: 0.3),
                    SizedBox(height: 12),
                    _DashboardShimmerBlock(height: 12, widthFactor: 0.75),
                    SizedBox(height: 8),
                    _DashboardShimmerBlock(height: 12, widthFactor: 0.66),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardSkeletonCard extends StatelessWidget {
  const _DashboardSkeletonCard({required this.shimmerT, required this.child});

  final double shimmerT;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stopA = (shimmerT - 0.24).clamp(0.0, 1.0);
    final stopB = shimmerT.clamp(0.0, 1.0);
    final stopC = (shimmerT + 0.24).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: const Alignment(-1, -0.2),
          end: const Alignment(1, 0.2),
          stops: [stopA, stopB, stopC],
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainerHighest,
            cs.surfaceContainerHigh,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}

class _DashboardShimmerBlock extends StatelessWidget {
  const _DashboardShimmerBlock({
    required this.height,
    required this.widthFactor,
  });

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _AffirmationsCard extends ConsumerStatefulWidget {
  const _AffirmationsCard();

  @override
  ConsumerState<_AffirmationsCard> createState() => _AffirmationsCardState();
}

class _AffirmationsCardState extends ConsumerState<_AffirmationsCard> {
  String? _text;

  @override
  void initState() {
    super.initState();
    Future.microtask(_cleanupLegacyPhrases);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionTitleSize = (theme.textTheme.titleSmall?.fontSize ?? 15) - 1.2;
    final repo = ref.read(repositoryProvider);
    final saved = repo.getHomePhraseSelection();
    final savedType = saved?.type;
    final title = savedType == 'emanation' ? 'EMANACIONES' : 'AFIRMACIONES';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    fontSize: sectionTitleSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  onPressed: () => _openPhraseMenu(context, repo),
                  icon: const Icon(Icons.menu_book_outlined, size: 14),
                  label: const Text('Diarias'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WednesdayAffirmationPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                  label: const Text('Miércoles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhraseMenu(
    BuildContext context,
    SadhanaRepository repo,
  ) async {
    final saved = repo.getHomePhraseSelection();
    const workingType = 'affirmation';
    String workingText =
        (_text ?? saved?.text ?? _initialPhrase(repo, workingType)).trim();

    if (!_optionsForType(repo, workingType).contains(workingText)) {
      workingText = _initialPhrase(repo, workingType);
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final customOptions = repo.getCustomHomePhrases(
                type: workingType,
              );
              final selectedIsCustom = customOptions.any(
                (item) => item.toLowerCase() == workingText.toLowerCase(),
              );

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menú de afirmaciones',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Afirmación elegida para mostrar:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 96),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Text(
                        workingText.trim().isEmpty
                            ? 'Sin afirmación seleccionada'
                            : workingText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Theme(
                            data: theme.copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              childrenPadding: const EdgeInsets.only(bottom: 4),
                              title: Text(
                                'Mis afirmaciones',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              children: [
                                if (customOptions.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      6,
                                      2,
                                      6,
                                      8,
                                    ),
                                    child: Text(
                                      'No tienes afirmaciones personalizadas todavía.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                for (final option in customOptions)
                                  ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    onTap: () => setModalState(
                                      () => workingText = option,
                                    ),
                                    leading: Icon(
                                      workingText == option
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: workingText == option
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    title: Text(
                                      option,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar afirmación',
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: cs.primary,
                                          ),
                                          onPressed: () async {
                                            final edited =
                                                await _showAddPhraseDialog(
                                                  ctx,
                                                  type: workingType,
                                                  initialText: option,
                                                  previousText: option,
                                                );
                                            if (!mounted) return;
                                            if (edited != null &&
                                                edited.trim().isNotEmpty) {
                                              setModalState(() {
                                                if (workingText == option) {
                                                  workingText = edited;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Eliminar afirmación',
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: cs.error,
                                          ),
                                          onPressed: () async {
                                            await repo.removeCustomHomePhrase(
                                              type: 'affirmation',
                                              text: option,
                                            );
                                            if (!mounted) return;
                                            setModalState(() {
                                              if (workingText == option) {
                                                final refreshedCustom = repo
                                                    .getCustomHomePhrases(
                                                      type: 'affirmation',
                                                    );
                                                workingText =
                                                    refreshedCustom.isEmpty
                                                    ? ''
                                                    : refreshedCustom.first;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final added = await _showAddPhraseDialog(
                                        ctx,
                                        type: workingType,
                                      );
                                      if (!mounted) return;
                                      if (added != null && added.isNotEmpty) {
                                        setModalState(() {
                                          workingText = added;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Agregar afirmación'),
                                  ),
                                ),
                                if (selectedIsCustom) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final edited =
                                            await _showAddPhraseDialog(
                                              ctx,
                                              type: workingType,
                                              initialText: workingText,
                                              previousText: workingText,
                                            );
                                        if (!mounted) return;
                                        if (edited != null &&
                                            edited.trim().isNotEmpty) {
                                          setModalState(() {
                                            workingText = edited;
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Editar afirmación elegida',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (workingText.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Agrega una frase antes de guardar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            await repo.saveHomePhraseSelection(
                              type: workingType,
                              text: workingText,
                            );
                            if (!mounted) return;
                            setState(() {
                              _text = workingText;
                            });
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          },
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _showAddPhraseDialog(
    BuildContext context, {
    required String type,
    String? initialText,
    String? previousText,
  }) async {
    final ctrl = TextEditingController(text: initialText ?? '');
    final isEditing = previousText != null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing
              ? (type == 'emanation' ? 'Editar emanación' : 'Editar afirmación')
              : (type == 'emanation'
                    ? 'Agregar emanación'
                    : 'Agregar afirmación'),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Frase escrita',
            hintText: 'Escribe tu frase',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final repo = ref.read(repositoryProvider);
              late final bool saved;
              if (isEditing) {
                saved = await repo.updateCustomHomePhrase(
                  type: type,
                  previousText: previousText,
                  nextText: text,
                );
              } else {
                await repo.addCustomHomePhrase(type: type, text: text);
                saved = true;
              }
              if (!saved) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ya existe una afirmación igual o no se pudo editar.',
                    ),
                  ),
                );
                return;
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  List<String> _optionsForType(SadhanaRepository repo, String type) {
    final base = type == 'emanation' ? _emanationOptions : _affirmationOptions;
    final custom = repo.getCustomHomePhrases(type: type);
    return <String>[...base, ...custom];
  }

  String _initialPhrase(SadhanaRepository repo, String type) {
    final options = _optionsForType(repo, type);
    if (options.isEmpty) return '';
    return options.first;
  }

  Future<void> _cleanupLegacyPhrases() async {
    final repo = ref.read(repositoryProvider);
    final legacy = <String>{
      ..._legacyAffirmationOptions.map((e) => e.trim().toLowerCase()),
      ..._legacyEmanationOptions.map((e) => e.trim().toLowerCase()),
    };

    final customAffirmations = repo.getCustomHomePhrases(type: 'affirmation');
    final customEmanations = repo.getCustomHomePhrases(type: 'emanation');
    final filteredAffirmations = customAffirmations
        .where((item) => !legacy.contains(item.trim().toLowerCase()))
        .toList(growable: false);
    final filteredEmanations = customEmanations
        .where((item) => !legacy.contains(item.trim().toLowerCase()))
        .toList(growable: false);

    if (filteredAffirmations.length != customAffirmations.length) {
      await repo.saveCustomHomePhrases(
        type: 'affirmation',
        phrases: filteredAffirmations,
      );
    }
    if (filteredEmanations.length != customEmanations.length) {
      await repo.saveCustomHomePhrases(
        type: 'emanation',
        phrases: filteredEmanations,
      );
    }

    final selected = repo.getHomePhraseSelection();
    final selectedText = selected?.text.trim().toLowerCase();
    if (selectedText != null && legacy.contains(selectedText)) {
      await repo.clearHomePhraseSelection();
      if (!mounted) return;
      setState(() {
        _text = null;
      });
    }
  }
}

// ── Logros de hoy ─────────────────────────────────────────────────────────────

class _DiaryTodayCard extends StatelessWidget {
  const _DiaryTodayCard({
    required this.taskCount,
    required this.extraTaskCount,
    required this.noteCount,
  });

  final int taskCount;
  final int extraTaskCount;
  final int noteCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sectionTitleSize = (theme.textTheme.titleSmall?.fontSize ?? 15) - 1.2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LOGROS DE HOY',
                    style: theme.textTheme.titleSmall?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      fontSize: sectionTitleSize,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LogroChip(
                    icon: Icons.check_circle_outline,
                    label: '$taskCount práctica${taskCount == 1 ? '' : 's'}',
                    color: cs.primary,
                    expand: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LogroChip(
                    icon: Icons.task_alt_outlined,
                    label:
                        '$extraTaskCount extra${extraTaskCount == 1 ? '' : 's'}',
                    color: cs.tertiary,
                    expand: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LogroChip(
                    icon: Icons.edit_note_outlined,
                    label: '$noteCount nota${noteCount == 1 ? '' : 's'}',
                    color: cs.secondary,
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogroChip extends StatelessWidget {
  const _LogroChip({
    required this.icon,
    required this.label,
    required this.color,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          if (expand)
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            )
          else
            Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MandalasSectionBand extends StatelessWidget {
  const _MandalasSectionBand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.primary.withValues(alpha: 0.72),
          cs.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Center(
        child: Text(
          'MÁNDALAS',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w800,
            color: cs.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _CycleBadge extends StatelessWidget {
  const _CycleBadge({required this.cycle});

  final CycleModel cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final label = (archetype?.label ?? cycle.name).toUpperCase();

    return Row(
      children: [
        Expanded(child: Divider(color: Colors.transparent, thickness: 0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.transparent, thickness: 0)),
      ],
    );
  }
}

String _normalizedMandalaName(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'Mandala';
  return cleaned
      .split(' ')
      .map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}
