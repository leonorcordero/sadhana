import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    required this.name,
    required this.themeColor,
    required this.remindersEnabled,
    required this.reminderHours,
  });

  final String name;
  final Color themeColor;
  final bool remindersEnabled;
  final List<int> reminderHours;

  static const defaultName = 'Sadhana';
  static const defaultColor = Color(0xFF5A7D5A); // sage

  static const presetColors = [
    // Naturales profundos
    Color(0xFF5A7D5A), // sage (default)
    Color(0xFF4E6F67), // eucalipto profundo
    Color(0xFF5D6678), // pizarra azul
    Color(0xFF7A6A58), // tierra tostada
    Color(0xFF6E6275), // ciruela humo

    // Medios equilibrados
    Color(0xFF7FA184), // verde hoja
    Color(0xFF6F98A1), // azul laguna
    Color(0xFF8B95B5), // índigo suave
    Color(0xFFB38A73), // terracota suave
    Color(0xFFA38EA8), // malva gris

    // Claros útiles (no excesivos)
    Color(0xFFD5E4D4), // salvia clara
    Color(0xFFD3E5E3), // menta clara
    Color(0xFFDCE5F2), // cielo perla
    Color(0xFFE8DECF), // arena clara
    Color(0xFFE7E0EA), // lavanda clara
  ];

  static const defaultReminderHours = [9, 14, 20];

  AppSettings copyWith({
    String? name,
    Color? themeColor,
    bool? remindersEnabled,
    List<int>? reminderHours,
  }) => AppSettings(
    name: name ?? this.name,
    themeColor: themeColor ?? this.themeColor,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderHours: reminderHours ?? this.reminderHours,
  );
}
