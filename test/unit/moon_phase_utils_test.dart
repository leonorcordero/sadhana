import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';

void main() {
  test('luna nueva retorna emoji correcto', () {
    // 2001-01-01 es luna nueva (dia 0 del ciclo)
    final date = DateTime(2001, 1, 1);
    expect(MoonPhaseUtils.phaseEmoji(date), '🌑');
    expect(MoonPhaseUtils.phaseName(date), contains('Luna nueva'));
  });

  test('luna llena retorna emoji correcto', () {
    // ~15 dias despues de luna nueva = luna llena
    final date = DateTime(2001, 1, 16);
    expect(MoonPhaseUtils.phaseEmoji(date), '🌕');
    expect(MoonPhaseUtils.phaseName(date), contains('Luna llena'));
  });

  test('phaseName nunca retorna cadena vacia', () {
    for (var i = 0; i < 30; i++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: i));
      expect(MoonPhaseUtils.phaseName(date), isNotEmpty);
    }
  });
}
