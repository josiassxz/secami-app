import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../data/local/database.dart';
import '../../features/library/data/library_repository.dart';
import '../entities/exercise.dart';
import '../entities/planned_set.dart';

enum ProgressionDecision { aumentar, manter, reduzir }

class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.decision,
    required this.cargaSugerida,
    required this.delta,
    required this.baseadoEmSessoes,
  });

  final ProgressionDecision decision;
  final double cargaSugerida;
  final double delta; // positivo ou negativo em kg
  final int baseadoEmSessoes;
}

/// Sugestao de progressao para exercicios medidos por tempo (E6). Em vez de
/// carga, progride o **alvo de duracao** (segundos).
class TimedProgressionSuggestion {
  const TimedProgressionSuggestion({
    required this.decision,
    required this.duracaoSugeridaSegundos,
    required this.deltaSegundos,
    required this.baseadoEmSessoes,
  });

  final ProgressionDecision decision;
  final int duracaoSugeridaSegundos;
  final int deltaSegundos; // positivo ou negativo em segundos
  final int baseadoEmSessoes;
}

/// Motor de progressao de carga.
///
/// Regras:
/// - Todas as series no topo da faixa => +2.5kg compostos / +1kg isoladores
/// - >= 50% das series na faixa       => manter
/// - Maioria abaixo do minimo         => -5%
class ProgressionEngine {
  ProgressionEngine(this._db, this._library);

  // ignore: unused_field
  final AppDatabase _db;
  // ignore: unused_field
  final LibraryRepository _library;

  static const double _incrementoComposto = 2.5;
  static const double _incrementoIsolador = 1.0;
  static const int _incrementoTempoSegundos = 5;

  /// Calcula a sugestao para a faixa indicada usando as series da sessao
  /// imediatamente anterior do mesmo exercicio.
  ///
  /// RPE medio das series executadas modifica a decisao:
  ///   <= 6 (facil)  → progressao mais agressiva
  ///   >= 9 (limite) → freia ou reverte aumento
  ProgressionSuggestion suggest({
    required Exercise exercise,
    required PlannedSet planned,
    required List<SetLogRow> lastSessionLogs,
  }) {
    final executadas = lastSessionLogs.where((l) => l.executada).toList();
    if (executadas.isEmpty) {
      final base = planned.cargaAlvo ?? 0;
      return ProgressionSuggestion(
        decision: ProgressionDecision.manter,
        cargaSugerida: base,
        delta: 0,
        baseadoEmSessoes: 0,
      );
    }

    final topo = planned.repsAlvoMax;
    final base = planned.repsAlvoMin;
    final allAtTop = executadas.every((l) => (l.repsRealizadas ?? 0) >= topo);
    final inRangeCount = executadas
        .where(
          (l) =>
              (l.repsRealizadas ?? 0) >= base &&
              (l.repsRealizadas ?? 0) <= topo,
        )
        .length;
    final belowMinCount = executadas
        .where((l) => (l.repsRealizadas ?? 0) < base)
        .length;

    final maxCarga = executadas
        .map((l) => l.cargaKg ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final increment = _isComposto(exercise)
        ? _incrementoComposto
        : _incrementoIsolador;

    final avgRpe = _avgRpe(executadas);
    final esforcoAlto = avgRpe != null && avgRpe >= 9;
    final esforcoFacil = avgRpe != null && avgRpe <= 6;

    if (allAtTop) {
      if (esforcoAlto) {
        // Bateu o topo mas com esforco maximo: manter para consolidar
        return ProgressionSuggestion(
          decision: ProgressionDecision.manter,
          cargaSugerida: maxCarga,
          delta: 0,
          baseadoEmSessoes: 1,
        );
      }
      // Esforco facil: dobra o incremento
      final inc = esforcoFacil ? increment * 2 : increment;
      return ProgressionSuggestion(
        decision: ProgressionDecision.aumentar,
        cargaSugerida: _round(maxCarga + inc),
        delta: inc,
        baseadoEmSessoes: 1,
      );
    }

    if (inRangeCount >= executadas.length / 2) {
      if (esforcoFacil) {
        // Na faixa mas sentiu facil: pequeno aumento
        return ProgressionSuggestion(
          decision: ProgressionDecision.aumentar,
          cargaSugerida: _round(maxCarga + increment),
          delta: increment,
          baseadoEmSessoes: 1,
        );
      }
      if (esforcoAlto) {
        // Na faixa mas no limite: recua levemente para consolidar
        final reduzida = _round(maxCarga * 0.975);
        return ProgressionSuggestion(
          decision: ProgressionDecision.reduzir,
          cargaSugerida: reduzida,
          delta: reduzida - maxCarga,
          baseadoEmSessoes: 1,
        );
      }
      return ProgressionSuggestion(
        decision: ProgressionDecision.manter,
        cargaSugerida: maxCarga,
        delta: 0,
        baseadoEmSessoes: 1,
      );
    }

    if (belowMinCount > executadas.length / 2) {
      // Esforco alto + abaixo do minimo: recua mais (-10% vs -5%)
      final pct = esforcoAlto ? 0.90 : 0.95;
      final reduzida = _round(maxCarga * pct);
      return ProgressionSuggestion(
        decision: ProgressionDecision.reduzir,
        cargaSugerida: reduzida,
        delta: reduzida - maxCarga,
        baseadoEmSessoes: 1,
      );
    }

    return ProgressionSuggestion(
      decision: ProgressionDecision.manter,
      cargaSugerida: maxCarga,
      delta: 0,
      baseadoEmSessoes: 1,
    );
  }

  /// Progressao por tempo (E6). Usa as series por tempo da sessao anterior.
  /// Regra (espelha a de carga): todas atingiram o alvo => aumenta o alvo
  /// (+5s, ou +10s se RPE facil; mantem se RPE no limite). Maioria abaixo do
  /// alvo => recua para a maior duracao efetivamente alcancada. Senao, mantem.
  TimedProgressionSuggestion suggestTimed({
    required PlannedSet planned,
    required List<SetLogRow> lastSessionLogs,
  }) {
    final executadas = lastSessionLogs
        .where((l) => l.executada && l.duracaoSegundos != null)
        .toList();
    final alvo = planned.duracaoAlvoSegundos ?? 0;
    if (executadas.isEmpty) {
      return TimedProgressionSuggestion(
        decision: ProgressionDecision.manter,
        duracaoSugeridaSegundos: alvo,
        deltaSegundos: 0,
        baseadoEmSessoes: 0,
      );
    }

    final maxDur = executadas
        .map((l) => l.duracaoSegundos!)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final base = alvo > 0 ? alvo : maxDur;

    final avgRpe = _avgRpe(executadas);
    final esforcoAlto = avgRpe != null && avgRpe >= 9;
    final esforcoFacil = avgRpe != null && avgRpe <= 6;

    final atingiuAlvo =
        base > 0 && executadas.every((l) => l.duracaoSegundos! >= base);
    final abaixoCount = executadas
        .where((l) => l.duracaoSegundos! < base)
        .length;

    if (atingiuAlvo) {
      if (esforcoAlto) {
        return TimedProgressionSuggestion(
          decision: ProgressionDecision.manter,
          duracaoSugeridaSegundos: base,
          deltaSegundos: 0,
          baseadoEmSessoes: 1,
        );
      }
      final inc = esforcoFacil
          ? _incrementoTempoSegundos * 2
          : _incrementoTempoSegundos;
      return TimedProgressionSuggestion(
        decision: ProgressionDecision.aumentar,
        duracaoSugeridaSegundos: base + inc,
        deltaSegundos: inc,
        baseadoEmSessoes: 1,
      );
    }

    if (abaixoCount > executadas.length / 2) {
      return TimedProgressionSuggestion(
        decision: ProgressionDecision.reduzir,
        duracaoSugeridaSegundos: maxDur,
        deltaSegundos: maxDur - base,
        baseadoEmSessoes: 1,
      );
    }

    return TimedProgressionSuggestion(
      decision: ProgressionDecision.manter,
      duracaoSugeridaSegundos: base,
      deltaSegundos: 0,
      baseadoEmSessoes: 1,
    );
  }

  double? _avgRpe(List<SetLogRow> sets) {
    final rpes = sets.map((s) => s.rpe).whereType<int>().toList();
    if (rpes.isEmpty) return null;
    return rpes.reduce((a, b) => a + b) / rpes.length;
  }

  bool _isComposto(Exercise e) {
    switch (e.padraoMovimento) {
      case PadraoMovimento.isolador:
        return false;
      case PadraoMovimento.puxada_vertical:
      case PadraoMovimento.puxada_horizontal:
      case PadraoMovimento.empurrada_vertical:
      case PadraoMovimento.empurrada_horizontal:
      case PadraoMovimento.agachamento:
      case PadraoMovimento.dobradica_quadril:
        return true;
    }
  }

  double _round(double v) {
    // arredonda para multiplos de 0.5kg
    return (v * 2).round() / 2.0;
  }
}

final progressionEngineProvider = Provider<ProgressionEngine>((ref) {
  return ProgressionEngine(
    ref.watch(appDatabaseProvider),
    ref.watch(libraryRepositoryProvider),
  );
});
