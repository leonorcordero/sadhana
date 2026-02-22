import 'package:flutter/material.dart';

/// Define los arquetipos de mandala disponibles al crear un ciclo.
class MandalaArchetype {
  const MandalaArchetype({
    required this.key,
    required this.label,
    required this.emoji,
    required this.colors,
  });

  /// Identificador persistido en el modelo.
  final String key;
  final String label;
  final String emoji;

  /// Colores del gradiente de fondo [inicio, fin].
  final List<Color> colors;

  /// Construye el [LinearGradient] de fondo.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );

  /// Color de texto con contraste garantizado sobre el gradiente.
  Color get onColor {
    final luminance =
        (colors.first.computeLuminance() + colors.last.computeLuminance()) / 2;
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }

  // ── Arquetipos predefinidos ────────────────────────────────────────────────

  static const fuego = MandalaArchetype(
    key: 'fuego',
    label: 'Fuego',
    emoji: '🔥',
    colors: [Color(0xFFFF6B35), Color(0xFFC1121F)],
  );

  static const luz = MandalaArchetype(
    key: 'luz',
    label: 'Luz',
    emoji: '✨',
    colors: [Color(0xFFFFD166), Color(0xFFEF8C00)],
  );

  static const cosmico = MandalaArchetype(
    key: 'cosmico',
    label: 'Cósmico',
    emoji: '🌌',
    colors: [Color(0xFF1B1B3A), Color(0xFF6A0572)],
  );

  static const estelar = MandalaArchetype(
    key: 'estelar',
    label: 'Estelar',
    emoji: '🌠',
    colors: [Color(0xFF283593), Color(0xFF512DA8)],
  );

  static const madre = MandalaArchetype(
    key: 'madre',
    label: 'Madre',
    emoji: '🌸',
    colors: [Color(0xFFFFB3C1), Color(0xFFD63384)],
  );

  static const padre = MandalaArchetype(
    key: 'padre',
    label: 'Padre',
    emoji: '⚡',
    colors: [Color(0xFF023E8A), Color(0xFF0077B6)],
  );

  static const fuente = MandalaArchetype(
    key: 'fuente',
    label: 'Fuente',
    emoji: '💧',
    colors: [Color(0xFF48CAE4), Color(0xFF0096C7)],
  );

  static const ganesha = MandalaArchetype(
    key: 'ganesha',
    label: 'Ganesha',
    emoji: '🐘',
    colors: [Color(0xFFFF9F1C), Color(0xFFE36414)],
  );

  static const hanuman = MandalaArchetype(
    key: 'hanuman',
    label: 'Hanuman',
    emoji: '🏔️',
    colors: [Color(0xFFCC0000), Color(0xFF6D0000)],
  );

  static const krishna = MandalaArchetype(
    key: 'krishna',
    label: 'Krishna',
    emoji: '🪷',
    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
  );

  static const otro = MandalaArchetype(
    key: 'otro',
    label: 'Otro',
    emoji: '✍️',
    colors: [Color(0xFF8D99AE), Color(0xFF4A4E69)],
  );

  static const List<MandalaArchetype> all = [
    fuego,
    luz,
    cosmico,
    estelar,
    madre,
    padre,
    fuente,
    ganesha,
    hanuman,
    krishna,
    otro,
  ];

  static MandalaArchetype? fromKey(String? key) {
    if (key == null) return null;
    for (final a in all) {
      if (a.key == key) return a;
    }
    // Arquetipo personalizado: usa el gradiente de "otro"
    return MandalaArchetype(
      key: key,
      label: key,
      emoji: '✍️',
      colors: otro.colors,
    );
  }
}
