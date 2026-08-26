import '../../../../domain/entities/planned_set.dart';
import '../../../../domain/entities/exercise.dart';
import '../questionario.dart';
import '../treino_recomendado.dart';

/// Define series, repeticoes e descanso por objetivo e tipo de exercicio
/// (RN-024..031). Aplica regra conservadora para iniciantes/alertas (RN-014/030).
class Prescriber {
  const Prescriber._();

  static ExercicioPrescrito prescrever({
    required Exercise exercicio,
    required Objetivo objetivo,
    required bool conservador,
    List<String> alertas = const [],
  }) {
    final composto = exercicio.tipo != TipoExercicio.isolador;
    final p = _params(objetivo, composto: composto);

    var series = composto ? p.seriesComposto : p.seriesIsolador;
    if (conservador) series = (series - 1).clamp(1, 5);

    final descanso = composto ? p.descansoComposto : p.descansoIsolador;

    final sets = List.generate(
      series,
      (i) => PlannedSet(
        numero: i + 1,
        repsAlvoMin: p.repsMin,
        repsAlvoMax: p.repsMax,
        descansoSegundos: descanso,
      ),
      growable: false,
    );

    return ExercicioPrescrito(
      exercicio: exercicio,
      series: sets,
      observacao: _observacao(
        objetivo,
        composto: composto,
        conservador: conservador,
      ),
      alertas: alertas,
    );
  }

  static String? _observacao(
    Objetivo objetivo, {
    required bool composto,
    required bool conservador,
  }) {
    if (conservador) {
      return 'Pare 1 a 2 repeticoes antes da falha (repeticoes em reserva).';
    }
    if (objetivo == Objetivo.forca && composto) {
      return 'Priorize tecnica e progressao controlada de carga.';
    }
    if (objetivo == Objetivo.condicionamento ||
        objetivo == Objetivo.emagrecimento) {
      return 'Mantenha o descanso curto para elevar a frequencia cardiaca.';
    }
    return null;
  }

  static _Params _params(Objetivo objetivo, {required bool composto}) {
    switch (objetivo) {
      case Objetivo.hipertrofia:
        return composto
            ? const _Params(4, 3, 8, 12, 90, 60)
            : const _Params(4, 3, 10, 15, 90, 60);
      case Objetivo.forca:
      case Objetivo.performance:
        return const _Params(5, 3, 4, 6, 180, 120);
      case Objetivo.emagrecimento:
      case Objetivo.condicionamento:
        return const _Params(3, 3, 12, 20, 45, 30);
      case Objetivo.saude:
        return const _Params(3, 2, 10, 15, 75, 60);
      case Objetivo.mobilidade:
        return const _Params(2, 2, 10, 12, 45, 45);
    }
  }
}

class _Params {
  const _Params(
    this.seriesComposto,
    this.seriesIsolador,
    this.repsMin,
    this.repsMax,
    this.descansoComposto,
    this.descansoIsolador,
  );

  final int seriesComposto;
  final int seriesIsolador;
  final int repsMin;
  final int repsMax;
  final int descansoComposto;
  final int descansoIsolador;
}
