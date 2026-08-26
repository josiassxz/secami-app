import '../../../domain/entities/planned_set.dart';
import '../../../domain/entities/exercise.dart';
import 'triagem.dart';

/// Tipo de divisao semanal (secao 8 / RN-018..022).
enum TipoDivisao {
  fullBodyAB,
  fullBodyABC,
  upperLowerFull,
  upperLower2x,
  upperLowerPonto,
  pplAdaptado,
  ppl2x;

  String get label {
    switch (this) {
      case TipoDivisao.fullBodyAB:
        return 'Corpo inteiro A/B';
      case TipoDivisao.fullBodyABC:
        return 'Corpo inteiro A/B/C';
      case TipoDivisao.upperLowerFull:
        return 'Superior / Inferior / Full';
      case TipoDivisao.upperLower2x:
        return 'Superior / Inferior (2x)';
      case TipoDivisao.upperLowerPonto:
        return 'Superior / Inferior + ponto fraco';
      case TipoDivisao.pplAdaptado:
        return 'Push / Pull / Legs adaptado';
      case TipoDivisao.ppl2x:
        return 'Push / Pull / Legs (2x)';
    }
  }
}

/// Plano de um dia antes da selecao de exercicios: nome + grupos-alvo.
class DiaPlano {
  const DiaPlano({
    required this.nome,
    required this.foco,
    this.diasDaSemana = const [],
  });

  final String nome;
  final List<GrupoMuscular> foco;
  final List<int> diasDaSemana;
}

/// Divisao escolhida pelo [SplitSelector].
class DivisaoTreino {
  const DivisaoTreino({required this.tipo, required this.dias});

  final TipoDivisao tipo;
  final List<DiaPlano> dias;
}

/// Exercicio ja prescrito (series/reps/descanso + observacoes e alertas).
class ExercicioPrescrito {
  const ExercicioPrescrito({
    required this.exercicio,
    required this.series,
    this.observacao,
    this.alertas = const [],
  });

  final Exercise exercicio;
  final List<PlannedSet> series;
  final String? observacao;

  /// Alertas especificos do exercicio (RN-046), ex.: restricao do usuario.
  final List<String> alertas;

  ExercicioPrescrito copyWith({List<PlannedSet>? series}) {
    return ExercicioPrescrito(
      exercicio: exercicio,
      series: series ?? this.series,
      observacao: observacao,
      alertas: alertas,
    );
  }

  Map<String, dynamic> toJson() => {
    'slug': exercicio.slug,
    'nome': exercicio.nome,
    'grupo': exercicio.grupoPrimario.name,
    'series': series.length,
    'reps_min': series.isEmpty ? null : series.first.repsAlvoMin,
    'reps_max': series.isEmpty ? null : series.first.repsAlvoMax,
    'descanso_segundos': series.isEmpty ? null : series.first.descansoSegundos,
    if (observacao != null) 'observacao': observacao,
  };
}

class DiaTreino {
  const DiaTreino({
    required this.nome,
    required this.exercicios,
    this.diasDaSemana = const [],
  });

  final String nome;
  final List<ExercicioPrescrito> exercicios;
  final List<int> diasDaSemana;

  DiaTreino copyWith({List<ExercicioPrescrito>? exercicios}) {
    return DiaTreino(
      nome: nome,
      exercicios: exercicios ?? this.exercicios,
      diasDaSemana: diasDaSemana,
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'dias_da_semana': diasDaSemana,
    'exercicios': exercicios.map((e) => e.toJson()).toList(),
  };
}

/// Resultado final da recomendacao (RN-043/044/046/050).
class TreinoRecomendado {
  const TreinoRecomendado({
    required this.bloqueado,
    required this.triagem,
    required this.dias,
    required this.justificativa,
    required this.alertas,
    required this.versaoRegras,
    required this.entradas,
    this.divisao,
  });

  /// Construtor para o caso de triagem que encaminha (RN-002/CA-002): nenhum
  /// treino e gerado, apenas a orientacao.
  factory TreinoRecomendado.bloqueado({
    required TriagemResultado triagem,
    required String versaoRegras,
    required Map<String, dynamic> entradas,
  }) {
    return TreinoRecomendado(
      bloqueado: true,
      triagem: triagem,
      dias: const [],
      justificativa: triagem.orientacao,
      alertas: triagem.motivos,
      versaoRegras: versaoRegras,
      entradas: entradas,
    );
  }

  final bool bloqueado;
  final TriagemResultado triagem;
  final TipoDivisao? divisao;
  final List<DiaTreino> dias;

  /// Explicacao da escolha (RN-044).
  final String justificativa;

  /// Alertas globais exibidos antes do treino (RN-046).
  final List<String> alertas;

  /// Versao do motor de regras (RN-052).
  final String versaoRegras;

  /// Entradas + criterios usados, para auditoria (RN-050).
  final Map<String, dynamic> entradas;

  int get totalExercicios =>
      dias.fold(0, (acc, d) => acc + d.exercicios.length);

  TreinoRecomendado copyWith({List<DiaTreino>? dias}) {
    return TreinoRecomendado(
      bloqueado: bloqueado,
      triagem: triagem,
      dias: dias ?? this.dias,
      justificativa: justificativa,
      alertas: alertas,
      versaoRegras: versaoRegras,
      entradas: entradas,
      divisao: divisao,
    );
  }

  /// Serializacao para auditoria (RN-050 / CA-008).
  Map<String, dynamic> toJson() => {
    'versao_regras': versaoRegras,
    'bloqueado': bloqueado,
    'divisao': divisao?.name,
    'justificativa': justificativa,
    'alertas': alertas,
    'dias': dias.map((d) => d.toJson()).toList(),
    'entradas': entradas,
  };
}
