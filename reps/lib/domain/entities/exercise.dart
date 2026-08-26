// Nomes de constantes em snake_case sao intencionais: espelham os enums
// do Postgres declarados em supabase/migrations/0001_init.sql.
// ignore_for_file: constant_identifier_names

/// Enums de classificacao do exercicio. Espelham o modelo de dados em
/// docs/03-data-model.md. Mantidos em portugues por convencao do projeto.
enum GrupoMuscular {
  peito,
  costas,
  ombros,
  biceps,
  triceps,
  quadriceps,
  posterior,
  gluteos,
  panturrilha,
  core;

  String get label {
    switch (this) {
      case GrupoMuscular.peito:
        return 'Peito';
      case GrupoMuscular.costas:
        return 'Costas';
      case GrupoMuscular.ombros:
        return 'Ombros';
      case GrupoMuscular.biceps:
        return 'Biceps';
      case GrupoMuscular.triceps:
        return 'Triceps';
      case GrupoMuscular.quadriceps:
        return 'Quadriceps';
      case GrupoMuscular.posterior:
        return 'Posterior';
      case GrupoMuscular.gluteos:
        return 'Gluteos';
      case GrupoMuscular.panturrilha:
        return 'Panturrilha';
      case GrupoMuscular.core:
        return 'Core';
    }
  }

  static GrupoMuscular? fromString(String? raw) {
    if (raw == null) return null;
    for (final v in GrupoMuscular.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

enum PadraoMovimento {
  puxada_vertical,
  puxada_horizontal,
  empurrada_vertical,
  empurrada_horizontal,
  agachamento,
  dobradica_quadril,
  isolador;

  String get label {
    switch (this) {
      case PadraoMovimento.puxada_vertical:
        return 'Puxada vertical';
      case PadraoMovimento.puxada_horizontal:
        return 'Puxada horizontal';
      case PadraoMovimento.empurrada_vertical:
        return 'Empurrada vertical';
      case PadraoMovimento.empurrada_horizontal:
        return 'Empurrada horizontal';
      case PadraoMovimento.agachamento:
        return 'Agachamento';
      case PadraoMovimento.dobradica_quadril:
        return 'Dobradica de quadril';
      case PadraoMovimento.isolador:
        return 'Isolador';
    }
  }

  static PadraoMovimento? fromString(String? raw) {
    if (raw == null) return null;
    for (final v in PadraoMovimento.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

enum Equipamento {
  barra,
  halter,
  maquina,
  cabo,
  peso_corporal,
  kettlebell,
  anilha;

  String get label {
    switch (this) {
      case Equipamento.barra:
        return 'Barra';
      case Equipamento.halter:
        return 'Halter';
      case Equipamento.maquina:
        return 'Maquina';
      case Equipamento.cabo:
        return 'Cabo';
      case Equipamento.peso_corporal:
        return 'Peso corporal';
      case Equipamento.kettlebell:
        return 'Kettlebell';
      case Equipamento.anilha:
        return 'Anilha';
    }
  }

  static Equipamento? fromString(String? raw) {
    if (raw == null) return null;
    for (final v in Equipamento.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// Nivel tecnico exigido pelo exercicio. Usado pelo recomendador para
/// classificar usuarios e filtrar exercicios (RN-013/014/036). Em duvida, o
/// motor classifica de forma conservadora (mais proximo de iniciante).
enum NivelTecnico {
  iniciante,
  intermediario,
  avancado;

  String get label {
    switch (this) {
      case NivelTecnico.iniciante:
        return 'Iniciante';
      case NivelTecnico.intermediario:
        return 'Intermediario';
      case NivelTecnico.avancado:
        return 'Avancado';
    }
  }

  static NivelTecnico? fromString(String? raw) {
    if (raw == null) return null;
    for (final v in NivelTecnico.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// Tipo do exercicio (RN-032). Multiarticular e isolador sao derivados do
/// padrao de movimento; mobilidade e cardio existem no enum para fidelidade ao
/// modelo de dados, mas nenhum exercicio canonico se enquadra neles na v1.
enum TipoExercicio {
  multiarticular,
  isolador,
  mobilidade,
  cardio;

  String get label {
    switch (this) {
      case TipoExercicio.multiarticular:
        return 'Multiarticular';
      case TipoExercicio.isolador:
        return 'Isolador';
      case TipoExercicio.mobilidade:
        return 'Mobilidade';
      case TipoExercicio.cardio:
        return 'Cardio';
    }
  }
}

class Exercise {
  const Exercise({
    required this.id,
    required this.slug,
    required this.nome,
    required this.descricao,
    required this.grupoPrimario,
    required this.gruposSecundarios,
    required this.padraoMovimento,
    required this.equipamento,
    this.nivelTecnico = NivelTecnico.iniciante,
    this.recomendavel = false,
    this.ativo = true,
    this.criadoPor,
    this.arquivado = false,
    this.medidaPorTempo = false,
  });

  final String id;
  final String slug;
  final String nome;
  final String descricao;
  final GrupoMuscular grupoPrimario;
  final List<GrupoMuscular> gruposSecundarios;
  final PadraoMovimento padraoMovimento;
  final Equipamento equipamento;

  /// Nivel tecnico exigido (RN-013/014/036).
  final NivelTecnico nivelTecnico;

  /// Se o exercicio pode entrar na recomendacao automatica. Na v1 apenas os
  /// 100 canonicos (`exercisesSeed`) sao `true`; extended e custom ficam
  /// `false` (continuam pesquisaveis e usaveis manualmente).
  final bool recomendavel;

  /// Exercicio ativo na biblioteca (RN-048 / CA-007). Inativo nao entra em
  /// novos treinos mas preserva historico.
  final bool ativo;

  final String? criadoPor;
  final bool arquivado;

  /// Exercicio medido por tempo (isometria, farmer carry) em vez de
  /// repeticoes. Na execucao, o input de reps vira um timer regressivo.
  final bool medidaPorTempo;

  /// Tipo derivado do padrao de movimento. Isolador -> isolador; qualquer
  /// outro padrao -> multiarticular (RN-032/033).
  TipoExercicio get tipo => padraoMovimento == PadraoMovimento.isolador
      ? TipoExercicio.isolador
      : TipoExercicio.multiarticular;

  String get assetPath => 'assets/exercises/$slug.gif';
}
