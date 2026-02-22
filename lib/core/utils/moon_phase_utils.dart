import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/utils/date_utils.dart';

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
    return '🌘 Último cuarto';
  }

  /// Devuelve true si la fase lunar es favorable para practicar de noche.
  static bool isNightFavorable(DateTime date) {
    final phase = _phase(date);
    return phase > 0.03 && phase < 0.78;
  }

  /// Texto de recomendación horaria para el sadhana según la fase lunar.
  static String sadhanaRecommendation(DateTime date) {
    final phase = _phase(date);
    if (phase < 0.03 || phase > 0.97) {
      return 'Tiempo de recogimiento. Practica de día.';
    }
    if (phase < 0.28) return 'Energía en expansión. Favorable de noche.';
    if (phase < 0.53) return 'Energía máxima. Muy favorable de noche.';
    if (phase < 0.78) return 'Tiempo de soltar. Practica de día.';
    return 'Tiempo de depuración. Practica de día.';
  }

  /// Evento lunar especial del día (Purnima, Amavasya, Ekadashi) o null.
  /// Primero consulta [AppConstants.specialDays]; si no hay entrada,
  /// detecta automáticamente por fase.
  static String? lunarEvent(DateTime date) {
    final key = DateUtilsX.dateKey(date);
    final hardcoded = AppConstants.specialDays[key];
    if (hardcoded != null) return hardcoded;

    final phase = _phase(date);
    if (phase < 0.03 || phase > 0.97) return 'Amavasya';
    if (phase > 0.47 && phase < 0.53) return 'Purnima';
    // Ekadashi: día 11 de cada quincena lunar (~fase 0.35 y ~0.85)
    if ((phase > 0.33 && phase < 0.39) || (phase > 0.83 && phase < 0.89)) {
      return 'Ekadashi';
    }
    return null;
  }
}
