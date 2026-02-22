class MoonPhaseUtils {
  static double _phase(DateTime date) {
    final days = date.difference(DateTime(2001, 1, 1)).inDays;
    return ((days % 29.530588853) / 29.530588853);
  }

  static String phaseEmoji(DateTime date) {
    final phase = _phase(date);
    if (phase < 0.03 || phase > 0.97) return '🌑';
    if (phase < 0.22) return '🌒';
    if (phase < 0.28) return '🌓';
    if (phase < 0.53) return '🌕';
    if (phase < 0.72) return '🌖';
    if (phase < 0.78) return '🌗';
    return '🌘';
  }

  static String phaseName(DateTime date) {
    final phase = _phase(date);
    if (phase < 0.03 || phase > 0.97) return '🌑 Luna nueva';
    if (phase < 0.22) return '🌒 Cuarto creciente inicial';
    if (phase < 0.28) return '🌓 Cuarto creciente';
    if (phase < 0.53) return '🌕 Luna llena';
    if (phase < 0.72) return '🌖 Cuarto menguante inicial';
    if (phase < 0.78) return '🌗 Cuarto menguante';
    return '🌘 Ultimo cuarto';
  }
}
