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

  String _phraseKeyForType(String type) {
    return type == 'emanation' ? _customEmanationsKey : _customAffirmationsKey;
  }

  String _dayLogId(String cycleId, DateTime date) {
    return '${cycleId}_${DateUtilsX.dateKey(date)}';
  }

  // ── Notas ─────────────────────────────────────────────────────────────────

  List<NoteModel> getNotes() {
    return _datasource.getNotesRaw().map(NoteModel.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // ── Recursos por mándala ────────────────────────────────────────────────

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

  Future<void> saveMandalaResource(MandalaResourceModel resource) async {
    final all = getMandalaResources();
    final next = <MandalaResourceModel>[];
    var found = false;
    for (final item in all) {
      if (item.id == resource.id) {
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
  }

  Future<void> deleteMandalaResource(String resourceId) async {
    final next = getMandalaResources()
        .where((r) => r.id != resourceId)
        .toList();
    await _datasource.saveMandalaResourcesRaw(
      next.map((r) => r.toMap()).toList(growable: false),
    );
  }
}

void debugLog(String message) {
  debugPrint('[SadhanaRepository] $message');
}
