// InstructorApi: URLs, corpo das requisições e parse defensivo das respostas
// (campos nulos são omitidos pelo backend — Jackson non_null). Sem rede:
// http.Client é um MockClient.

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/instructor/data/instructor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda as requisições feitas e responde com [status]/[body] em JSON.
class _Servidor {
  _Servidor(this.body, {this.status = 200});

  final Object? body;
  final int status;
  final List<http.Request> requests = [];

  InstructorApi get api => InstructorApi(
    ApiClient(
      client: MockClient((req) async {
        requests.add(req);
        return http.Response.bytes(
          utf8.encode(body == null ? '' : jsonEncode(body)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );

  http.Request get ultima => requests.last;
}

void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('students', () {
    test(
      'sempre manda perfil=aluno, page e size; q só quando há termo',
      () async {
        final s = _Servidor({'content': <Object>[]});
        await s.api.students();

        expect(s.ultima.method, 'GET');
        expect(s.ultima.url.path, '/students');
        expect(s.ultima.url.queryParameters, {
          'page': '0',
          'size': '20',
          'perfil': 'aluno',
        });

        await s.api.students(q: '   ', page: 3);
        expect(s.ultima.url.queryParameters.containsKey('q'), isFalse);
        expect(s.ultima.url.queryParameters['page'], '3');
      },
    );

    test('q vai URL-encoded (espaço, acento, & e pontuação de CPF)', () async {
      final s = _Servidor({'content': <Object>[]});
      await s.api.students(q: ' João & Maria 123.456 ');

      expect(s.ultima.url.queryParameters['q'], 'João & Maria 123.456');
      expect(s.ultima.url.queryParameters['perfil'], 'aluno');
      // O "&" do termo não pode virar separador de parâmetro.
      expect(s.ultima.url.queryParameters.length, 4);
      expect(s.ultima.url.query, isNot(contains(' ')));
    });

    test('parseia a página com campos opcionais ausentes', () async {
      final s = _Servidor({
        'content': [
          {
            'id': 'a1',
            'fullName': 'Ana Souza',
            'cpf': '***.456.789-**',
            'studentType': 'Militar',
            'departmentName': 'Casa Militar',
            'situacao': 'BLOQUEADO',
            'active': false,
            'photoId': 'f1',
          },
          {'id': 'a2', 'fullName': 'Bruno Lima'},
        ],
        'totalElements': 45,
        'totalPages': 3,
        'number': 0,
        'last': false,
      });
      final page = await s.api.students();

      expect(page.content, hasLength(2));
      expect(page.totalElements, 45);
      expect(page.totalPages, 3);
      expect(page.last, isFalse);

      final ana = page.content[0];
      expect(ana.fullName, 'Ana Souza');
      expect(ana.studentType, 'Militar');
      expect(ana.departmentName, 'Casa Militar');
      expect(ana.situacao, 'BLOQUEADO');
      expect(ana.isAtivo, isFalse);

      final bruno = page.content[1];
      expect(bruno.departmentName, isNull);
      expect(bruno.photoId, isNull);
      expect(bruno.studentType, 'Civil');
      expect(bruno.isAtivo, isTrue);
    });

    test(
      'sem "last", deduz pelo total de páginas (inclusive aninhado)',
      () async {
        final raiz = _Servidor({
          'content': <Object>[],
          'number': 1,
          'totalPages': 2,
        });
        expect((await raiz.api.students(page: 1)).last, isTrue);

        final aninhado = _Servidor({
          'content': <Object>[],
          'page': {
            'number': 0,
            'totalPages': 4,
            'totalElements': 70,
            'size': 20,
          },
        });
        final page = await aninhado.api.students();
        expect(page.last, isFalse);
        expect(page.totalElements, 70);
      },
    );
  });

  group('fichas', () {
    const planoJson = {
      'id': 'p1',
      'studentId': 'a1',
      'studentName': 'Ana Souza',
      'professorId': 'u9',
      'sheetLabel': 'B',
      'title': 'Costas e bíceps',
      'active': false,
      'validUntil': '2030-12-31',
      'exercises': [
        {'exerciseName': 'Rosca direta', 'ordem': 1, 'sets': 3, 'reps': '12'},
        {
          'exerciseId': 'e1',
          'exerciseName': 'Remada curvada',
          'ordem': 0,
          'sets': 4,
          'reps': '8-10',
          'restSeconds': 90,
          'notes': 'Coluna neutra',
        },
      ],
    };

    test(
      'studentPlans busca por aluno e ordena exercícios por "ordem"',
      () async {
        final s = _Servidor([planoJson]);
        final planos = await s.api.studentPlans('a1');

        expect(s.ultima.method, 'GET');
        expect(s.ultima.url.path, '/students/a1/workout-plans');

        final p = planos.single;
        expect(p.sheetLabel, 'B');
        expect(p.title, 'Costas e bíceps');
        expect(p.active, isFalse);
        expect(p.validUntil, DateTime(2030, 12, 31));
        expect(p.studentName, 'Ana Souza');
        expect(p.exercises.map((e) => e.exerciseName), [
          'Remada curvada',
          'Rosca direta',
        ]);
        expect(p.exercises.first.restSeconds, 90);
        expect(p.exercises.first.notes, 'Coluna neutra');
        // Campos omitidos pelo backend viram null, sem quebrar o parse.
        expect(p.exercises.last.exerciseId, isNull);
        expect(p.exercises.last.restSeconds, isNull);
        expect(p.exercises.last.notes, isNull);
      },
    );

    test('ficha mínima (sem validade nem exercícios) usa padrões', () async {
      final s = _Servidor([
        {'id': 'p2', 'studentId': 'a1', 'title': 'Pernas'},
      ]);
      final p = (await s.api.studentPlans('a1')).single;

      expect(p.sheetLabel, 'A');
      expect(p.active, isTrue);
      expect(p.validUntil, isNull);
      expect(p.exercises, isEmpty);
    });

    const payload = WorkoutPlanPayload(
      studentId: 'a1',
      sheetLabel: 'C',
      title: 'Pernas',
      active: true,
      exercises: [
        PlanExerciseItem(
          exerciseId: 'e7',
          exerciseName: 'Agachamento livre',
          sets: 4,
          reps: '8-10',
          restSeconds: 90,
          notes: 'Amplitude completa',
        ),
        PlanExerciseItem(exerciseName: 'Panturrilha em pé'),
      ],
    );

    test('createPlan faz POST /workout-plans com o corpo esperado', () async {
      final s = _Servidor({...planoJson, 'id': 'novo'});
      final criado = await s.api.createPlan(payload);

      expect(criado.id, 'novo');
      expect(s.ultima.method, 'POST');
      expect(s.ultima.url.path, '/workout-plans');
      expect(jsonDecode(s.ultima.body), {
        'studentId': 'a1',
        'sheetLabel': 'C',
        'title': 'Pernas',
        'active': true,
        'validUntil': null,
        'exercises': [
          {
            'exerciseId': 'e7',
            'exerciseName': 'Agachamento livre',
            'sets': 4,
            'reps': '8-10',
            'restSeconds': 90,
            'notes': 'Amplitude completa',
          },
          {
            'exerciseId': null,
            'exerciseName': 'Panturrilha em pé',
            'sets': null,
            'reps': null,
            'restSeconds': null,
            'notes': null,
          },
        ],
      });
    });

    test(
      'updatePlan faz PUT /workout-plans/{id}; validade em YYYY-MM-DD',
      () async {
        final s = _Servidor(planoJson);
        await s.api.updatePlan(
          'p1',
          WorkoutPlanPayload(
            studentId: 'a1',
            sheetLabel: 'B',
            title: 'Costas',
            active: false,
            validUntil: DateTime(2031, 3, 5),
            exercises: const [],
          ),
        );

        expect(s.ultima.method, 'PUT');
        expect(s.ultima.url.path, '/workout-plans/p1');
        final body = jsonDecode(s.ultima.body) as Map<String, dynamic>;
        expect(body['validUntil'], '2031-03-05');
        expect(body['active'], isFalse);
        expect(body['exercises'], isEmpty);
      },
    );

    test(
      'deletePlan faz DELETE /workout-plans/{id} (resposta sem corpo)',
      () async {
        final s = _Servidor(null, status: 204);
        await s.api.deletePlan('p1');

        expect(s.ultima.method, 'DELETE');
        expect(s.ultima.url.path, '/workout-plans/p1');
      },
    );

    test(
      'erro do backend chega como ApiException com a mensagem pt-BR',
      () async {
        final s = _Servidor({'message': 'Aluno não encontrado.'}, status: 404);

        await expectLater(
          s.api.createPlan(payload),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 404)
                .having((e) => e.message, 'message', 'Aluno não encontrado.'),
          ),
        );
      },
    );
  });

  group('exercises', () {
    test('ignora arquivados e aceita campos opcionais ausentes', () async {
      final s = _Servidor([
        {
          'id': 'e1',
          'name': 'Supino reto',
          'muscleGroup': 'Peito',
          'equipment': 'Barra',
          'arquivado': false,
        },
        {'id': 'e2', 'name': 'Exercício antigo', 'arquivado': true},
        {'id': 'e3', 'name': 'Prancha', 'muscleGroup': '  '},
      ]);
      final lista = await s.api.exercises();

      expect(s.ultima.url.path, '/exercises');
      expect(s.ultima.url.hasQuery, isFalse);
      expect(lista.map((e) => e.name), ['Supino reto', 'Prancha']);
      expect(lista.first.muscleGroup, 'Peito');
      expect(lista.first.equipment, 'Barra');
      // Grupo em branco conta como "sem grupo".
      expect(lista.last.muscleGroup, isNull);
      expect(lista.last.equipment, isNull);
    });

    test('q e grupo vão URL-encoded', () async {
      final s = _Servidor(<Object>[]);
      await s.api.exercises(q: 'rosca direta', grupo: 'Bíceps');

      expect(s.ultima.url.queryParameters, {
        'q': 'rosca direta',
        'grupo': 'Bíceps',
      });
    });
  });
}
