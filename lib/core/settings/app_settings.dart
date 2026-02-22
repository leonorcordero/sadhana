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
    Color(0xFF5A7D5A), // sage (default)
    Color(0xFF0B6E4F), // verde esmeralda
    Color(0xFF00695C), // teal profundo
    Color(0xFF1565C0), // azul índigo
    Color(0xFF6A1B9A), // violeta
    Color(0xFFC62828), // rojo coral
    Color(0xFFE65100), // naranja tierra
    Color(0xFF37474F), // gris pizarra
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
