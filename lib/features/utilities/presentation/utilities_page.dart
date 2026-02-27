import 'package:flutter/material.dart';
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.widgets_outlined, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Panel de utilitarios',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    itemCount: tools.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.45,
                        ),
                    itemBuilder: (context, index) {
                      final tool = tools[index];
                      return _UtilityPanelTile(tool: tool);
                    },
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: tool.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tool.icon, color: cs.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              tool.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
