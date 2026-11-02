import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/task_priority.dart';

/// Persists user preferences in shared preferences (not SQLite).
class SettingsService {
  SettingsService({this.preferences});

  static final SettingsService instance = SettingsService();

  static const String _themeKey = 'settings.themeMode';
  static const String _notificationsKey = 'settings.notificationsEnabled';
  static const String _priorityKey = 'settings.defaultPriority';
  static const String _startOfWeekKey = 'settings.startOfWeek';
  static const String _sortKey = 'settings.sortOption';

  SharedPreferences? preferences;

  Future<SharedPreferences> get _prefs async {
    return preferences ??= await SharedPreferences.getInstance();
  }

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await _prefs;
    final String? themeName = prefs.getString(_themeKey);

    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      defaultPriority: TaskPriority.fromValue(
        prefs.getInt(_priorityKey) ?? TaskPriority.medium.value,
      ),
      startOfWeek: prefs.getInt(_startOfWeekKey) ?? DateTime.monday,
      sortOption: TaskSortOption.fromName(prefs.getString(_sortKey)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_themeKey, settings.themeMode.name);
    await prefs.setBool(_notificationsKey, settings.notificationsEnabled);
    await prefs.setInt(_priorityKey, settings.defaultPriority.value);
    await prefs.setInt(_startOfWeekKey, settings.startOfWeek);
    await prefs.setString(_sortKey, settings.sortOption.name);
  }
}
