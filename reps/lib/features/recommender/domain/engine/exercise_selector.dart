import '../../../../domain/entities/exercise.dart';
import '../questionario.dart';
import '../treino_recomendado.dart';

/// Seleciona e ordena exercicios de um dia (RN-009/011/012/033/034).
class ExerciseSelector {
  const ExerciseSelector._();

  /// Numero alvo de exercicios conforme tempo da sessao (RN-010/023).
  static int exerciciosPorTempo(int minutos) {
    if (minutos <= 30) return 4;
    if (minutos <= 45) return 5;
    if (minutos <= 60) return 6;
    if (minutos <= 75) return 7;
    return 8;
  }

  /// Retorna os exercicios de um dia ja filtrados e ordenados (compostos
  /// primeiro, RN-033). [variacao] rotaciona a ordem dos candidatos para gerar
  /// treinos variados sem mudar a logica (RN-047).
  static List<Exercise> selecionarDia({
    required List<Exercise> biblioteca,
    required DiaPlano plano,
    required PerfilQuestionario perfil,
    required NivelTecnico tetoNivel,
    int variacao = 0,
  }) {
    final alvo = exerciciosPorTempo(perfil.minutosPorSessao);

    // Grupos do dia, sem duplicar e sem grupos restritos (RN-009).
    final grupos = <GrupoMuscular>[];
    for (final g in plano.foco) {
      if (!grupos.contains(g) && !perfil.restricoesGrupos.contains(g)) {
        grupos.add(g);
      }
    }

    // Candidatos por grupo, ordenados compostos->isoladores e rotacionados.
    final porGrupo = <GrupoMuscular, List<Exercise>>{};
    for (final g in grupos) {
      final cands =
          biblioteca.where((e) => _compativel(e, g, perfil, tetoNivel)).toList()
            ..sort(_compostoPrimeiro);
      if (cands.isNotEmpty) porGrupo[g] = _rotacionar(cands, variacao);
    }
    if (porGrupo.isEmpty) return const [];

    final ordenados = grupos.where(porGrupo.containsKey).toList();
    final disponiveis = porGrupo.values.fold<int>(0, (a, l) => a + l.length);
    var restante = alvo < disponiveis ? alvo : disponiveis;

    final aloc = {for (final g in ordenados) g: 0};

    // Round 1: garante 1 exercicio por grupo (RN-009: nao zerar grupos).
    for (final g in ordenados) {
      if (restante <= 0) break;
      if (aloc[g]! < porGrupo[g]!.length) {
        aloc[g] = aloc[g]! + 1;
        restante--;
      }
    }

    // Rounds extras: prioridade muscular recebe slots adicionais primeiro.
    final prio = perfil.prioridade.grupos;
    while (restante > 0) {
      var progresso = false;
      for (final preferePrioridade in [true, false]) {
        for (final g in ordenados) {
          if (restante <= 0) break;
          if (prio.contains(g) != preferePrioridade) continue;
          if (aloc[g]! < porGrupo[g]!.length) {
            aloc[g] = aloc[g]! + 1;
            restante--;
            progresso = true;
          }
        }
      }
      if (!progresso) break;
    }

    final escolhidos = <Exercise>[];
    for (final g in ordenados) {
      escolhidos.addAll(porGrupo[g]!.take(aloc[g]!));
    }

    // RN-033: compostos no inicio, isoladores no fim (estavel).
    final multi = escolhidos.where((e) => e.tipo != TipoExercicio.isolador);
    final iso = escolhidos.where((e) => e.tipo == TipoExercicio.isolador);
    return [...multi, ...iso];
  }

  static bool _compativel(
    Exercise e,
    GrupoMuscular grupo,
    PerfilQuestionario perfil,
    NivelTecnico teto,
  ) {
    if (!e.recomendavel || !e.ativo) return false;
    if (e.grupoPrimario != grupo) return false;
    if (_nivelOrdinal(e.nivelTecnico) > _nivelOrdinal(teto)) return false;
    if (!perfil.equipamentos.contains(e.equipamento)) return false;
    if (perfil.exerciciosEvitados.contains(e.slug)) return false;
    return true;
  }

  static int _nivelOrdinal(NivelTecnico n) {
    switch (n) {
      case NivelTecnico.iniciante:
        return 0;
      case NivelTecnico.intermediario:
        return 1;
      case NivelTecnico.avancado:
        return 2;
    }
  }

  static int _compostoPrimeiro(Exercise a, Exercise b) {
    final ai = a.tipo == TipoExercicio.isolador ? 1 : 0;
    final bi = b.tipo == TipoExercicio.isolador ? 1 : 0;
    if (ai != bi) return ai - bi;
    return a.nome.compareTo(b.nome);
  }

  static List<Exercise> _rotacionar(List<Exercise> list, int variacao) {
    if (variacao <= 0 || list.length < 2) return list;
    final n = variacao % list.length;
    if (n == 0) return list;
    return [...list.sublist(n), ...list.sublist(0, n)];
  }
}
