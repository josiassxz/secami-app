import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/exercise_id.dart';
import '../domain/coach_models.dart';

const _uuid = Uuid();

/// Erro de coaching com mensagem pronta pra exibir ao usuario (pt-BR).
class CoachException implements Exception {
  CoachException(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Acesso ONLINE aos dados de coaching (vinculos, convites, alunos).
///
/// Le/escreve direto no Supabase (legado) ou no backend SECAMI via REST
/// (`Env.hasRestApi`). **Nunca** usa o Drift local: dados de aluno nao podem
/// entrar no banco local do professor (ver docs/stages/stage-04-coaching.md,
/// secao 5).
///
/// Migração E9 (nota de escopo): `criarConvite`/`resgatarConvite`/
/// `meusAlunos`/`meusTreinadores` funcionam nos dois modos. Os demais
/// métodos (`encerrarVinculo`, `rotinasAtribuidas`, `atribuirRotina`,
/// `evolucaoAluno`, os métodos de academia/org) são features nativas do
/// reps sem equivalente no backend SECAMI ainda — em modo REST puro (sem
/// Supabase configurado) eles falham com uma `CoachException` clara em vez
/// de silenciosamente não fazer nada (ver `_client` abaixo). A prescrição de
/// treino no SECAMI é feita pelas fichas (`WorkoutPlan`, ver
/// `features/academy/`), não por `atribuirRotina`.
class CoachRepository {
  /// Em producao use [instance]. [client]/[testUid] sao seams de teste:
  /// injetam um SupabaseClient e uma identidade sem sessao real de auth.
  CoachRepository({
    SupabaseClient? client,
    @visibleForTesting String? testUid,
    ApiClient? apiClient,
  }) : _override = client,
       // ignore: prefer_initializing_formals (campo privado, param nomeado)
       _testUid = testUid,
       _api = apiClient ?? ApiClient();

  static final CoachRepository instance = CoachRepository();

  final SupabaseClient? _override;
  final String? _testUid;
  final ApiClient _api;

  SupabaseClient get _client {
    final c = _override ?? SupabaseConfig.clientOrNull;
    if (c == null) {
      throw CoachException('Recurso indisponível sem conta conectada.');
    }
    return c;
  }

  String get _uid {
    final id = _testUid ?? _client.auth.currentUser?.id;
    if (id == null) {
      throw CoachException('Entre na sua conta para usar o coaching.');
    }
    return id;
  }

  /// Gera um convite. [tipo] = 'professor_aluno' (aluno entra) ou
  /// 'org_professor' (professor entra numa academia, requer [orgId]).
  Future<ConviteCriado> criarConvite({
    String tipo = 'professor_aluno',
    String? orgId,
    int usosMax = 1,
    int validadeDias = 7,
  }) async {
    if (Env.hasRestApi) {
      try {
        final data =
            await _api.post(
                  '/coach/invites',
                  body: {
                    'tipo': tipo,
                    'orgId': orgId,
                    'usosMax': usosMax,
                    'validadeDias': validadeDias,
                  },
                )
                as Map<String, dynamic>;
        return ConviteCriado.fromRestJson(data);
      } on ApiException catch (e) {
        throw CoachException('Não foi possível gerar o convite: ${e.message}');
      }
    }
    try {
      final res = await _client.rpc<dynamic>(
        'criar_convite',
        params: {
          'p_tipo': tipo,
          'p_org': orgId,
          'p_usos_max': usosMax,
          'p_validade_dias': validadeDias,
        },
      );
      return ConviteCriado.fromJson(_asMap(res));
    } on PostgrestException catch (e) {
      throw CoachException('Não foi possível gerar o convite: ${e.message}');
    }
  }

  /// Aluno resgata um codigo de convite e cria o vinculo.
  Future<void> resgatarConvite(String codigo) async {
    final cod = codigo.trim().toUpperCase();
    if (cod.isEmpty) {
      throw CoachException('Digite o código do convite.');
    }
    if (Env.hasRestApi) {
      try {
        await _api.post('/coach/invites/redeem', body: {'codigo': cod});
      } on ApiException catch (e) {
        throw CoachException(e.message);
      }
      return;
    }
    try {
      await _client.rpc<dynamic>('resgatar_convite', params: {'p_codigo': cod});
    } on PostgrestException catch (e) {
      // A RPC usa `raise exception` com mensagem em pt-BR.
      throw CoachException(e.message);
    }
  }

  /// Lista os alunos ativos do professor logado.
  Future<List<VinculoAluno>> meusAlunos() async {
    if (Env.hasRestApi) {
      try {
        final data = await _api.get('/coach/students') as List;
        return data
            .cast<Map<String, dynamic>>()
            .map(VinculoAluno.fromRestJson)
            .toList();
      } on ApiException catch (e) {
        throw CoachException('Erro ao carregar alunos: ${e.message}');
      }
    }
    try {
      final rows = await _client
          .from('vinculos')
          .select(
            'id, status, aceito_em, aluno:users!aluno_id(id, nome, email)',
          )
          .eq('professor_id', _uid)
          .eq('status', 'ativo')
          .isFilter('deleted_at', null)
          .order('aceito_em', ascending: false);
      return rows
          .cast<Map<String, dynamic>>()
          .map(VinculoAluno.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar alunos: ${e.message}');
    }
  }

  /// Lista os treinadores ativos do aluno logado.
  Future<List<VinculoTreinador>> meusTreinadores() async {
    if (Env.hasRestApi) {
      try {
        final data = await _api.get('/coach/trainers') as List;
        return data
            .cast<Map<String, dynamic>>()
            .map(VinculoTreinador.fromRestJson)
            .toList();
      } on ApiException catch (e) {
        throw CoachException('Erro ao carregar treinadores: ${e.message}');
      }
    }
    try {
      final rows = await _client
          .from('vinculos')
          .select(
            'id, status, professor:users!professor_id(id, nome, email), '
            'org:organizacoes(nome)',
          )
          .eq('aluno_id', _uid)
          .eq('status', 'ativo')
          .isFilter('deleted_at', null);
      return rows
          .cast<Map<String, dynamic>>()
          .map(VinculoTreinador.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar treinadores: ${e.message}');
    }
  }

  /// Encerra um vinculo (qualquer um dos lados pode). O acesso do treinador
  /// cai na hora: eh_treinador_de() so conta vinculos status='ativo'.
  Future<void> encerrarVinculo(String vinculoId) async {
    try {
      await _client
          .from('vinculos')
          .update({
            'status': 'encerrado',
            'encerrado_em': DateTime.now().toUtc().toIso8601String(),
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', vinculoId);
    } on PostgrestException catch (e) {
      throw CoachException('Não foi possível encerrar o vínculo: ${e.message}');
    }
  }

  /// Treinos que o professor logado atribuiu a [alunoId].
  Future<List<RotinaAtribuida>> rotinasAtribuidas(String alunoId) async {
    try {
      final rows = await _client
          .from('routines')
          .select('id, nome, tipo, ativo')
          .eq('user_id', alunoId)
          .eq('origem', 'atribuida')
          .eq('atribuido_por', _uid)
          .isFilter('deleted_at', null)
          .order('criado_em', ascending: false);
      return rows
          .cast<Map<String, dynamic>>()
          .map(RotinaAtribuida.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar treinos: ${e.message}');
    }
  }

  /// Clona uma rotina (montada localmente pelo professor) para a conta do
  /// aluno, marcada como atribuida. Escreve direto no Supabase: a RLS permite
  /// (eh_treinador_de + atribuido_por = eu). Nunca toca o Drift do professor.
  Future<void> atribuirRotina({
    required String alunoId,
    required String nome,
    required String tipo,
    required List<int> diasDaSemana,
    required List<ExercicioAtribuir> exercicios,
  }) async {
    final client = _client;
    final uid = _uid;
    final mapa = await _slugParaUuid();
    final routineId = _uuid.v4();
    try {
      await client.from('routines').insert({
        'id': routineId,
        'user_id': alunoId,
        'nome': nome,
        'tipo': tipo,
        'dias_da_semana': diasDaSemana,
        'ativo': true,
        'origem': 'atribuida',
        'atribuido_por': uid,
      });

      final linhas = <Map<String, dynamic>>[];
      for (final e in exercicios) {
        final eid = ExerciseId.parse(e.exerciseId);
        final dbEx = eid.isSeed ? mapa[eid.value] : e.exerciseId;
        if (dbEx == null) continue; // exercicio nao seedado no banco: ignora
        linhas.add({
          'id': _uuid.v4(),
          'routine_id': routineId,
          'exercise_id': dbEx,
          'ordem': e.ordem,
          'series_planejadas': jsonDecode(e.seriesPlanejadasJson),
          'notas': e.notas,
        });
      }
      if (linhas.isNotEmpty) {
        await client.from('routine_exercises').insert(linhas);
      }
    } on PostgrestException catch (e) {
      throw CoachException('Não foi possível atribuir o treino: ${e.message}');
    }
  }

  /// Evolucao do aluno nos ultimos 30 dias (sessoes, volume por grupo).
  /// Read-only: usa as policies de leitura do treinador (RLS) + owner_user_id.
  Future<EvolucaoAluno> evolucaoAluno(String alunoId) async {
    final desde = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    try {
      final sessoesRaw = await _client
          .from('workout_sessions')
          .select('iniciado_em, finalizado_em, duracao_total_segundos')
          .eq('user_id', alunoId)
          .isFilter('deleted_at', null)
          .gte('iniciado_em', desde)
          .order('iniciado_em', ascending: false);
      final sessoes = sessoesRaw
          .cast<Map<String, dynamic>>()
          .map(SessaoResumo.fromJson)
          .toList();

      final logsRaw = await _client
          .from('set_logs')
          .select(
            'carga_kg, reps_realizadas, '
            'exercise:exercises(grupo_muscular_primario)',
          )
          .eq('owner_user_id', alunoId)
          .eq('executada', true)
          .isFilter('deleted_at', null)
          .gte('criado_em', desde);
      final logs = logsRaw.cast<Map<String, dynamic>>();

      final volume = <String, double>{};
      for (final l in logs) {
        final carga = (l['carga_kg'] as num?)?.toDouble() ?? 0;
        final reps = (l['reps_realizadas'] as int?) ?? 0;
        final grupo =
            (l['exercise'] as Map?)?['grupo_muscular_primario'] as String?;
        if (grupo == null || carga <= 0 || reps <= 0) continue;
        volume[grupo] = (volume[grupo] ?? 0) + carga * reps;
      }

      return EvolucaoAluno(
        sessoes30d: sessoes.length,
        series30d: logs.length,
        volumePorGrupo: volume,
        ultimasSessoes: sessoes.take(10).toList(),
        ultimaSessao: sessoes.isNotEmpty ? sessoes.first.iniciadoEm : null,
      );
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar evolução: ${e.message}');
    }
  }

  /// Mapa slug -> uuid da biblioteca global (criado_por null).
  Future<Map<String, String>> _slugParaUuid() async {
    final rows = await _client.from('exercises').select('id, slug, criado_por');
    final mapa = <String, String>{};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      if (r['criado_por'] != null) continue;
      final id = r['id'] as String?;
      final slug = r['slug'] as String?;
      if (id != null && slug != null) mapa[slug] = id;
    }
    return mapa;
  }

  // ===== Academia (org) =====

  /// Academias que o usuario logado ve (dono ou membro ativo).
  Future<List<Organizacao>> minhasOrgs() async {
    try {
      final rows = await _client
          .from('organizacoes')
          .select('id, nome, dono_user_id')
          .isFilter('deleted_at', null)
          .order('nome');
      return rows
          .cast<Map<String, dynamic>>()
          .map(Organizacao.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar academias: ${e.message}');
    }
  }

  /// Cria uma academia da qual o usuario logado vira dono.
  Future<Organizacao> criarOrg(String nome) async {
    final n = nome.trim();
    if (n.isEmpty) throw CoachException('Dê um nome à academia.');
    try {
      final rows = await _client
          .from('organizacoes')
          .insert({'nome': n, 'dono_user_id': _uid})
          .select('id, nome, dono_user_id');
      return Organizacao.fromJson(rows.first);
    } on PostgrestException catch (e) {
      throw CoachException('Não foi possível criar a academia: ${e.message}');
    }
  }

  /// Professores/membros de uma academia.
  Future<List<MembroOrg>> membrosDaOrg(String orgId) async {
    try {
      final rows = await _client
          .from('organizacao_membros')
          .select('id, papel, status, user:users!user_id(id, nome, email)')
          .eq('org_id', orgId)
          .eq('status', 'ativo')
          .isFilter('deleted_at', null);
      return rows.cast<Map<String, dynamic>>().map(MembroOrg.fromJson).toList();
    } on PostgrestException catch (e) {
      throw CoachException('Erro ao carregar professores: ${e.message}');
    }
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map) return res.cast<String, dynamic>();
    if (res is List && res.isNotEmpty && res.first is Map) {
      return (res.first as Map).cast<String, dynamic>();
    }
    throw CoachException('Resposta inesperada do servidor.');
  }
}
