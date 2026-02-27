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

  /// Color suave y consistente para cabeceras/bandas de mandala.
  Color softHeaderColor(ColorScheme scheme) {
    return Color.alphaBlend(
      colors.first.withValues(alpha: 0.22),
      scheme.surfaceContainerHigh,
    );
  }

  /// Icono minimalista para representar el tipo de mandala.
  IconData get minimalIcon {
    switch (key) {
      case 'fuego':
        return Icons.local_fire_department_outlined;
      case 'luz':
        return Icons.auto_awesome_outlined;
      case 'cosmico':
        return Icons.public_outlined;
      case 'estelar':
        return Icons.star_outline_rounded;
      case 'madre':
        return Icons.spa_outlined;
      case 'padre':
        return Icons.bolt_outlined;
      case 'fuente':
        return Icons.flare;
      case 'ganesha':
        return Icons.temple_buddhist_outlined;
      case 'hanuman':
        return Icons.sports_martial_arts;
      case 'krishna':
        return Icons.music_note_outlined;
      case 'ayunos':
        return Icons.restaurant_outlined;
      case 'redes_off':
        return Icons.wifi_off_outlined;
      case 'azucar_0':
        return Icons.no_food_outlined;
      case 'mowna':
        return Icons.record_voice_over_outlined;
      case 'no_harinas':
        return Icons.bakery_dining_outlined;
      default:
        return Icons.self_improvement_outlined;
    }
  }

  // ── Arquetipos predefinidos ────────────────────────────────────────────────

  static const fuego = MandalaArchetype(
    key: 'fuego',
    label: 'Fuego',
    emoji: '🔥',
    colors: [Color(0xFFC86A3A), Color(0xFFA0442F)],
  );

  static const luz = MandalaArchetype(
    key: 'luz',
    label: 'Luz',
    emoji: '✨',
    colors: [Color(0xFFD7B55D), Color(0xFFB28A3F)],
  );

  static const cosmico = MandalaArchetype(
    key: 'cosmico',
    label: 'Cósmico',
    emoji: '🌌',
    colors: [Color(0xFF3D3A68), Color(0xFF5A4E79)],
  );

  static const estelar = MandalaArchetype(
    key: 'estelar',
    label: 'Estelar',
    emoji: '🌠',
    colors: [Color(0xFF4A5C89), Color(0xFF5F6FA0)],
  );

  static const madre = MandalaArchetype(
    key: 'madre',
    label: 'Madre',
    emoji: '🌸',
    colors: [Color(0xFFD9A2AE), Color(0xFFBE7C8E)],
  );

  static const padre = MandalaArchetype(
    key: 'padre',
    label: 'Padre',
    emoji: '⚡',
    colors: [Color(0xFF315E7A), Color(0xFF447A8E)],
  );

  static const fuente = MandalaArchetype(
    key: 'fuente',
    label: 'Fuente',
    emoji: '🕯️',
    colors: [Color(0xFF63AFC0), Color(0xFF3D8C9D)],
  );

  static const ganesha = MandalaArchetype(
    key: 'ganesha',
    label: 'Ganesha',
    emoji: '🐘',
    colors: [Color(0xFFC58A45), Color(0xFFA66D32)],
  );

  static const hanuman = MandalaArchetype(
    key: 'hanuman',
    label: 'Hanuman',
    emoji: '🐒',
    colors: [Color(0xFF9B4A4A), Color(0xFF7A3636)],
  );

  static const krishna = MandalaArchetype(
    key: 'krishna',
    label: 'Krishna',
    emoji: '🪷',
    colors: [Color(0xFF426D9D), Color(0xFF2F5A84)],
  );

  static const ayunos = MandalaArchetype(
    key: 'ayunos',
    label: 'Ayunos',
    emoji: '🥣',
    colors: [Color(0xFF4D7A52), Color(0xFF345A3B)],
  );

  static const redesOff = MandalaArchetype(
    key: 'redes_off',
    label: 'Redes sociales OFF',
    emoji: '📵',
    colors: [Color(0xFF516B86), Color(0xFF384C63)],
  );

  static const azucar0 = MandalaArchetype(
    key: 'azucar_0',
    label: '0% Azúcar',
    emoji: '🚫🍬',
    colors: [Color(0xFF9B6A40), Color(0xFF7A4B2B)],
  );

  static const mowna = MandalaArchetype(
    key: 'mowna',
    label: 'Mowna',
    emoji: '🤫',
    colors: [Color(0xFF6C5B8E), Color(0xFF4F426B)],
  );

  static const noHarinas = MandalaArchetype(
    key: 'no_harinas',
    label: 'No harinas',
    emoji: '🥖',
    colors: [Color(0xFF8A6E4D), Color(0xFF6A5137)],
  );

  static const otro = MandalaArchetype(
    key: 'otro',
    label: 'Agregar otros',
    emoji: '✍️',
    colors: [Color(0xFF7A8594), Color(0xFF5A6472)],
  );

  static const List<MandalaArchetype> mandalaOptions = [
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

  static const List<MandalaArchetype> tapasyaOptions = [
    ayunos,
    redesOff,
    azucar0,
    mowna,
    noHarinas,
    otro,
  ];

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
    ayunos,
    redesOff,
    azucar0,
    mowna,
    noHarinas,
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
