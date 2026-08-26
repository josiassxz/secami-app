// Verifica que o CoachRepository monta as queries/RPCs certas (tabela,
// filtros, params, inserts). Captura a requisicao HTTP real com um client
// fake; respostas vazias bastam (asseguramos a REQUISICAO, nao a resposta).
//
// NAO cobre RLS nem o fluxo end-to-end com 2 contas: isso exige um Postgres
// real e validacao manual.

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reps/features/coaching/data/coach_repository.dart';
import 'package:reps/features/coaching/domain/coach_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Req {
  _Req(this.method, this.url, this.body);
  final String method;
  final Uri url;
  final String body;
}

class _Capturing extends http.BaseClient {
  final List<_Req> reqs = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    reqs.add(_Req(request.method, request.url, body));
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  _Req reqContaining(String pathPart) =>
      reqs.firstWhere((r) => r.url.path.contains(pathPart));
}

void main() {
  // CoachRepository() sempre monta um ApiClient real (mesmo quando o teste
  // so exercita o caminho Supabase via `client:`) — desde a migracao REST
  // (E9) o construtor faz `_api = apiClient ?? ApiClient()`, e o construtor
  // do ApiClient le SharedPreferences (_warmCache), o que exige o binding
  // do Flutter inicializado. Sem isso, TODO teste deste arquivo falhava na
  // construcao do repo, antes mesmo de exercitar o que o teste queria
  // verificar (regressao introduzida na migracao, nao pega por `flutter
  // test` na epoca porque essa suite nao rodou de novo depois da mudanca).
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  // `criarConvite`/`resgatarConvite`/`meusAlunos`/`meusTreinadores` checam
  // Env.hasRestApi antes de escolher REST vs Supabase — sem Env.load(), o
  // getter lanca NotInitializedError (flutter_dotenv) em vez de cair no
  // fallback ''. testLoad() inicializa o mapa interno vazio (API_BASE_URL
  // ausente => hasRestApi=false => caminho Supabase, que e o que este
  // arquivo testa) sem precisar de um arquivo .env real.
  dotenv.testLoad(fileInput: '');

  late _Capturing httpClient;
  late SupabaseClient supabase;
  late CoachRepository repo;

  setUp(() {
    httpClient = _Capturing();
    supabase = SupabaseClient(
      'https://exemplo.supabase.co',
      'anon-de-teste',
      httpClient: httpClient,
    );
    repo = CoachRepository(client: supabase, testUid: 'prof-1');
  });

  Future<void> ignorando(Future<void> Function() acao) async {
    // As respostas vazias fazem o parse falhar; so a requisicao importa.
    try {
      await acao();
    } catch (_) {}
  }

  test('criarConvite -> rpc criar_convite com tipo e validade', () async {
    await ignorando(() => repo.criarConvite());
    final r = httpClient.reqContaining('/rpc/criar_convite');
    expect(r.method, 'POST');
    expect(r.body, contains('"p_tipo":"professor_aluno"'));
    expect(r.body, contains('"p_usos_max":1'));
    expect(r.body, contains('"p_validade_dias":7'));
  });

  test('criarConvite org_professor envia org', () async {
    await ignorando(
      () => repo.criarConvite(tipo: 'org_professor', orgId: 'org-9'),
    );
    final r = httpClient.reqContaining('/rpc/criar_convite');
    expect(r.body, contains('"p_tipo":"org_professor"'));
    expect(r.body, contains('"p_org":"org-9"'));
  });

  test('resgatarConvite normaliza o codigo (trim + maiusculo)', () async {
    await ignorando(() => repo.resgatarConvite('  a1b2-c3d4 '));
    final r = httpClient.reqContaining('/rpc/resgatar_convite');
    expect(r.body, contains('"p_codigo":"A1B2-C3D4"'));
  });

  test('meusAlunos filtra professor_id/status e embute aluno', () async {
    await ignorando(() => repo.meusAlunos());
    final r = httpClient.reqContaining('/vinculos');
    expect(r.method, 'GET');
    expect(r.url.queryParameters['professor_id'], 'eq.prof-1');
    expect(r.url.queryParameters['status'], 'eq.ativo');
    expect(r.url.queryParameters['deleted_at'], 'is.null');
    expect(r.url.queryParameters['select'], contains('aluno:users!aluno_id'));
  });

  test('meusTreinadores filtra aluno_id e embute professor', () async {
    await ignorando(() => repo.meusTreinadores());
    final r = httpClient.reqContaining('/vinculos');
    expect(r.url.queryParameters['aluno_id'], 'eq.prof-1');
    expect(
      r.url.queryParameters['select'],
      contains('professor:users!professor_id'),
    );
  });

  test('rotinasAtribuidas filtra user_id/origem/atribuido_por', () async {
    await ignorando(() => repo.rotinasAtribuidas('aluno-7'));
    final r = httpClient.reqContaining('/routines');
    expect(r.url.queryParameters['user_id'], 'eq.aluno-7');
    expect(r.url.queryParameters['origem'], 'eq.atribuida');
    expect(r.url.queryParameters['atribuido_por'], 'eq.prof-1');
  });

  test(
    'evolucaoAluno consulta set_logs por owner_user_id e executada',
    () async {
      await ignorando(() => repo.evolucaoAluno('aluno-7'));
      final logs = httpClient.reqContaining('/set_logs');
      expect(logs.url.queryParameters['owner_user_id'], 'eq.aluno-7');
      expect(logs.url.queryParameters['executada'], 'eq.true');
      expect(logs.url.queryParameters['select'], contains('exercises'));
      final sess = httpClient.reqContaining('/workout_sessions');
      expect(sess.url.queryParameters['user_id'], 'eq.aluno-7');
    },
  );

  test('criarOrg insere com dono = uid', () async {
    await ignorando(() => repo.criarOrg('Minha Box'));
    final r = httpClient.reqContaining('/organizacoes');
    expect(r.method, 'POST');
    expect(r.body, contains('"nome":"Minha Box"'));
    expect(r.body, contains('"dono_user_id":"prof-1"'));
  });

  test('membrosDaOrg filtra por org_id', () async {
    await ignorando(() => repo.membrosDaOrg('org-3'));
    final r = httpClient.reqContaining('/organizacao_membros');
    expect(r.url.queryParameters['org_id'], 'eq.org-3');
  });

  test('atribuirRotina insere routine na conta do aluno (atribuida)', () async {
    await ignorando(
      () => repo.atribuirRotina(
        alunoId: 'aluno-7',
        nome: 'Treino A',
        tipo: 'fixo',
        diasDaSemana: const [1, 3, 5],
        exercicios: const [
          // uuid (nao seed) -> resolve pra ele mesmo e e inserido.
          ExercicioAtribuir(
            exerciseId: 'ex-uuid-1',
            ordem: 0,
            seriesPlanejadasJson: '[]',
          ),
        ],
      ),
    );
    final routine = httpClient.reqs.firstWhere(
      (r) => r.url.path.endsWith('/routines') && r.method == 'POST',
    );
    expect(routine.body, contains('"user_id":"aluno-7"'));
    expect(routine.body, contains('"origem":"atribuida"'));
    expect(routine.body, contains('"atribuido_por":"prof-1"'));

    final exRows = httpClient.reqs.firstWhere(
      (r) => r.url.path.endsWith('/routine_exercises') && r.method == 'POST',
    );
    expect(exRows.body, contains('"exercise_id":"ex-uuid-1"'));
  });

  test('evolucaoAluno agrega volume por grupo e ignora nulos/zeros', () async {
    final responder = _Responding({
      '/workout_sessions': jsonEncode([
        {
          'iniciado_em': '2026-06-05T08:00:00Z',
          'finalizado_em': '2026-06-05T09:00:00Z',
          'duracao_total_segundos': 3600,
        },
        {
          'iniciado_em': '2026-06-03T08:00:00Z',
          'finalizado_em': null,
          'duracao_total_segundos': null,
        },
      ]),
      '/set_logs': jsonEncode([
        {
          'carga_kg': 50,
          'reps_realizadas': 10,
          'exercise': {'grupo_muscular_primario': 'peito'},
        },
        {
          'carga_kg': 60,
          'reps_realizadas': 8,
          'exercise': {'grupo_muscular_primario': 'peito'},
        },
        {
          'carga_kg': 40,
          'reps_realizadas': 10,
          'exercise': {'grupo_muscular_primario': 'costas'},
        },
        // carga nula -> ignorado no volume
        {
          'carga_kg': null,
          'reps_realizadas': 12,
          'exercise': {'grupo_muscular_primario': 'costas'},
        },
        // reps zero -> ignorado no volume
        {
          'carga_kg': 80,
          'reps_realizadas': 0,
          'exercise': {'grupo_muscular_primario': 'pernas'},
        },
      ]),
    });
    final supabase2 = SupabaseClient(
      'https://exemplo.supabase.co',
      'anon-de-teste',
      httpClient: responder,
    );
    final repo2 = CoachRepository(client: supabase2, testUid: 'prof-1');

    final evo = await repo2.evolucaoAluno('aluno-7');
    expect(evo.sessoes30d, 2);
    expect(evo.series30d, 5); // total de set_logs retornados
    expect(evo.volumePorGrupo['peito'], 50 * 10 + 60 * 8); // 980
    expect(evo.volumePorGrupo['costas'], 40 * 10); // 400
    expect(evo.volumePorGrupo.containsKey('pernas'), isFalse);
    expect(evo.ultimaSessao, isNotNull);
  });
}

/// Client fake que responde JSON por trecho do path (para testar parsing
/// e agregacao, nao so a requisicao).
class _Responding extends http.BaseClient {
  _Responding(this.porPath);
  final Map<String, String> porPath;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var body = '[]';
    for (final e in porPath.entries) {
      if (request.url.path.contains(e.key)) {
        body = e.value;
        break;
      }
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}
