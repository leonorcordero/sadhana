import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sadhana/features/notes/presentation/notes_page.dart';
import 'package:sadhana/features/utilities/presentation/audio_player_page.dart';
import 'package:sadhana/features/utilities/presentation/audio_recorder_page.dart';
import 'package:sadhana/features/utilities/presentation/counter_page.dart';
import 'package:sadhana/features/utilities/presentation/links_page.dart';
import 'package:sadhana/features/utilities/presentation/moon_card_texts_page.dart';
import 'package:sadhana/features/utilities/presentation/stopwatch_page.dart';

class UtilitiesPage extends StatelessWidget {
  const UtilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 390;
    final tools = <_UtilityTool>[
      _UtilityTool(
        icon: Icons.note_alt_outlined,
        title: 'Hoja de notas',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotesPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.timer_outlined,
        title: 'Cronómetro',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const StopwatchPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.exposure_plus_1_outlined,
        title: 'Contador',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CounterPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.link_outlined,
        title: 'Links',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LinksPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.mic_none_outlined,
        title: 'Grabador\nde audio',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AudioRecorderPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.play_circle_outline,
        title: 'Reproductor\nde audio',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AudioPlayerPage()));
        },
      ),
      _UtilityTool(
        icon: Icons.dark_mode_outlined,
        title: 'Caja lunar',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MoonCardTextsPage()));
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Utilitarios'),
            Text(
              'Herramientas rápidas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: DecoratedBox(
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _UtilitiesHero(total: tools.length),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.widgets_outlined,
                          color: cs.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Panel de utilitarios',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accesos directos para mantener el foco en tu práctica.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      itemCount: tools.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isNarrow ? 2 : 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: isNarrow ? 1.35 : 1.2,
                      ),
                      itemBuilder: (context, index) {
                        final tool = tools[index];
                        return _UtilityStaggeredTile(
                          index: index,
                          child: _UtilityPanelTile(tool: tool),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilitiesHero extends StatelessWidget {
  const _UtilitiesHero({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.auto_awesome, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Espacio de herramientas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$total utilitarios disponibles',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Rápido',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilityTool {
  const _UtilityTool({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _UtilityPanelTile extends StatelessWidget {
  const _UtilityPanelTile({required this.tool});

  final _UtilityTool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          tool.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: cs.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                tool.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityStaggeredTile extends StatelessWidget {
  const _UtilityStaggeredTile({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = index.clamp(0, 10);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + (clamped * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: Transform.scale(scale: 0.97 + (0.03 * value), child: child),
          ),
        );
      },
    );
  }
}
