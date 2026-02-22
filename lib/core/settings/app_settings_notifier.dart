import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/settings/app_settings.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';

const _keyName = 'app_name';
const _keyColor = 'app_theme_color';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._datasource)
      : super(_load(_datasource));

  final LocalStorageDatasource _datasource;

  static AppSettings _load(LocalStorageDatasource ds) {
    final name = ds.getSetting(_keyName) as String?;
    final colorValue = ds.getSetting(_keyColor) as int?;
    return AppSettings(
      name: name ?? AppSettings.defaultName,
      themeColor: colorValue != null
          ? Color(colorValue)
          : AppSettings.defaultColor,
    );
  }

  Future<void> setName(String name) async {
    await _datasource.saveSetting(_keyName, name.trim().isEmpty ? AppSettings.defaultName : name.trim());
    state = state.copyWith(name: name.trim().isEmpty ? AppSettings.defaultName : name.trim());
  }

  Future<void> setColor(Color color) async {
    await _datasource.saveSetting(_keyColor, color.toARGB32());
    state = state.copyWith(themeColor: color);
  }
}
