import '../../../../domain/entities/exercise.dart';
import '../questionario.dart';
import '../treino_recomendado.dart';

/// Seleciona a divisao semanal conforme dias disponiveis, objetivo e nivel
/// (secao 8 / RN-018..022). Distribui os dias da semana de forma espacada.
class SplitSelector {
  const SplitSelector._();

  static const _superiores = <GrupoMuscular>[
    GrupoMuscular.peito,
    GrupoMuscular.costas,
    GrupoMuscular.ombros,
    GrupoMuscular.biceps,
    GrupoMuscular.triceps,
  ];
  static const _inferiores = <GrupoMuscular>[
    GrupoMuscular.quadriceps,
    GrupoMuscular.posterior,
    GrupoMuscular.gluteos,
    GrupoMuscular.panturrilha,
  ];
  static const _push = <GrupoMuscular>[
    GrupoMuscular.peito,
    GrupoMuscular.ombros,
    GrupoMuscular.triceps,
  ];
  static const _pull = <GrupoMuscular>[
    GrupoMuscular.costas,
    GrupoMuscular.biceps,
  ];
  static const _legs = <GrupoMuscular>[
    GrupoMuscular.quadriceps,
    GrupoMuscular.posterior,
    GrupoMuscular.gluteos,
    GrupoMuscular.panturrilha,
  ];

  static List<GrupoMuscular> get _corpoTodo => [
    ..._superiores,
    ..._inferiores,
    GrupoMuscular.core,
  ];

  static List<GrupoMuscular> get _upper => [..._superiores, GrupoMuscular.core];
  static List<GrupoMuscular> get _lower => [..._inferiores, GrupoMuscular.core];

  static DivisaoTreino selecionar({
    required int dias,
    required Objetivo objetivo,
    required NivelExperiencia experiencia,
    required PrioridadeMuscular prioridade,
  }) {
    final iniciante =
        experiencia == NivelExperiencia.nuncaTreinou ||
        experiencia == NivelExperiencia.iniciante;

    switch (dias) {
      case 2:
        return _comDias(TipoDivisao.fullBodyAB, [
          DiaPlano(nome: 'Treino A - Corpo inteiro', foco: _corpoTodo),
          DiaPlano(nome: 'Treino B - Corpo inteiro', foco: _corpoTodo),
        ], dias);
      case 3:
        if (iniciante) {
          return _comDias(TipoDivisao.fullBodyABC, [
            DiaPlano(nome: 'Treino A - Corpo inteiro', foco: _corpoTodo),
            DiaPlano(nome: 'Treino B - Corpo inteiro', foco: _corpoTodo),
            DiaPlano(nome: 'Treino C - Corpo inteiro', foco: _corpoTodo),
          ], dias);
        }
        return _comDias(TipoDivisao.upperLowerFull, [
          DiaPlano(nome: 'Superior', foco: _upper),
          DiaPlano(nome: 'Inferior', foco: _lower),
          DiaPlano(nome: 'Corpo inteiro', foco: _corpoTodo),
        ], dias);
      case 4:
        return _comDias(TipoDivisao.upperLower2x, [
          DiaPlano(nome: 'Superior A', foco: _upper),
          DiaPlano(nome: 'Inferior A', foco: _lower),
          DiaPlano(nome: 'Superior B', foco: _upper),
          DiaPlano(nome: 'Inferior B', foco: _lower),
        ], dias);
      case 5:
        return _comDias(TipoDivisao.upperLowerPonto, [
          DiaPlano(nome: 'Superior A', foco: _upper),
          DiaPlano(nome: 'Inferior A', foco: _lower),
          DiaPlano(nome: 'Superior B', foco: _upper),
          DiaPlano(nome: 'Inferior B', foco: _lower),
          DiaPlano(
            nome: 'Ponto fraco - ${prioridade.label}',
            foco: prioridade.grupos.toList(),
          ),
        ], dias);
      case 6:
      default:
        return _comDias(TipoDivisao.ppl2x, const [
          DiaPlano(nome: 'Push A', foco: _push),
          DiaPlano(nome: 'Pull A', foco: _pull),
          DiaPlano(nome: 'Legs A', foco: [..._legs, GrupoMuscular.core]),
          DiaPlano(nome: 'Push B', foco: _push),
          DiaPlano(nome: 'Pull B', foco: _pull),
          DiaPlano(nome: 'Legs B', foco: [..._legs, GrupoMuscular.core]),
        ], dias);
    }
  }

  /// Distribui N dias de treino espacados ao longo da semana (0=Dom..6=Sab)
  /// e anexa os dias sugeridos a cada [DiaPlano].
  static DivisaoTreino _comDias(
    TipoDivisao tipo,
    List<DiaPlano> planos,
    int dias,
  ) {
    final semana = _diasEspacados(dias);
    final comDia = <DiaPlano>[];
    for (var i = 0; i < planos.length; i++) {
      comDia.add(
        DiaPlano(
          nome: planos[i].nome,
          foco: planos[i].foco,
          diasDaSemana: [semana[i]],
        ),
      );
    }
    return DivisaoTreino(tipo: tipo, dias: comDia);
  }

  /// Escolhe [n] dias da semana espacados (seg/qua/sex etc).
  static List<int> _diasEspacados(int n) {
    const mapa = {
      2: [1, 4], // Seg, Qui
      3: [1, 3, 5], // Seg, Qua, Sex
      4: [1, 2, 4, 5], // Seg, Ter, Qui, Sex
      5: [1, 2, 3, 5, 6], // Seg..Qua, Sex, Sab
      6: [1, 2, 3, 4, 5, 6], // Seg..Sab
    };
    return mapa[n] ?? List.generate(n, (i) => i + 1);
  }
}
