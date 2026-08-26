// Modelos do modulo de coaching (treinador <-> aluno <-> academia).
//
// Sao DTOs online: vem do Supabase via CoachRepository e nunca tocam o
// Drift local (ver docs/stages/stage-04-coaching.md, secao 5).

/// Pessoa (aluno ou professor) num vinculo.
class PessoaResumo {
  const PessoaResumo({required this.id, required this.email, this.nome});

  final String id;
  final String email;
  final String? nome;

  /// Nome se houver, senao o email (sempre tem algo pra exibir).
  String get exibicao =>
      (nome != null && nome!.trim().isNotEmpty) ? nome!.trim() : email;

  factory PessoaResumo.fromJson(Map<String, dynamic> j) => PessoaResumo(
    id: j['id'] as String,
    email: (j['email'] as String?) ?? '',
    nome: j['nome'] as String?,
  );

  /// Mesmo shape do backend SECAMI (`CoachDtos.PessoaResumo`), que já usa
  /// as mesmas chaves (`id`, `nome`, `email`) — reaproveita fromJson.
  factory PessoaResumo.fromRestJson(Map<String, dynamic> j) =>
      PessoaResumo.fromJson(j);
}

/// Vinculo visto pelo lado do PROFESSOR (o outro lado e o aluno).
class VinculoAluno {
  const VinculoAluno({
    required this.id,
    required this.status,
    required this.aluno,
    this.aceitoEm,
  });

  final String id;
  final String status;
  final DateTime? aceitoEm;
  final PessoaResumo aluno;

  factory VinculoAluno.fromJson(Map<String, dynamic> j) => VinculoAluno(
    id: j['id'] as String,
    status: (j['status'] as String?) ?? 'ativo',
    aceitoEm: _ts(j['aceito_em']),
    aluno: PessoaResumo.fromJson(
      (j['aluno'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  /// Backend SECAMI (`GET /coach/students`): Jackson serializa records em
  /// camelCase (`aceitoEm`), diferente do `aceito_em` do Postgrest legado.
  factory VinculoAluno.fromRestJson(Map<String, dynamic> j) => VinculoAluno(
    id: j['id'] as String,
    status: (j['status'] as String?) ?? 'ativo',
    aceitoEm: _ts(j['aceitoEm']),
    aluno: PessoaResumo.fromRestJson(
      (j['aluno'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

/// Vinculo visto pelo lado do ALUNO (o outro lado e o professor).
class VinculoTreinador {
  const VinculoTreinador({
    required this.id,
    required this.status,
    required this.professor,
    this.orgNome,
  });

  final String id;
  final String status;
  final PessoaResumo professor;
  final String? orgNome;

  factory VinculoTreinador.fromJson(Map<String, dynamic> j) => VinculoTreinador(
    id: j['id'] as String,
    status: (j['status'] as String?) ?? 'ativo',
    orgNome: (j['org'] as Map?)?['nome'] as String?,
    professor: PessoaResumo.fromJson(
      (j['professor'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  /// Backend SECAMI (`GET /coach/trainers`) não tem academia/org — orgNome
  /// fica sempre null nesse modo (organização multi-tenant é feature reps
  /// nativa, fora do escopo desta migração — ver nota em CoachRepository).
  factory VinculoTreinador.fromRestJson(Map<String, dynamic> j) =>
      VinculoTreinador(
        id: j['id'] as String,
        status: (j['status'] as String?) ?? 'ativo',
        professor: PessoaResumo.fromRestJson(
          (j['professor'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

/// Convite recem-criado (codigo a compartilhar com o aluno).
class ConviteCriado {
  const ConviteCriado({required this.codigo, required this.expiraEm});

  final String codigo;
  final DateTime expiraEm;

  factory ConviteCriado.fromJson(Map<String, dynamic> j) => ConviteCriado(
    codigo: j['codigo'] as String,
    expiraEm: _ts(j['expira_em']) ?? DateTime.now().toUtc(),
  );

  /// Backend SECAMI (`POST /coach/invites`): `codigo` + `expiraEm` (camelCase).
  factory ConviteCriado.fromRestJson(Map<String, dynamic> j) => ConviteCriado(
    codigo: j['codigo'] as String,
    expiraEm: _ts(j['expiraEm']) ?? DateTime.now().toUtc(),
  );
}

/// Rotina atribuida a um aluno (vista pelo professor).
class RotinaAtribuida {
  const RotinaAtribuida({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String tipo;
  final bool ativo;

  factory RotinaAtribuida.fromJson(Map<String, dynamic> j) => RotinaAtribuida(
    id: j['id'] as String,
    nome: (j['nome'] as String?) ?? 'Treino',
    tipo: (j['tipo'] as String?) ?? 'fixo',
    ativo: (j['ativo'] as bool?) ?? true,
  );
}

/// Academia (organizacao).
class Organizacao {
  const Organizacao({
    required this.id,
    required this.nome,
    required this.donoUserId,
  });

  final String id;
  final String nome;
  final String donoUserId;

  bool souDono(String uid) => donoUserId == uid;

  factory Organizacao.fromJson(Map<String, dynamic> j) => Organizacao(
    id: j['id'] as String,
    nome: (j['nome'] as String?) ?? 'Academia',
    donoUserId: (j['dono_user_id'] as String?) ?? '',
  );
}

/// Membro (professor/admin) de uma academia.
class MembroOrg {
  const MembroOrg({
    required this.id,
    required this.papel,
    required this.status,
    required this.pessoa,
  });

  final String id;
  final String papel;
  final String status;
  final PessoaResumo pessoa;

  factory MembroOrg.fromJson(Map<String, dynamic> j) => MembroOrg(
    id: j['id'] as String,
    papel: (j['papel'] as String?) ?? 'professor',
    status: (j['status'] as String?) ?? 'ativo',
    pessoa: PessoaResumo.fromJson(
      (j['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

/// Resumo de uma sessao de treino do aluno (read-only).
class SessaoResumo {
  const SessaoResumo({
    required this.iniciadoEm,
    required this.duracaoSegundos,
    required this.finalizada,
  });

  final DateTime iniciadoEm;
  final int? duracaoSegundos;
  final bool finalizada;

  factory SessaoResumo.fromJson(Map<String, dynamic> j) => SessaoResumo(
    iniciadoEm: _ts(j['iniciado_em']) ?? DateTime.now().toUtc(),
    duracaoSegundos: j['duracao_total_segundos'] as int?,
    finalizada: j['finalizado_em'] != null,
  );
}

/// Evolucao consolidada do aluno (ultimos 30 dias), vista pelo professor.
class EvolucaoAluno {
  const EvolucaoAluno({
    required this.sessoes30d,
    required this.series30d,
    required this.volumePorGrupo,
    required this.ultimasSessoes,
    this.ultimaSessao,
  });

  final int sessoes30d;
  final int series30d;
  final Map<String, double> volumePorGrupo;
  final List<SessaoResumo> ultimasSessoes;
  final DateTime? ultimaSessao;

  bool get vazio => sessoes30d == 0 && series30d == 0;
}

/// Um exercicio a clonar na rotina atribuida (dados lidos do Drift local
/// do professor). [exerciseId] pode ser `seed:<slug>` ou um uuid.
class ExercicioAtribuir {
  const ExercicioAtribuir({
    required this.exerciseId,
    required this.ordem,
    required this.seriesPlanejadasJson,
    this.notas,
  });

  final String exerciseId;
  final int ordem;
  final String seriesPlanejadasJson;
  final String? notas;
}

DateTime? _ts(Object? raw) {
  if (raw is String) {
    return DateTime.tryParse(raw)?.toUtc();
  }
  return null;
}
