import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/calendar_custom_event.dart';
import 'package:sadhana/data/models/calendar_external_event.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/diary_entry_model.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/note_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/models/wednesday_affirmation_model.dart';
import 'package:sadhana/features/streaks/application/streak_calculator.dart';

class SadhanaRepository {
  SadhanaRepository(this._datasource);

  final LocalStorageDatasource _datasource;
  static const _streakCalculator = StreakCalculator();
  static const _homePhraseTypeKey = 'home_phrase_type';
  static const _homePhraseTextKey = 'home_phrase_text';
  static const _customAffirmationsKey = 'custom_affirmations';
  static const _customEmanationsKey = 'custom_emanations';
  static const _externalCalendarConnectedKey = 'connected';
  static const _externalCalendarSourceUrlKey = 'sourceUrl';
  static const _externalCalendarLastSyncAtKey = 'lastSyncAt';
  static const _resourceFoldersKey = 'resource_folders';
  static const _resourceFoldersOrderKey = 'resource_folders_order';
  static const _resourceItemsOrderByFolderKey =
      'resource_items_order_by_folder';
  static const _wednesdayAffirmationKey = 'wednesday_affirmation';
  static const _moonNightWarningTextKey = 'moon_night_warning_text';
  static const _moonDayOnlyTextKey = 'moon_day_only_text';
  static const defaultMoonNightWarningText =
      'No se recomienda hacer sadhana PM';
  static const defaultMoonDayOnlyText = 'Sadhana solo de día.';

  List<CycleModel> getCycles() {
    final cycles = _datasource.getCycles();
    cycles.sort((a, b) => a.name.compareTo(b.name));
    return cycles;
  }

  Future<CycleModel> createCycle(CycleModel cycle) async {
    await _datasource.saveCycle(cycle);
    return cycle;
  }

  Future<CycleModel> updateCycle(CycleModel updated) async {
    final existing = _datasource.getCycles().firstWhere(
      (cycle) => cycle.id == updated.id,
    );

    if (existing.isActive && existing.sankalpa != updated.sankalpa) {
      throw StateError('No puedes editar el sankalpa de un ciclo activo.');
    }

    await _datasource.saveCycle(updated);
    return updated;
  }

  Future<void> deleteCycle(String cycleId) async {
    final tasks = getTasksByCycle(cycleId);
    for (final task in tasks) {
      await _datasource.deleteTask(task.id);
    }

    final logs = getLogsByCycle(cycleId);
    for (final log in logs) {
      await _datasource.deleteDayLog(log.id);
    }

    await _datasource.deleteSetting('last_closed_date_$cycleId');
    await _datasource.deleteCycle(cycleId);
  }

  CycleModel? getActiveCycle() {
    final cycles = _datasource.getCycles();
    for (final cycle in cycles) {
      if (cycle.isActive) {
        return cycle;
      }
    }
    return null;
  }

  CycleModel? getCycleById(String id) {
    for (final cycle in _datasource.getCycles()) {
      if (cycle.id == id) return cycle;
    }
    return null;
  }

  Future<void> startCycle(String cycleId) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;
    if (cycle.isActive) return;
    await _datasource.saveCycle(cycle.copyWith(isActive: true));
  }

  Future<void> stopCycle(String cycleId) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;
    await _datasource.saveCycle(cycle.copyWith(isActive: false));
  }

  Future<void> restartCycle(String cycleId) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;

    // Reinicio completo del marcador diario: elimina los checks guardados.
    final logs = getLogsByCycle(cycleId);
    for (final log in logs) {
      await _datasource.deleteDayLog(log.id);
    }
    await _datasource.deleteSetting('last_closed_date_$cycleId');

    await _datasource.saveCycle(
      cycle.copyWith(
        currentDay: 1,
        startDay: 1,
        streakCurrent: 0,
        isActive: true,
      ),
    );
  }

  List<TaskModel> getTasksByCycle(String cycleId) {
    return _datasource
        .getTasks()
        .where((task) => task.cycleId == cycleId)
        .toList(growable: false);
  }

  Future<TaskModel> createTask(TaskModel task) async {
    await _datasource.saveTask(task);
    return task;
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    await _datasource.saveTask(task);
    return task;
  }

  Future<void> deleteTask(String taskId) async {
    final task = _datasource.getTasks().firstWhere((t) => t.id == taskId);
    final cycle = getCycleById(task.cycleId);

    if (cycle != null && cycle.isActive) {
      throw StateError('No puedes eliminar tareas de un ciclo activo.');
    }

    await _datasource.deleteTask(taskId);
  }

  DayLogModel getOrCreateDayLog({
    required String cycleId,
    required DateTime date,
  }) {
    final key = _dayLogId(cycleId, date);
    final existing = _datasource.getDayLog(key);
    if (existing != null) return existing;

    final created = DayLogModel(
      id: key,
      cycleId: cycleId,
      date: DateUtilsX.dateKey(date),
      completedTaskIds: <String>[],
      closed: false,
      wasComplete: false,
    );
    _datasource.saveDayLog(created);
    return created;
  }

  Future<DayLogModel> toggleTaskCompleted({
    required String cycleId,
    required String taskId,
    required DateTime date,
    required bool completed,
  }) async {
    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    if (log.closed) return log;

    final ids = List<String>.from(log.completedTaskIds);
    if (completed) {
      if (!ids.contains(taskId)) ids.add(taskId);
    } else {
      ids.remove(taskId);
    }

    final updated = log.copyWith(completedTaskIds: ids);
    await _datasource.saveDayLog(updated);
    return updated;
  }

  bool isDayComplete({required String cycleId, required DateTime date}) {
    final tasks = getTasksByCycle(cycleId).where((t) => t.isActive).toList();
    if (tasks.isEmpty) return false;

    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    final completedCount = log.completedTaskIds
        .where((id) => tasks.any((task) => task.id == id))
        .length;
    return completedCount == tasks.length;
  }

  Future<void> closeDay({
    required String cycleId,
    required DateTime date,
  }) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;

    final complete = isDayComplete(cycleId: cycleId, date: date);
    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    final closedLog = log.copyWith(closed: true, wasComplete: complete);

    final streak = _streakCalculator.next(
      current: cycle.streakCurrent,
      max: cycle.streakMax,
      dayComplete: complete,
    );
    final streakCurrent = streak.current;
    final streakMax = streak.max;

    var nextDay = cycle.currentDay + 1;
    var active = cycle.isActive;
    if (nextDay > cycle.duration) {
      nextDay = cycle.duration;
      active = false;
    }

    final updatedCycle = cycle.copyWith(
      streakCurrent: streakCurrent,
      streakMax: streakMax,
      currentDay: nextDay,
      isActive: active,
    );

    await _datasource.saveDayLog(closedLog);
    await _datasource.saveCycle(updatedCycle);

    await _datasource.saveSetting(
      'last_closed_date_$cycleId',
      DateUtilsX.dateKey(date),
    );
  }

  Future<void> closePendingDaysUntilYesterday() async {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    final activeCycles = _datasource
        .getCycles()
        .where((c) => c.isActive)
        .toList();
    for (final cycle in activeCycles) {
      final raw =
          _datasource.getSetting('last_closed_date_${cycle.id}') as String?;
      DateTime cursor;
      if (raw == null) {
        cursor = yesterday;
      } else {
        cursor = DateUtilsX.fromDateKey(raw).add(const Duration(days: 1));
      }

      while (!cursor.isAfter(yesterday)) {
        await closeDay(cycleId: cycle.id, date: cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
  }

  Future<void> closeTodayForActiveCycles() async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final activeCycles = _datasource
        .getCycles()
        .where((c) => c.isActive)
        .toList();
    for (final cycle in activeCycles) {
      await closeDay(cycleId: cycle.id, date: date);
    }
  }

  DashboardSnapshot getDashboardSnapshot({required DateTime date}) {
    final cycle = getActiveCycle();
    if (cycle == null) {
      return DashboardSnapshot(
        activeCycle: null,
        tasks: const [],
        todayLog: null,
        completionRatio: 0,
      );
    }
    return getDashboardSnapshotForCycle(cycleId: cycle.id, date: date);
  }

  DashboardSnapshot getDashboardSnapshotForCycle({
    required String cycleId,
    required DateTime date,
  }) {
    final cycle = getCycleById(cycleId);
    if (cycle == null) {
      return DashboardSnapshot(
        activeCycle: null,
        tasks: const [],
        todayLog: null,
        completionRatio: 0,
      );
    }

    final tasks = getTasksByCycle(cycle.id).where((t) => t.isActive).toList();
    final log = getOrCreateDayLog(cycleId: cycle.id, date: date);

    final done = log.completedTaskIds
        .where((id) => tasks.any((t) => t.id == id))
        .length;
    final ratio = tasks.isEmpty ? 0.0 : done / tasks.length;

    return DashboardSnapshot(
      activeCycle: cycle,
      tasks: tasks,
      todayLog: log,
      completionRatio: ratio,
    );
  }

  Map<DateTime, bool> getCalendarCompletionMap(String cycleId) {
    final map = <DateTime, bool>{};
    for (final log in _datasource.getDayLogs().where(
      (l) => l.cycleId == cycleId,
    )) {
      map[DateUtilsX.fromDateKey(log.date)] = log.wasComplete;
    }
    return map;
  }

  List<DayLogModel> getLogsByCycle(String cycleId) {
    return _datasource.getDayLogs().where((l) => l.cycleId == cycleId).toList();
  }

  List<CalendarCustomEvent> getCustomEvents() {
    return _datasource
        .getCustomEventsRaw()
        .map(CalendarCustomEvent.fromMap)
        .toList();
  }

  List<CalendarCustomEvent> getCustomEventsForDate(DateTime date) {
    final key = DateUtilsX.dateKey(date);
    return getCustomEvents().where((e) => e.dateKey == key).toList();
  }

  List<CalendarExternalEvent> getExternalEvents() {
    return _datasource
        .getExternalEventsRaw()
        .map(CalendarExternalEvent.fromMap)
        .toList();
  }

  List<CalendarExternalEvent> getExternalEventsForDate(DateTime date) {
    final key = DateUtilsX.dateKey(date);
    return getExternalEvents().where((e) => e.dateKey == key).toList();
  }

  Future<void> upsertExternalEvents(List<CalendarExternalEvent> events) async {
    final merged = <String, CalendarExternalEvent>{};
    for (final item in getExternalEvents()) {
      merged[item.id] = item;
    }
    for (final item in events) {
      merged[item.id] = item;
    }
    await _datasource.saveExternalEventsRaw(
      merged.values.map((e) => e.toMap()).toList(growable: false),
    );
  }

  Map<String, dynamic> getExternalCalendarConfig() {
    final raw = _datasource.getExternalCalendarConfig();
    return {
      _externalCalendarConnectedKey: raw[_externalCalendarConnectedKey] == true,
      _externalCalendarSourceUrlKey:
          (raw[_externalCalendarSourceUrlKey] as String?) ?? '',
      _externalCalendarLastSyncAtKey:
          (raw[_externalCalendarLastSyncAtKey] as String?) ?? '',
    };
  }

  Future<void> setExternalCalendarSourceUrl(String sourceUrl) async {
    final current = getExternalCalendarConfig();
    await _datasource.saveExternalCalendarConfig({
      ...current,
      _externalCalendarConnectedKey: sourceUrl.trim().isNotEmpty,
      _externalCalendarSourceUrlKey: sourceUrl.trim(),
    });
  }

  Future<int> syncExternalCalendar() async {
    final config = getExternalCalendarConfig();
    final sourceUrl = (config[_externalCalendarSourceUrlKey] as String?) ?? '';
    if (sourceUrl.trim().isEmpty) return 0;

    final icsUrl = _resolveExternalCalendarIcsUrl(sourceUrl.trim());
    final response = await http.get(Uri.parse(icsUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'No se pudo descargar el calendario (HTTP ${response.statusCode}).',
      );
    }

    final events = _parseIcsEvents(response.body);
    await _datasource.saveExternalEventsRaw(
      events.map((e) => e.toMap()).toList(growable: false),
    );

    // Tras una sincronización nueva, mostramos todos los eventos importados
    // para evitar que queden ocultos por filtros anteriores.
    await _datasource.saveExternalHiddenEventIds(<String>{});

    await markExternalCalendarSyncNow();
    return events.length;
  }

  Future<void> markExternalCalendarSyncNow() async {
    final current = getExternalCalendarConfig();
    await _datasource.saveExternalCalendarConfig({
      ...current,
      _externalCalendarLastSyncAtKey: DateTime.now().toIso8601String(),
    });
  }

  Set<String> getHiddenExternalEventIds() {
    return _datasource.getExternalHiddenEventIds();
  }

  Set<String> getHiddenExternalGroupKeys() {
    return _datasource.getExternalHiddenGroupKeys();
  }

  Set<String> getHiddenExternalTitleKeys() {
    return _datasource.getExternalHiddenTitleKeys();
  }

  Future<void> setExternalEventVisible({
    required String eventId,
    required bool visible,
  }) async {
    final hidden = getHiddenExternalEventIds();
    if (visible) {
      hidden.remove(eventId);
    } else {
      hidden.add(eventId);
    }
    await _datasource.saveExternalHiddenEventIds(hidden);
  }

  Future<void> setExternalGroupVisible({
    required String groupKey,
    required bool visible,
  }) async {
    final hidden = getHiddenExternalGroupKeys();
    if (visible) {
      hidden.remove(groupKey);
    } else {
      hidden.add(groupKey);
    }
    await _datasource.saveExternalHiddenGroupKeys(hidden);
  }

  Future<void> setExternalTitleVisible({
    required String titleKey,
    required bool visible,
  }) async {
    final hidden = getHiddenExternalTitleKeys();
    if (visible) {
      hidden.remove(titleKey);
    } else {
      hidden.add(titleKey);
    }
    await _datasource.saveExternalHiddenTitleKeys(hidden);
  }

  bool isExternalEventVisible(String eventId) {
    for (final event in getExternalEvents()) {
      if (event.id == eventId) {
        return isExternalEventVisibleModel(event);
      }
    }
    return false;
  }

  bool isExternalEventVisibleModel(CalendarExternalEvent event) {
    final hiddenEventIds = getHiddenExternalEventIds();
    if (hiddenEventIds.contains(event.id)) return false;
    final hiddenGroups = getHiddenExternalGroupKeys();
    final hiddenTitles = getHiddenExternalTitleKeys();
    final groupKey = externalGroupKeyFromTitle(event.title);
    final titleKey = externalTitleKeyFromTitle(event.title);
    return !hiddenGroups.contains(groupKey) && !hiddenTitles.contains(titleKey);
  }

  List<String> getVisibleEventTitlesForDate(DateTime date) {
    final titles = <String>[];
    for (final event in getCustomEventsForDate(date)) {
      titles.add(event.title);
    }
    for (final event in getExternalEventsForDate(date)) {
      if (isExternalEventVisibleModel(event)) {
        titles.add(event.title);
      }
    }
    return titles;
  }

  String externalGroupKeyFromTitle(String title) {
    final normalized = _normalizeTextKey(title);
    if (normalized.isEmpty) return 'sin titulo';
    final words = normalized
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'sin titulo';
    if (words.length == 1) return words.first;
    return '${words[0]} ${words[1]}';
  }

  String externalTitleKeyFromTitle(String title) {
    final normalized = _normalizeTextKey(title);
    return normalized.isEmpty ? 'sin titulo' : normalized;
  }

  String _normalizeTextKey(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  String _resolveExternalCalendarIcsUrl(String input) {
    final uri = Uri.tryParse(input);
    final src = uri?.queryParameters['src']?.trim();
    if (src != null && src.isNotEmpty) {
      return 'https://calendar.google.com/calendar/ical/'
          '${Uri.encodeComponent(src)}/public/basic.ics';
    }

    if (input.toLowerCase().endsWith('.ics')) {
      return input;
    }

    if (input.contains('@') && !input.contains('/')) {
      return 'https://calendar.google.com/calendar/ical/'
          '${Uri.encodeComponent(input)}/public/basic.ics';
    }

    throw const FormatException('Link de calendario no válido.');
  }

  List<CalendarExternalEvent> _parseIcsEvents(String rawIcs) {
    final lines = _unfoldIcsLines(rawIcs);
    final events = <CalendarExternalEvent>[];
    var inEvent = false;
    String? uid;
    String? summary;
    String? description;
    String? dtStart;

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        uid = null;
        summary = null;
        description = null;
        dtStart = null;
        continue;
      }
      if (line == 'END:VEVENT') {
        if (inEvent && summary != null && dtStart != null) {
          final dateKey = _parseIcsDateKey(dtStart);
          if (dateKey != null) {
            final eventSummary = summary;
            final eventDescription = description;
            final sourceUid = (uid == null || uid.trim().isEmpty)
                ? '${eventSummary}_$dateKey'
                : uid;
            final stableId = 'ext_${Uri.encodeComponent(sourceUid)}_$dateKey';
            events.add(
              CalendarExternalEvent(
                id: stableId,
                title: _decodeIcsText(eventSummary),
                description: eventDescription == null
                    ? null
                    : _decodeIcsText(eventDescription),
                dateKey: dateKey,
                sourceLabel: 'Google Calendar',
              ),
            );
          }
        }
        inEvent = false;
        continue;
      }
      if (!inEvent) continue;

      final sep = line.indexOf(':');
      if (sep <= 0) continue;
      final rawKey = line.substring(0, sep).trim();
      final value = line.substring(sep + 1).trim();
      final key = rawKey.split(';').first.toUpperCase();

      switch (key) {
        case 'UID':
          uid = value;
          break;
        case 'SUMMARY':
          summary = value;
          break;
        case 'DESCRIPTION':
          description = value;
          break;
        case 'DTSTART':
          dtStart = value;
          break;
      }
    }

    return events;
  }

  List<String> _unfoldIcsLines(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final unfolded = <String>[];
    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }
    return unfolded;
  }

  String? _parseIcsDateKey(String value) {
    final match = RegExp(r'(\d{8})').firstMatch(value);
    if (match == null) return null;
    final raw = match.group(1)!;
    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(4, 6));
    final day = int.tryParse(raw.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateUtilsX.dateKey(DateTime(year, month, day));
  }

  String _decodeIcsText(String text) {
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', r'\')
        .trim();
  }

  Future<void> upsertCustomEvent(CalendarCustomEvent event) async {
    final events = getCustomEvents();
    var replaced = false;
    final next = <CalendarCustomEvent>[];
    for (final item in events) {
      if (item.id == event.id) {
        next.add(event);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) next.add(event);

    await _datasource.saveCustomEventsRaw(
      next.map((e) => e.toMap()).toList(growable: false),
    );
  }

  Future<void> deleteCustomEvent(String eventId) async {
    final events = getCustomEvents();
    final next = events.where((e) => e.id != eventId).toList();
    await _datasource.saveCustomEventsRaw(
      next.map((e) => e.toMap()).toList(growable: false),
    );
  }

  String googleCalendarCreateUrl(CalendarCustomEvent event) {
    final day = DateUtilsX.fromDateKey(event.dateKey);
    final endDay = day.add(const Duration(days: 1));
    final start =
        '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final end =
        '${endDay.year.toString().padLeft(4, '0')}${endDay.month.toString().padLeft(2, '0')}${endDay.day.toString().padLeft(2, '0')}';
    final params = {
      'text': event.title,
      'details': event.description ?? '',
      'dates': '$start/$end',
    };
    return Uri.https(
      'calendar.google.com',
      '/calendar/u/0/r/eventedit',
      params,
    ).toString();
  }

  ({int total, int completed, bool closed, bool complete}) getDaySummary({
    required String cycleId,
    required DateTime date,
  }) {
    final tasks = getTasksByCycle(cycleId).where((t) => t.isActive).toList();
    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    final completed = log.completedTaskIds
        .where((id) => tasks.any((t) => t.id == id))
        .length;
    final complete = tasks.isNotEmpty && completed == tasks.length;
    return (
      total: tasks.length,
      completed: completed,
      closed: log.closed,
      complete: complete,
    );
  }

  // ── Diario ────────────────────────────────────────────────────────────────

  DiaryEntryModel getDiaryEntry(DateTime date) {
    final key = DateUtilsX.dateKey(date);
    final all = _datasource.getDiaryEntriesRaw();
    try {
      final raw = all.firstWhere((e) => e['dateKey'] == key);
      return DiaryEntryModel.fromMap(raw);
    } catch (_) {
      return DiaryEntryModel(
        dateKey: key,
        manualEntries: const [],
        extraTasks: const [],
      );
    }
  }

  Future<void> _saveDiaryEntry(DiaryEntryModel entry) async {
    final all = _datasource.getDiaryEntriesRaw();
    final next = <Map<String, dynamic>>[];
    var found = false;
    for (final e in all) {
      if (e['dateKey'] == entry.dateKey) {
        next.add(entry.toMap());
        found = true;
      } else {
        next.add(e);
      }
    }
    if (!found) next.add(entry.toMap());
    await _datasource.saveDiaryEntriesRaw(next);
  }

  Future<void> addManualDiaryEntry(DateTime date, String text) async {
    final existing = getDiaryEntry(date);
    await _saveDiaryEntry(
      existing.copyWith(manualEntries: [...existing.manualEntries, text]),
    );
  }

  Future<void> removeManualDiaryEntry(DateTime date, int index) async {
    final existing = getDiaryEntry(date);
    final next = List<String>.from(existing.manualEntries)..removeAt(index);
    await _saveDiaryEntry(existing.copyWith(manualEntries: next));
  }

  Future<void> addExtraDiaryTask(DateTime date, String text) async {
    final existing = getDiaryEntry(date);
    await _saveDiaryEntry(
      existing.copyWith(extraTasks: [...existing.extraTasks, text]),
    );
  }

  Future<void> removeExtraDiaryTask(DateTime date, int index) async {
    final existing = getDiaryEntry(date);
    final next = List<String>.from(existing.extraTasks)..removeAt(index);
    await _saveDiaryEntry(existing.copyWith(extraTasks: next));
  }

  List<({String cycleName, String taskTitle})> getCompletedMandalaTasksForDay(
    DateTime date,
  ) {
    final result = <({String cycleName, String taskTitle})>[];
    for (final cycle in getCycles()) {
      final logKey = _dayLogId(cycle.id, date);
      final log = _datasource.getDayLog(logKey);
      if (log == null || log.completedTaskIds.isEmpty) continue;
      final tasks = getTasksByCycle(cycle.id);
      for (final task in tasks) {
        if (log.completedTaskIds.contains(task.id)) {
          result.add((cycleName: cycle.name, taskTitle: task.title));
        }
      }
    }
    return result;
  }

  ({int daysWithPractice, int totalPractices}) getPracticeWindowStats({
    required int days,
    DateTime? untilDate,
  }) {
    final end = untilDate ?? DateTime.now();
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    var daysWithPractice = 0;
    var totalPractices = 0;

    for (var offset = 0; offset < days; offset++) {
      final day = normalizedEnd.subtract(Duration(days: offset));
      final completedMandalaTasks = getCompletedMandalaTasksForDay(day).length;
      final extraTasks = getDiaryEntry(day).extraTasks.length;
      final totalForDay = completedMandalaTasks + extraTasks;
      if (totalForDay > 0) {
        daysWithPractice++;
        totalPractices += totalForDay;
      }
    }

    return (daysWithPractice: daysWithPractice, totalPractices: totalPractices);
  }

  Future<String> exportBackupJson() async {
    final map = await _datasource.exportAllAsJsonMap();
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<void> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Formato de backup invalido');
    }
    await _datasource.importAllFromJsonMap(decoded);
  }

  String motivationalQuote({required bool dayComplete}) {
    final options = dayComplete
        ? AppConstants.rewardQuotes
        : AppConstants.reminderQuotes;

    final seed = DateUtilsX.dateKey(DateTime.now()).hashCode;
    return options[seed.abs() % options.length];
  }

  ({String type, String text})? getHomePhraseSelection() {
    final type = _datasource.getSetting(_homePhraseTypeKey) as String?;
    final text = _datasource.getSetting(_homePhraseTextKey) as String?;
    if (type == null || text == null || text.trim().isEmpty) return null;
    return (type: type, text: text);
  }

  Future<void> saveHomePhraseSelection({
    required String type,
    required String text,
  }) async {
    await _datasource.saveSetting(_homePhraseTypeKey, type);
    await _datasource.saveSetting(_homePhraseTextKey, text);
  }

  List<String> getCustomHomePhrases({required String type}) {
    final key = _phraseKeyForType(type);
    final raw = _datasource.getSetting(key) as List?;
    if (raw == null) return <String>[];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> addCustomHomePhrase({
    required String type,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final existing = getCustomHomePhrases(type: type);
    final exists = existing.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) return;
    final next = <String>[...existing, normalized];
    await _datasource.saveSetting(_phraseKeyForType(type), next);
  }

  Future<void> removeCustomHomePhrase({
    required String type,
    required String text,
  }) async {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final existing = getCustomHomePhrases(type: type);
    final next = existing
        .where((item) => item.trim().toLowerCase() != normalized)
        .toList(growable: false);
    await _datasource.saveSetting(_phraseKeyForType(type), next);
  }

  Future<bool> updateCustomHomePhrase({
    required String type,
    required String previousText,
    required String nextText,
  }) async {
    final prevNormalized = previousText.trim();
    final nextNormalized = nextText.trim();
    if (prevNormalized.isEmpty || nextNormalized.isEmpty) return false;

    final existing = getCustomHomePhrases(type: type).toList(growable: true);
    final previousIndex = existing.indexWhere(
      (item) => item.toLowerCase() == prevNormalized.toLowerCase(),
    );
    if (previousIndex < 0) return false;

    final duplicateIndex = existing.indexWhere(
      (item) => item.toLowerCase() == nextNormalized.toLowerCase(),
    );
    if (duplicateIndex >= 0 && duplicateIndex != previousIndex) return false;

    existing[previousIndex] = nextNormalized;
    await _datasource.saveSetting(
      _phraseKeyForType(type),
      existing.toList(growable: false),
    );
    return true;
  }

  Future<void> saveCustomHomePhrases({
    required String type,
    required List<String> phrases,
  }) async {
    final normalized = phrases
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await _datasource.saveSetting(_phraseKeyForType(type), normalized);
  }

  Future<void> clearHomePhraseSelection() async {
    await _datasource.deleteSetting(_homePhraseTypeKey);
    await _datasource.deleteSetting(_homePhraseTextKey);
  }

  ({String nightWarningText, String dayOnlyText}) getMoonCardTexts() {
    final savedNight =
        (_datasource.getSetting(_moonNightWarningTextKey) as String?)?.trim();
    final savedDay = (_datasource.getSetting(_moonDayOnlyTextKey) as String?)
        ?.trim();

    return (
      nightWarningText: (savedNight == null || savedNight.isEmpty)
          ? defaultMoonNightWarningText
          : savedNight,
      dayOnlyText: (savedDay == null || savedDay.isEmpty)
          ? defaultMoonDayOnlyText
          : savedDay,
    );
  }

  Future<void> saveMoonCardTexts({
    required String nightWarningText,
    required String dayOnlyText,
  }) async {
    final night = nightWarningText.trim().isEmpty
        ? defaultMoonNightWarningText
        : nightWarningText.trim();
    final day = dayOnlyText.trim().isEmpty
        ? defaultMoonDayOnlyText
        : dayOnlyText.trim();
    await _datasource.saveSetting(_moonNightWarningTextKey, night);
    await _datasource.saveSetting(_moonDayOnlyTextKey, day);
  }

  WednesdayAffirmationModel? getWednesdayAffirmation() {
    final list = getWednesdayAffirmations();
    if (list.isEmpty) return null;
    return list.first;
  }

  List<WednesdayAffirmationModel> getWednesdayAffirmations() {
    final raw = _datasource.getSetting(_wednesdayAffirmationKey);
    final items = <WednesdayAffirmationModel>[];

    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final model = WednesdayAffirmationModel.fromMap(
          Map<String, dynamic>.from(entry),
        );
        if (model.meditationDateKey.trim().isEmpty) continue;
        items.add(model);
      }
    } else if (raw is Map) {
      final model = WednesdayAffirmationModel.fromMap(
        Map<String, dynamic>.from(raw),
      );
      if (model.meditationDateKey.trim().isNotEmpty) {
        items.add(model);
      }
    }

    items.sort((a, b) => b.meditationDateKey.compareTo(a.meditationDateKey));
    return items;
  }

  Future<void> saveWednesdayAffirmation(WednesdayAffirmationModel value) async {
    final all = getWednesdayAffirmations().toList(growable: true);
    all.insert(0, value);
    await saveWednesdayAffirmations(all);
  }

  Future<void> saveWednesdayAffirmations(
    List<WednesdayAffirmationModel> values,
  ) async {
    await _datasource.saveSetting(
      _wednesdayAffirmationKey,
      values.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<void> removeWednesdayAffirmation({required String updatedAt}) async {
    final normalized = updatedAt.trim();
    if (normalized.isEmpty) return;
    final next = getWednesdayAffirmations()
        .where((item) => item.updatedAt.trim() != normalized)
        .toList(growable: false);
    await saveWednesdayAffirmations(next);
  }

  String _phraseKeyForType(String type) {
    return type == 'emanation' ? _customEmanationsKey : _customAffirmationsKey;
  }

  String _dayLogId(String cycleId, DateTime date) {
    return '${cycleId}_${DateUtilsX.dateKey(date)}';
  }

  // ── Notas ─────────────────────────────────────────────────────────────────

  List<NoteModel> getNotes() {
    return _datasource.getNotesRaw().map(NoteModel.fromMap).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> saveNote(NoteModel note) async {
    final all = getNotes();
    final next = <NoteModel>[];
    var found = false;
    for (final n in all) {
      if (n.id == note.id) {
        next.add(note);
        found = true;
      } else {
        next.add(n);
      }
    }
    if (!found) next.add(note);
    await _datasource.saveNotesRaw(
      next.map((n) => n.toMap()).toList(growable: false),
    );
  }

  Future<void> deleteNote(String noteId) async {
    final next = getNotes().where((n) => n.id != noteId).toList();
    await _datasource.saveNotesRaw(
      next.map((n) => n.toMap()).toList(growable: false),
    );
  }

  // ── Recursos por mandala ────────────────────────────────────────────────

  List<MandalaResourceModel> getMandalaResources({String? cycleId}) {
    final all = _datasource
        .getMandalaResourcesRaw()
        .map(MandalaResourceModel.fromMap)
        .toList();
    final filtered = cycleId == null
        ? all
        : all.where((r) => r.cycleId == cycleId).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  List<MandalaResourceModel> getMandalaResourcesForFolderOrdered(
    String folderId,
  ) {
    final items = getMandalaResources()
        .where((item) => item.folderId == folderId)
        .toList(growable: false);
    final order =
        _getResourceItemsOrderByFolder()[folderId] ?? const <String>[];
    return _applyManualOrder(
      items: items,
      idOf: (item) => item.id,
      order: order,
      fallbackCompare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  Future<void> saveMandalaResource(MandalaResourceModel resource) async {
    final all = getMandalaResources();
    final next = <MandalaResourceModel>[];
    var found = false;
    String? previousFolderId;
    for (final item in all) {
      if (item.id == resource.id) {
        previousFolderId = item.folderId;
        next.add(resource);
        found = true;
      } else {
        next.add(item);
      }
    }
    if (!found) next.add(resource);
    await _datasource.saveMandalaResourcesRaw(
      next.map((r) => r.toMap()).toList(growable: false),
    );
    await _syncResourceItemOrderOnSave(
      saved: resource,
      previousFolderId: previousFolderId,
      isNew: !found,
    );
  }

  Future<void> deleteMandalaResource(String resourceId) async {
    final all = getMandalaResources();
    String? removedFolderId;
    final next = <MandalaResourceModel>[];
    for (final resource in all) {
      if (resource.id == resourceId) {
        removedFolderId = resource.folderId;
        continue;
      }
      next.add(resource);
    }
    await _datasource.saveMandalaResourcesRaw(
      next.map((r) => r.toMap()).toList(growable: false),
    );
    if (removedFolderId != null) {
      final map = _getResourceItemsOrderByFolder();
      final list = List<String>.from(map[removedFolderId] ?? const <String>[]);
      final changed = list.remove(resourceId);
      if (changed) {
        map[removedFolderId] = list;
        await _saveResourceItemsOrderByFolder(map);
      }
    }
  }

  List<ResourceFolderModel> getResourceFolders() {
    final raw = _datasource.getSetting(_resourceFoldersKey) as List?;
    if (raw == null) return <ResourceFolderModel>[];
    final folders = raw
        .whereType<Map>()
        .map(
          (item) =>
              ResourceFolderModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    folders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _applyManualOrder(
      items: folders,
      idOf: (folder) => folder.id,
      order: _getResourceFoldersOrderIds(),
      fallbackCompare: (a, b) => a.createdAt.compareTo(b.createdAt),
    );
  }

  Future<ResourceFolderModel> createResourceFolder({
    required String name,
    required int circle,
    String? parentId,
  }) async {
    final existingFolders = getResourceFolders();
    final normalizedParent = _resolveParentId(
      parentId: parentId,
      allFolders: existingFolders,
      currentFolderId: null,
    );
    final folder = ResourceFolderModel.create(
      name: name,
      circle: circle,
      parentId: normalizedParent,
    );
    final all = existingFolders..add(folder);
    await _saveResourceFolders(all);
    await _appendResourceFolderOrder(folder.id);
    return folder;
  }

  Future<void> saveResourceFolder(ResourceFolderModel folder) async {
    final all = getResourceFolders();
    final sanitized = folder.copyWith(
      parentId: _resolveParentId(
        parentId: folder.parentId,
        allFolders: all,
        currentFolderId: folder.id,
      ),
    );
    final next = <ResourceFolderModel>[];
    var found = false;
    for (final item in all) {
      if (item.id == folder.id) {
        next.add(sanitized);
        found = true;
      } else {
        next.add(item);
      }
    }
    if (!found) next.add(sanitized);
    await _saveResourceFolders(next);
  }

  Future<void> deleteResourceFolder(String folderId) async {
    final allFolders = getResourceFolders();
    final descendants = _collectDescendantFolderIds(
      allFolders,
      rootFolderId: folderId,
    );
    final idsToDelete = <String>{folderId, ...descendants};

    final folders = allFolders
        .where((f) => !idsToDelete.contains(f.id))
        .toList(growable: false);
    await _saveResourceFolders(folders);
    final resources = getMandalaResources()
        .where((r) => !idsToDelete.contains(r.folderId))
        .toList(growable: false);
    await _datasource.saveMandalaResourcesRaw(
      resources.map((r) => r.toMap()).toList(growable: false),
    );
    for (final id in idsToDelete) {
      await _removeResourceFolderOrder(id);
      await _removeResourceItemsOrderForFolder(id);
    }
  }

  List<ResourceFolderModel> getChildResourceFolders(String? parentId) {
    final normalizedParent = parentId?.trim();
    final allFolders = getResourceFolders();
    final folderIds = allFolders.map((folder) => folder.id).toSet();
    return getResourceFolders()
        .where((folder) {
          final folderParent = folder.parentId?.trim();
          if (folderParent != null && folderParent.isNotEmpty) {
            if (!folderIds.contains(folderParent)) return false;
          }
          if (normalizedParent == null || normalizedParent.isEmpty) {
            return folderParent == null || folderParent.isEmpty;
          }
          return folderParent == normalizedParent;
        })
        .toList(growable: false);
  }

  Future<void> normalizeResourcesFolders(String fallbackFolderId) async {
    final all = getMandalaResources();
    var changed = false;
    final next = <MandalaResourceModel>[];
    for (final item in all) {
      if (item.folderId.trim().isEmpty) {
        next.add(item.copyWith(folderId: fallbackFolderId));
        changed = true;
      } else {
        next.add(item);
      }
    }
    if (!changed) return;
    await _datasource.saveMandalaResourcesRaw(
      next.map((r) => r.toMap()).toList(growable: false),
    );
  }

  Future<void> _saveResourceFolders(List<ResourceFolderModel> folders) async {
    await _datasource.saveSetting(
      _resourceFoldersKey,
      folders.map((f) => f.toMap()).toList(growable: false),
    );
  }

  Future<void> saveResourceFoldersOrderIds(
    List<String> orderedFolderIds,
  ) async {
    await _datasource.saveSetting(
      _resourceFoldersOrderKey,
      orderedFolderIds.toList(growable: false),
    );
  }

  Future<void> saveResourceItemsOrderForFolder(
    String folderId,
    List<String> orderedItemIds,
  ) async {
    final map = _getResourceItemsOrderByFolder();
    map[folderId] = orderedItemIds.toList(growable: false);
    await _saveResourceItemsOrderByFolder(map);
  }

  List<String> _getResourceFoldersOrderIds() {
    final raw = _datasource.getSetting(_resourceFoldersOrderKey) as List?;
    if (raw == null) return <String>[];
    return raw.map((item) => item.toString()).toList(growable: false);
  }

  Map<String, List<String>> _getResourceItemsOrderByFolder() {
    final raw = _datasource.getSetting(_resourceItemsOrderByFolderKey);
    if (raw is! Map) return <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is List) {
        out[key] = value.map((item) => item.toString()).toList(growable: false);
      }
    }
    return out;
  }

  Future<void> _saveResourceItemsOrderByFolder(
    Map<String, List<String>> map,
  ) async {
    final serializable = <String, dynamic>{
      for (final entry in map.entries)
        entry.key: entry.value.toList(growable: false),
    };
    await _datasource.saveSetting(_resourceItemsOrderByFolderKey, serializable);
  }

  Future<void> _appendResourceFolderOrder(String folderId) async {
    final order = List<String>.from(_getResourceFoldersOrderIds());
    if (order.contains(folderId)) return;
    order.add(folderId);
    await saveResourceFoldersOrderIds(order);
  }

  Set<String> _collectDescendantFolderIds(
    List<ResourceFolderModel> folders, {
    required String rootFolderId,
  }) {
    final descendants = <String>{};
    final queue = <String>[rootFolderId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final folder in folders) {
        if (folder.parentId != current) continue;
        if (descendants.add(folder.id)) {
          queue.add(folder.id);
        }
      }
    }
    return descendants;
  }

  String? _resolveParentId({
    required String? parentId,
    required List<ResourceFolderModel> allFolders,
    required String? currentFolderId,
  }) {
    final normalized = parentId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == currentFolderId) return null;
    final folderById = <String, ResourceFolderModel>{
      for (final folder in allFolders) folder.id: folder,
    };
    if (!folderById.containsKey(normalized)) return null;

    if (currentFolderId == null) return normalized;
    var cursor = normalized;
    final visited = <String>{};
    while (true) {
      if (!visited.add(cursor)) return null;
      if (cursor == currentFolderId) return null;
      final parent = folderById[cursor]?.parentId?.trim();
      if (parent == null || parent.isEmpty) return normalized;
      cursor = parent;
    }
  }

  Future<void> _removeResourceFolderOrder(String folderId) async {
    final order = List<String>.from(_getResourceFoldersOrderIds());
    if (!order.remove(folderId)) return;
    await saveResourceFoldersOrderIds(order);
  }

  Future<void> _removeResourceItemsOrderForFolder(String folderId) async {
    final map = _getResourceItemsOrderByFolder();
    if (map.remove(folderId) == null) return;
    await _saveResourceItemsOrderByFolder(map);
  }

  Future<void> _syncResourceItemOrderOnSave({
    required MandalaResourceModel saved,
    required String? previousFolderId,
    required bool isNew,
  }) async {
    final map = _getResourceItemsOrderByFolder();
    if (previousFolderId != null && previousFolderId != saved.folderId) {
      final prev = List<String>.from(map[previousFolderId] ?? const <String>[]);
      if (prev.remove(saved.id)) {
        map[previousFolderId] = prev;
      }
    }

    final target = List<String>.from(map[saved.folderId] ?? const <String>[]);
    if (!target.contains(saved.id)) {
      if (isNew) {
        target.insert(0, saved.id);
      } else {
        target.add(saved.id);
      }
      map[saved.folderId] = target;
      await _saveResourceItemsOrderByFolder(map);
      return;
    }
    if (map.isNotEmpty) {
      await _saveResourceItemsOrderByFolder(map);
    }
  }

  List<T> _applyManualOrder<T>({
    required List<T> items,
    required String Function(T item) idOf,
    required List<String> order,
    required int Function(T a, T b) fallbackCompare,
  }) {
    if (items.length <= 1) return items;
    final rank = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
    };
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final ra = rank[idOf(a)];
      final rb = rank[idOf(b)];
      if (ra != null && rb != null) return ra.compareTo(rb);
      if (ra != null) return -1;
      if (rb != null) return 1;
      return fallbackCompare(a, b);
    });
    return sorted;
  }
}

void debugLog(String message) {
  debugPrint('[SadhanaRepository] $message');
}
