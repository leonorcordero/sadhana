import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/models/wednesday_affirmation_model.dart';

void main() {
  // ── DateUtilsX ─────────────────────────────────────────────────────────────

  group('DateUtilsX', () {
    test('dateKey formatea con padding correcto', () {
      expect(DateUtilsX.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(DateUtilsX.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('fromDateKey parsea correctamente', () {
      final date = DateUtilsX.fromDateKey('2026-03-15');
      expect(date.year, 2026);
      expect(date.month, 3);
      expect(date.day, 15);
    });

    test('dateKey y fromDateKey son inversos', () {
      final original = DateTime(2025, 7, 4);
      expect(DateUtilsX.fromDateKey(DateUtilsX.dateKey(original)), original);
    });
  });

  // ── TaskModel ───────────────────────────────────────────────────────────────

  group('TaskModel', () {
    test('create genera id unico y comienza activa', () {
      final t = TaskModel.create(cycleId: 'c1', title: 'Meditar');
      expect(t.id, isNotEmpty);
      expect(t.isActive, isTrue);
      expect(t.description, isNull);
      expect(t.linkedResourceIds, isEmpty);
    });

    test('toMap y fromMap son inversos', () {
      final t = TaskModel(
        id: 'tid',
        cycleId: 'cid',
        title: 'Yoga',
        description: 'Hatha yoga',
        isActive: true,
        linkedResourceIds: const ['r1', 'r2'],
      );
      final map = t.toMap();
      final restored = TaskModel.fromMap(map);

      expect(restored.id, t.id);
      expect(restored.cycleId, t.cycleId);
      expect(restored.title, t.title);
      expect(restored.description, t.description);
      expect(restored.isActive, t.isActive);
      expect(restored.linkedResourceIds, t.linkedResourceIds);
    });

    test('fromMap con description null', () {
      final map = {
        'id': 'x',
        'cycleId': 'c',
        'title': 'T',
        'description': null,
        'isActive': false,
      };
      final t = TaskModel.fromMap(map);
      expect(t.description, isNull);
      expect(t.isActive, isFalse);
      expect(t.linkedResourceIds, isEmpty);
    });

    test('copyWith reemplaza campos individuales', () {
      final t = TaskModel.create(cycleId: 'c', title: 'Original');
      final updated = t.copyWith(
        title: 'Nuevo',
        isActive: false,
        linkedResourceIds: const ['res-1'],
      );
      expect(updated.title, 'Nuevo');
      expect(updated.isActive, isFalse);
      expect(updated.cycleId, t.cycleId);
      expect(updated.linkedResourceIds, const ['res-1']);
    });
  });

  // ── DayLogModel ─────────────────────────────────────────────────────────────

  group('DayLogModel', () {
    DayLogModel buildLog({
      bool closed = false,
      bool wasComplete = false,
      List<String> ids = const [],
    }) {
      return DayLogModel(
        id: 'lid',
        cycleId: 'cid',
        date: '2026-01-01',
        completedTaskIds: ids,
        closed: closed,
        wasComplete: wasComplete,
      );
    }

    test('toMap y fromMap son inversos', () {
      final log = buildLog(closed: true, wasComplete: true, ids: ['t1', 't2']);
      final restored = DayLogModel.fromMap(log.toMap());
      expect(restored.id, log.id);
      expect(restored.completedTaskIds, ['t1', 't2']);
      expect(restored.closed, isTrue);
      expect(restored.wasComplete, isTrue);
    });

    test('copyWith closed y wasComplete', () {
      final log = buildLog();
      final closed = log.copyWith(closed: true, wasComplete: true);
      expect(closed.closed, isTrue);
      expect(closed.wasComplete, isTrue);
      expect(closed.date, log.date);
    });

    test('completedTaskIds se actualiza en copyWith', () {
      final log = buildLog(ids: ['t1']);
      final updated = log.copyWith(completedTaskIds: ['t1', 't2']);
      expect(updated.completedTaskIds.length, 2);
    });
  });

  // ── CycleModel ──────────────────────────────────────────────────────────────

  group('CycleModel', () {
    test('create inicializa valores correctos', () {
      final c = CycleModel.create(
        name: 'Silencio',
        duration: 40,
        customDuration: false,
        sankalpa: 'Paz',
      );
      expect(c.id, isNotEmpty);
      expect(c.isActive, isFalse);
      expect(c.currentDay, 1);
      expect(c.startDay, 1);
      expect(c.streakCurrent, 0);
      expect(c.streakMax, 0);
      expect(c.linkedResourceFolderIds, isEmpty);
    });

    test('create falla con duracion invalida', () {
      expect(
        () => CycleModel.create(
          name: 'Invalido',
          duration: 0,
          customDuration: true,
          sankalpa: 'S',
        ),
        throwsArgumentError,
      );
    });

    test('progress calcula ratio correcto', () {
      final c = CycleModel(
        id: 'id',
        name: 'N',
        duration: 40,
        customDuration: false,
        startDay: 1,
        currentDay: 20,
        sankalpa: 'S',
        streakCurrent: 0,
        streakMax: 0,
        isActive: true,
      );
      expect(c.progress, closeTo(0.5, 0.01));
    });

    test('progress con duration 0 retorna 0', () {
      final c = CycleModel(
        id: 'id',
        name: 'N',
        duration: 0,
        customDuration: true,
        startDay: 1,
        currentDay: 1,
        sankalpa: 'S',
        streakCurrent: 0,
        streakMax: 0,
        isActive: false,
      );
      expect(c.progress, 0);
    });

    test('toMap y fromMap son inversos', () {
      final c = CycleModel(
        id: 'cid',
        name: 'Test',
        duration: 21,
        customDuration: true,
        startDay: 1,
        currentDay: 10,
        sankalpa: 'Perseverancia',
        streakCurrent: 5,
        streakMax: 8,
        isActive: true,
        linkedResourceFolderIds: const ['folder-a', 'folder-b'],
        plannedStartDateKey: '2026-03-15',
      );
      final restored = CycleModel.fromMap(c.toMap());
      expect(restored.id, c.id);
      expect(restored.name, c.name);
      expect(restored.duration, c.duration);
      expect(restored.currentDay, c.currentDay);
      expect(restored.streakCurrent, c.streakCurrent);
      expect(restored.streakMax, c.streakMax);
      expect(restored.isActive, c.isActive);
      expect(restored.linkedResourceFolderIds, c.linkedResourceFolderIds);
      expect(restored.plannedStartDateKey, c.plannedStartDateKey);
    });

    test('copyWith preserva campos no modificados', () {
      final c = CycleModel.create(
        name: 'X',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
      );
      final updated = c.copyWith(isActive: true, currentDay: 3);
      expect(updated.name, c.name);
      expect(updated.sankalpa, c.sankalpa);
      expect(updated.isActive, isTrue);
      expect(updated.currentDay, 3);
    });

    test('fromMap sin linkedResourceFolderIds usa default seguro', () {
      final restored = CycleModel.fromMap({
        'id': 'legacy',
        'name': 'Legacy',
        'duration': 21,
        'customDuration': false,
        'startDay': 1,
        'currentDay': 1,
        'sankalpa': 'S',
        'streakCurrent': 0,
        'streakMax': 0,
        'isActive': false,
      });
      expect(restored.linkedResourceFolderIds, isEmpty);
      expect(restored.plannedStartDateKey, isNull);
    });
  });

  group('WednesdayAffirmationModel', () {
    test('fromMap soporta datos antiguos con defaults seguros', () {
      final model = WednesdayAffirmationModel.fromMap({
        'meditationDateKey': '2026-02-24',
      });

      expect(model.meditationDateKey, '2026-02-24');
      expect(model.name, isNull);
      expect(model.contentType, 'text');
      expect(model.text, isNull);
      expect(model.imagePath, isNull);
      expect(model.updatedAt, isNotEmpty);
    });

    test('toMap y fromMap conservan campos', () {
      final original = WednesdayAffirmationModel(
        meditationDateKey: '2026-02-25',
        name: 'Leo',
        contentType: 'image',
        text: null,
        imagePath: '/tmp/a.png',
        updatedAt: '2026-02-24T10:00:00.000Z',
      );

      final restored = WednesdayAffirmationModel.fromMap(original.toMap());
      expect(restored.meditationDateKey, original.meditationDateKey);
      expect(restored.name, original.name);
      expect(restored.contentType, original.contentType);
      expect(restored.imagePath, original.imagePath);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}
