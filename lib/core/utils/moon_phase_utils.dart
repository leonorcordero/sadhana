class MoonPhaseUtils {
  static String phaseEmoji(DateTime date) {
    final days = date.difference(DateTime(2001, 1, 1)).inDays;
    final phase = ((days % 29.530588853) / 29.530588853);

    if (phase < 0.03 || phase > 0.97) return '🌑';
    if (phase < 0.22) return '🌓';
    if (phase < 0.28) return '🌔';
    if (phase < 0.53) return '🌕';
    if (phase < 0.72) return '🌗';
    return '🌘';
  }
}
