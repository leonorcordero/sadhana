import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.seed,
    required this.description,
  });

  final String id;
  final String name;
  final Color seed;
  final String description;
}

class AppSettings {
  const AppSettings({
    required this.name,
    required this.themeColor,
    required this.remindersEnabled,
    required this.reminderHours,
    required this.reminderContentType,
    required this.customReminderText,
    required this.iconPath,
    required this.textScale,
  });

  final String name;
  final Color themeColor;
  final bool remindersEnabled;
  final List<int> reminderHours;
  final String reminderContentType;
  final String customReminderText;
  final String? iconPath;
  final double textScale;

  static const defaultName = 'Sadhana';
  static const defaultColor = Color(0xFF5A7D5A); // sage
  static const defaultTextScale = 0.92;
  static const defaultReminderContentType = 'focus';
  static const defaultCustomReminderText = '';
  static const reminderContentTypes = [
    'focus',
    'pending',
    'motivational',
    'custom',
  ];

  static const palettes = [
    AppPalette(
      id: 'sage',
      name: 'Bosque Sagrado',
      seed: Color(0xFF5A7D5A),
      description: 'Verde estable y contemplativo',
    ),
    AppPalette(
      id: 'ocean',
      name: 'Océano Profundo',
      seed: Color(0xFF2F6F8A),
      description: 'Azul sereno con buen contraste',
    ),
    AppPalette(
      id: 'slate',
      name: 'Pizarra Ritual',
      seed: Color(0xFF4F6070),
      description: 'Frío elegante, lectura clara',
    ),
    AppPalette(
      id: 'earth',
      name: 'Tierra Tostada',
      seed: Color(0xFF8A5A3C),
      description: 'Cálido sobrio para enfoque',
    ),
    AppPalette(
      id: 'plum',
      name: 'Ciruela Nocturna',
      seed: Color(0xFF5B4A7A),
      description: 'Profundo, sin perder legibilidad',
    ),
    AppPalette(
      id: 'emerald',
      name: 'Esmeralda Viva',
      seed: Color(0xFF1F7A63),
      description: 'Energía limpia y moderna',
    ),
    AppPalette(
      id: 'indigo',
      name: 'Índigo Sutil',
      seed: Color(0xFF3F4F8C),
      description: 'Contraste fuerte y visual calmado',
    ),
    AppPalette(
      id: 'teal_smoke',
      name: 'Teal Humo',
      seed: Color(0xFF2D7C78),
      description: 'Azul verdoso equilibrado',
    ),
    AppPalette(
      id: 'moss',
      name: 'Musgo Profundo',
      seed: Color(0xFF6A7F32),
      description: 'Natural y orgánico',
    ),
    AppPalette(
      id: 'rose_earth',
      name: 'Rosa Tierra',
      seed: Color(0xFF915D6D),
      description: 'Cálido elegante',
    ),
    AppPalette(
      id: 'storm_blue',
      name: 'Azul Tormenta',
      seed: Color(0xFF2F5178),
      description: 'Firme, de lectura cómoda',
    ),
    AppPalette(
      id: 'charcoal_green',
      name: 'Carbón Verde',
      seed: Color(0xFF2E4A44),
      description: 'Profundo y sobrio',
    ),
    AppPalette(
      id: 'sandal',
      name: 'Sándalo',
      seed: Color(0xFF9A6F46),
      description: 'Terroso espiritual',
    ),
    AppPalette(
      id: 'twilight',
      name: 'Crepúsculo',
      seed: Color(0xFF5E4E9B),
      description: 'Índigo suave meditativo',
    ),
    AppPalette(
      id: 'wine',
      name: 'Vino Sutil',
      seed: Color(0xFF7B3F52),
      description: 'Profundo cálido con carácter',
    ),
    AppPalette(
      id: 'copper',
      name: 'Cobre Ritual',
      seed: Color(0xFFB06A3E),
      description: 'Tierra viva y elegante',
    ),
    AppPalette(
      id: 'amber',
      name: 'Ámbar Solar',
      seed: Color(0xFFC79A1B),
      description: 'Amarillo cálido y firme',
    ),
    AppPalette(
      id: 'mustard',
      name: 'Mostaza Viva',
      seed: Color(0xFFB88A10),
      description: 'Amarillo intenso terroso',
    ),
    AppPalette(
      id: 'fuchsia',
      name: 'Fucsia Sagrado',
      seed: Color(0xFFB23B8A),
      description: 'Fucsia vibrante controlado',
    ),
    AppPalette(
      id: 'magenta_plum',
      name: 'Magenta Ciruela',
      seed: Color(0xFF9A3F7A),
      description: 'Rosa profundo elegante',
    ),
    AppPalette(
      id: 'obsidian',
      name: 'Obsidiana',
      seed: Color(0xFF1B1B1F),
      description: 'Negro sobrio de alto contraste',
    ),
    AppPalette(
      id: 'charcoal',
      name: 'Carbón',
      seed: Color(0xFF2A2A2E),
      description: 'Oscuro neutro equilibrado',
    ),
    AppPalette(
      id: 'orange_fire',
      name: 'Naranja Fuego',
      seed: Color(0xFFC96C2A),
      description: 'Naranja energético y claro',
    ),
    AppPalette(
      id: 'burnt_orange',
      name: 'Naranja Quemado',
      seed: Color(0xFFAF5A26),
      description: 'Naranja oscuro terroso',
    ),
    AppPalette(
      id: 'salmon',
      name: 'Salmón Ritual',
      seed: Color(0xFFD98B7A),
      description: 'Salmón suave y cálido',
    ),
    AppPalette(
      id: 'coral',
      name: 'Coral Claro',
      seed: Color(0xFFCF7A6D),
      description: 'Rosa-naranja balanceado',
    ),
  ];

  static const defaultReminderHours = [9, 14, 20];

  AppSettings copyWith({
    String? name,
    Color? themeColor,
    bool? remindersEnabled,
    List<int>? reminderHours,
    String? reminderContentType,
    String? customReminderText,
    String? iconPath,
    double? textScale,
    bool clearIconPath = false,
  }) => AppSettings(
    name: name ?? this.name,
    themeColor: themeColor ?? this.themeColor,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderHours: reminderHours ?? this.reminderHours,
    reminderContentType: reminderContentType ?? this.reminderContentType,
    customReminderText: customReminderText ?? this.customReminderText,
    iconPath: clearIconPath ? null : (iconPath ?? this.iconPath),
    textScale: textScale ?? this.textScale,
  );
}
