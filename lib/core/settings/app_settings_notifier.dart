import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/settings/app_settings.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';

const _keyName = 'app_name';
const _keyColor = 'app_theme_color';
const _keyRemindersEnabled = 'reminders_enabled';
const _keyReminderHours = 'reminder_hours';
const _keyReminderContentType = 'reminder_content_type';
const _keyCustomReminderText = 'reminder_custom_text';
const _keyIconPath = 'app_icon_path';
const _keyTextScale = 'app_text_scale';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._datasource) : super(_load(_datasource));

  final LocalStorageDatasource _datasource;

  static AppSettings _load(LocalStorageDatasource ds) {
    final name = ds.getSetting(_keyName) as String?;
    final colorValue = ds.getSetting(_keyColor) as int?;
    final remindersEnabled = ds.getSetting(_keyRemindersEnabled) as bool?;
    final reminderHoursRaw = ds.getSetting(_keyReminderHours) as List?;
    final reminderContentTypeRaw =
        ds.getSetting(_keyReminderContentType) as String?;
    final customReminderTextRaw =
        ds.getSetting(_keyCustomReminderText) as String?;
    final iconPath = ds.getSetting(_keyIconPath) as String?;
    final textScaleRaw = ds.getSetting(_keyTextScale);
    final textScale = textScaleRaw is num
        ? textScaleRaw.toDouble().clamp(0.85, 1.15)
        : AppSettings.defaultTextScale;
    final reminderHours = reminderHoursRaw == null
        ? AppSettings.defaultReminderHours
        : reminderHoursRaw.map((e) => e as int).toList();
    final reminderContentType =
        AppSettings.reminderContentTypes.contains(reminderContentTypeRaw)
        ? reminderContentTypeRaw!
        : AppSettings.defaultReminderContentType;
    final customReminderText = (customReminderTextRaw ?? '').trim();
    return AppSettings(
      name: name ?? AppSettings.defaultName,
      themeColor: colorValue != null
          ? Color(colorValue)
          : AppSettings.defaultColor,
      remindersEnabled: remindersEnabled ?? true,
      reminderHours: reminderHours,
      reminderContentType: reminderContentType,
      customReminderText: customReminderText,
      iconPath: iconPath,
      textScale: textScale,
    );
  }

  Future<void> setName(String name) async {
    await _datasource.saveSetting(
      _keyName,
      name.trim().isEmpty ? AppSettings.defaultName : name.trim(),
    );
    state = state.copyWith(
      name: name.trim().isEmpty ? AppSettings.defaultName : name.trim(),
    );
  }

  Future<void> setColor(Color color) async {
    await _datasource.saveSetting(_keyColor, color.toARGB32());
    state = state.copyWith(themeColor: color);
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await _datasource.saveSetting(_keyRemindersEnabled, enabled);
    state = state.copyWith(remindersEnabled: enabled);
  }

  Future<void> setReminderHours(List<int> hours) async {
    final sanitized = List<int>.from(hours)
      ..sort()
      ..retainWhere((h) => h >= 0 && h <= 23);
    if (sanitized.isEmpty) return;

    await _datasource.saveSetting(_keyReminderHours, sanitized);
    state = state.copyWith(reminderHours: sanitized);
  }

  Future<void> setReminderContentType(String contentType) async {
    if (!AppSettings.reminderContentTypes.contains(contentType)) return;
    await _datasource.saveSetting(_keyReminderContentType, contentType);
    state = state.copyWith(reminderContentType: contentType);
  }

  Future<void> setCustomReminderText(String text) async {
    final normalized = text.trim();
    await _datasource.saveSetting(_keyCustomReminderText, normalized);
    state = state.copyWith(customReminderText: normalized);
  }

  Future<void> setIconPath(String? path) async {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _datasource.deleteSetting(_keyIconPath);
      state = state.copyWith(clearIconPath: true);
      return;
    }
    await _datasource.saveSetting(_keyIconPath, normalized);
    state = state.copyWith(iconPath: normalized);
  }

  Future<void> setTextScale(double value) async {
    final sanitized = value.clamp(0.85, 1.15);
    await _datasource.saveSetting(_keyTextScale, sanitized);
    state = state.copyWith(textScale: sanitized);
  }
}
