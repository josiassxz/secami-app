import '../../../domain/entities/exercise.dart';

/// Objetivo principal do treino (RN-008). So um pode ser principal; os demais
/// entram como secundarios. Orienta volume, intensidade e divisao.
enum Objetivo {
  hipertrofia,
  forca,
  emagrecimento,
  saude,
  condicionamento,
  mobilidade,
  performance;

  String get label {
    switch (this) {
      case Objetivo.hipertrofia:
        return 'Hipertrofia';
      case Objetivo.forca:
        return 'Forca';
      case Objetivo.emagrecimento:
        return 'Emagrecimento';
      case Objetivo.saude:
        return 'Saude geral';
      case Objetivo.condicionamento:
        return 'Condicionamento';
      case Objetivo.mobilidade:
        return 'Mobilidade';
      case Objetivo.performance:
        return 'Performance';
    }
  }
}

/// Prioridade muscular do usuario (RN-009). Aumenta volume relativo do grupo
/// escolhido sem zerar os demais.
enum PrioridadeMuscular {
  corpoTodo,
  pernasGluteos,
  superiores,
  costas,
  peito,
  bracos,
  abdomen;

  String get label {
    switch (this) {
      case PrioridadeMuscular.corpoTodo:
        return 'Corpo todo';
      case PrioridadeMuscular.pernasGluteos:
        return 'Pernas e gluteos';
      case PrioridadeMuscular.superiores:
        return 'Superiores';
      case PrioridadeMuscular.costas:
        return 'Costas';
      case PrioridadeMuscular.peito:
        return 'Peito';
      case PrioridadeMuscular.bracos:
        return 'Bracos';
      case PrioridadeMuscular.abdomen:
        return 'Abdomen';
    }
  }

  /// Grupos musculares que recebem enfase quando esta prioridade e escolhida.
  Set<GrupoMuscular> get grupos {
    switch (this) {
      case PrioridadeMuscular.corpoTodo:
        return GrupoMuscular.values.toSet();
      case PrioridadeMuscular.pernasGluteos:
        return {
          GrupoMuscular.quadriceps,
          GrupoMuscular.posterior,
          GrupoMuscular.gluteos,
          GrupoMuscular.panturrilha,
        };
      case PrioridadeMuscular.superiores:
        return {
          GrupoMuscular.peito,
          GrupoMuscular.costas,
          GrupoMuscular.ombros,
          GrupoMuscular.biceps,
          GrupoMuscular.triceps,
        };
      case PrioridadeMuscular.costas:
        return {GrupoMuscular.costas};
      case PrioridadeMuscular.peito:
        return {GrupoMuscular.peito};
      case PrioridadeMuscular.bracos:
        return {GrupoMuscular.biceps, GrupoMuscular.triceps};
      case PrioridadeMuscular.abdomen:
        return {GrupoMuscular.core};
    }
  }
}

/// Local de treino (RN-011/034). Define o conjunto de equipamentos sugerido.
enum LocalTreino {
  academiaCompleta,
  academiaSimples,
  casa,
  arLivre;

  String get label {
    switch (this) {
      case LocalTreino.academiaCompleta:
        return 'Academia completa';
      case LocalTreino.academiaSimples:
        return 'Academia simples';
      case LocalTreino.casa:
        return 'Casa';
      case LocalTreino.arLivre:
        return 'Ar livre';
    }
  }

  /// Equipamentos pre-marcados ao escolher o local (o usuario pode ajustar).
  Set<Equipamento> get equipamentosPadrao {
    switch (this) {
      case LocalTreino.academiaCompleta:
        return Equipamento.values.toSet();
      case LocalTreino.academiaSimples:
        return {
          Equipamento.barra,
          Equipamento.halter,
          Equipamento.maquina,
          Equipamento.peso_corporal,
          Equipamento.anilha,
        };
      case LocalTreino.casa:
        return {
          Equipamento.halter,
          Equipamento.peso_corporal,
          Equipamento.kettlebell,
        };
      case LocalTreino.arLivre:
        return {Equipamento.peso_corporal};
    }
  }
}

/// Nivel de experiencia declarado pelo usuario (secao 7). Diferente de
/// [NivelTecnico] do exercicio: este e o perfil da pessoa.
enum NivelExperiencia {
  nuncaTreinou,
  iniciante,
  intermediario,
  avancado;

  String get label {
    switch (this) {
      case NivelExperiencia.nuncaTreinou:
        return 'Nunca treinou';
      case NivelExperiencia.iniciante:
        return 'Iniciante';
      case NivelExperiencia.intermediario:
        return 'Intermediario';
      case NivelExperiencia.avancado:
        return 'Avancado';
    }
  }
}

/// Respostas do questionario de perfil (secao 6 do PDF). Campos opcionais
/// (idade/sexo/peso/altura) nao bloqueiam a geracao.
class PerfilQuestionario {
  const PerfilQuestionario({
    required this.objetivo,
    required this.prioridade,
    required this.experiencia,
    required this.diasPorSemana,
    required this.minutosPorSessao,
    required this.local,
    required this.equipamentos,
    this.objetivosSecundarios = const {},
    this.restricoesGrupos = const {},
    this.exerciciosEvitados = const {},
    this.idade,
    this.retornoAposPausa = false,
    this.fadigaElevada = false,
  });

  final Objetivo objetivo;
  final Set<Objetivo> objetivosSecundarios;
  final PrioridadeMuscular prioridade;
  final NivelExperiencia experiencia;

  /// Dias de treino por semana (2..6). Define a divisao (RN-018..022).
  final int diasPorSemana;

  /// Minutos por sessao. Define quantidade de exercicios (RN-010/023).
  final int minutosPorSessao;

  final LocalTreino local;
  final Set<Equipamento> equipamentos;

  /// Grupos musculares a evitar por limitacao/lesao (RN-009).
  final Set<GrupoMuscular> restricoesGrupos;

  /// Slugs de exercicios que o usuario nao quer (RN-012).
  final Set<String> exerciciosEvitados;

  final int? idade;

  /// Retorno apos longa pausa -> tratar conservador (RN-017).
  final bool retornoAposPausa;

  /// Fadiga/recuperacao ruim relatada -> reduzir volume (RN-040).
  final bool fadigaElevada;

  /// RN-007: campos minimos para gerar treino.
  bool get completoParaGerar =>
      equipamentos.isNotEmpty &&
      diasPorSemana >= 2 &&
      diasPorSemana <= 6 &&
      minutosPorSessao >= 20;

  Map<String, dynamic> toJson() => {
    'objetivo': objetivo.name,
    'objetivos_secundarios': objetivosSecundarios.map((o) => o.name).toList(),
    'prioridade': prioridade.name,
    'experiencia': experiencia.name,
    'dias_por_semana': diasPorSemana,
    'minutos_por_sessao': minutosPorSessao,
    'local': local.name,
    'equipamentos': equipamentos.map((e) => e.name).toList(),
    'restricoes_grupos': restricoesGrupos.map((g) => g.name).toList(),
    'exercicios_evitados': exerciciosEvitados.toList(),
    'idade': idade,
    'retorno_apos_pausa': retornoAposPausa,
    'fadiga_elevada': fadigaElevada,
  };
}
