import '../../../../domain/entities/exercise.dart';
import '../questionario.dart';
import '../treino_recomendado.dart';
import '../triagem.dart';
import 'exercise_selector.dart';
import 'prescriber.dart';
import 'profile_classifier.dart';
import 'safety_gate.dart';
import 'split_selector.dart';

/// Motor de recomendacao de treinos. Orquestra triagem -> perfil -> divisao ->
/// selecao -> prescricao (secao 13 do PDF). Dart puro e deterministico.
class WorkoutRecommender {
  const WorkoutRecommender();

  /// Versao das regras (RN-052). Bump ao alterar logica de prescricao.
  static const versaoRegras = 'rec-v1';

  TreinoRecomendado gerar({
    required PerfilQuestionario perfil,
    required RespostasTriagem triagem,
    required List<Exercise> biblioteca,
    int variacao = 0,
  }) {
    final tri = SafetyGate.avaliar(triagem);
    final entradasBase = <String, dynamic>{
      'versao_regras': versaoRegras,
      'perfil': perfil.toJson(),
      'triagem': tri.toJson(),
    };

    // RN-002 / CA-002: alerta critico nao gera treino intenso automaticamente.
    if (tri.nivel == TriagemNivel.encaminhar) {
      return TreinoRecomendado.bloqueado(
        triagem: tri,
        versaoRegras: versaoRegras,
        entradas: entradasBase,
      );
    }

    final perfilTreino = ProfileClassifier.classificar(
      perfil,
      bloqueiaIntenso: tri.bloqueiaIntenso,
    );

    final divisao = SplitSelector.selecionar(
      dias: perfil.diasPorSemana,
      objetivo: perfil.objetivo,
      experiencia: perfilTreino.experienciaEfetiva,
      prioridade: perfil.prioridade,
    );

    final dias = <DiaTreino>[];
    for (final plano in divisao.dias) {
      final exercicios = ExerciseSelector.selecionarDia(
        biblioteca: biblioteca,
        plano: plano,
        perfil: perfil,
        tetoNivel: perfilTreino.tetoNivel,
        variacao: variacao,
      );
      final prescritos = exercicios
          .map(
            (e) => Prescriber.prescrever(
              exercicio: e,
              objetivo: perfil.objetivo,
              conservador: perfilTreino.conservador,
            ),
          )
          .toList(growable: false);
      dias.add(
        DiaTreino(
          nome: plano.nome,
          exercicios: prescritos,
          diasDaSemana: plano.diasDaSemana,
        ),
      );
    }

    final alertas = <String>[
      if (tri.motivos.isNotEmpty) ...tri.motivos.map((m) => 'Atencao: $m'),
      if (perfil.fadigaElevada)
        'Volume reduzido por fadiga/recuperacao relatada.',
    ];

    return TreinoRecomendado(
      bloqueado: false,
      triagem: tri,
      divisao: divisao.tipo,
      dias: dias,
      justificativa: _justificativa(perfil, perfilTreino, divisao.tipo),
      alertas: alertas,
      versaoRegras: versaoRegras,
      entradas: {
        ...entradasBase,
        'divisao': divisao.tipo.name,
        'teto_nivel': perfilTreino.tetoNivel.name,
        'conservador': perfilTreino.conservador,
        'experiencia_efetiva': perfilTreino.experienciaEfetiva.name,
        'variacao': variacao,
      },
    );
  }

  /// RN-044: explica a escolha usando objetivo, frequencia, nivel e prioridade.
  String _justificativa(
    PerfilQuestionario perfil,
    PerfilTreino pt,
    TipoDivisao divisao,
  ) {
    final base =
        'Divisao ${divisao.label} escolhida para ${perfil.diasPorSemana} '
        'dias por semana, objetivo de ${perfil.objetivo.label.toLowerCase()} '
        'e nivel ${pt.experienciaEfetiva.label.toLowerCase()}.';
    final prio = perfil.prioridade == PrioridadeMuscular.corpoTodo
        ? ' O volume cobre o corpo todo de forma equilibrada.'
        : ' Damos enfase em ${perfil.prioridade.label.toLowerCase()} sem '
              'abandonar os demais grupos.';
    final cautela = pt.conservador
        ? ' Volume e intensidade iniciam conservadores para priorizar '
              'seguranca e adesao.'
        : '';
    return '$base$prio$cautela';
  }
}
