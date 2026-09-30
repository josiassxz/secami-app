// Widget tests das fichas de um aluno (lado instrutor) — dados, expansão dos
// exercícios, vazio, erro, exclusão com confirmação e navegação pro editor.
// Sem rede: instructorApiProvider é substituído por um fake via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/instructor/data/instructor_api.dart';
import 'package:reps/features/instructor/presentation/ficha_editor_screen.dart';
import 'package:reps/features/instructor/presentation/fichas_aluno_screen.dart';

import '../support/fake_instructor_api.dart';

final _fichaA = InstructorWorkoutPlan(
  id: 'p1',
  studentId: 'a1',
  studentName: 'Ana Beatriz Souza',
  sheetLabel: 'A',
  title: 'Peito e tríceps',
  validUntil: DateTime(2030, 12, 31),
  exercises: const [
    PlanExerciseItem(
      exerciseId: 'e1',
      exerciseName: 'Supino reto',
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      notes: 'Cadência lenta na descida',
    ),
    PlanExerciseItem(exerciseName: 'Tríceps corda', ordem: 1, sets: 4),
  ],
);

const _fichaB = InstructorWorkoutPlan(
  id: 'p2',
  studentId: 'a1',
  studentName: 'Ana Beatriz Souza',
  sheetLabel: 'B',
  title: 'Costas',
  active: false,
  exercises: [PlanExerciseItem(exerciseName: 'Remada curvada')],
);

void main() {
  Future<void> pumpTela(
    WidgetTester tester,
    FakeInstructorApi api, {
    String? studentName = 'Ana Beatriz Souza',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [instructorApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: FichasAlunoScreen(studentId: 'a1', studentName: studentName),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Deixa animações curtas (diálogo, expansão, SnackBar) terminarem sem
  /// depender de pumpAndSettle.
  Future<void> assentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lista as fichas com rótulo, título, contagem e selos', (
    tester,
  ) async {
    // Fora de ordem de propósito: a tela ordena por rótulo (A, B, ...).
    final api = FakeInstructorApi()..plans = [_fichaB, _fichaA];
    await pumpTela(tester, api);

    expect(find.text('Ana Beatriz Souza'), findsOneWidget); // AppBar
    expect(find.text('Peito e tríceps'), findsOneWidget);
    expect(find.text('2 exercícios'), findsOneWidget);
    expect(find.text('válida até 31/12/2030'), findsOneWidget);
    expect(find.text('Costas'), findsOneWidget);
    expect(find.text('1 exercício'), findsOneWidget);
    // Só a ficha B está inativa.
    expect(find.text('inativa'), findsOneWidget);

    final yA = tester.getTopLeft(find.text('Peito e tríceps')).dy;
    final yB = tester.getTopLeft(find.text('Costas')).dy;
    expect(yA, lessThan(yB));

    expect(find.widgetWithText(TextButton, 'Editar'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, 'Excluir'), findsNWidgets(2));
    expect(find.text('Nova ficha'), findsOneWidget);
    // Exercícios só aparecem ao expandir.
    expect(find.text('Supino reto'), findsNothing);
  });

  testWidgets('expandir a ficha mostra os exercícios prescritos', (
    tester,
  ) async {
    final api = FakeInstructorApi()..plans = [_fichaA];
    await pumpTela(tester, api);

    await tester.tap(find.text('Peito e tríceps'));
    await assentar(tester);

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('3 × 10-12'), findsOneWidget);
    expect(find.text('descanso 60s'), findsOneWidget);
    expect(find.text('Cadência lenta na descida'), findsOneWidget);
    // Só séries, sem repetições nem descanso.
    expect(find.text('Tríceps corda'), findsOneWidget);
    expect(find.text('4 séries'), findsOneWidget);

    // Tocar de novo recolhe.
    await tester.tap(find.text('Peito e tríceps'));
    await assentar(tester);
    expect(find.text('Supino reto'), findsNothing);
  });

  testWidgets('mostra progresso enquanto as fichas carregam', (tester) async {
    final api = _ApiQueNuncaResponde();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [instructorApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: FichasAlunoScreen(studentId: 'a1', studentName: 'Ana'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('estado vazio convida a criar a primeira ficha', (tester) async {
    final api = FakeInstructorApi();
    await pumpTela(tester, api);

    expect(find.text('Nenhuma ficha cadastrada.'), findsOneWidget);
    expect(
      find.text('Toque em "Nova ficha" para criar a primeira.'),
      findsOneWidget,
    );
    expect(find.text('Nova ficha'), findsOneWidget);
  });

  testWidgets('sem nome na rota (refresh no web) usa o nome vindo das fichas', (
    tester,
  ) async {
    final api = FakeInstructorApi()..plans = [_fichaA];
    await pumpTela(tester, api, studentName: null);

    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
  });

  testWidgets('sem nome e sem fichas, o título cai em "Aluno"', (tester) async {
    final api = FakeInstructorApi();
    await pumpTela(tester, api, studentName: null);

    expect(find.text('Aluno'), findsOneWidget);
    expect(find.text('Nenhuma ficha cadastrada.'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem amigável e tenta de novo', (tester) async {
    final api = FakeInstructorApi()
      ..plans = [_fichaA]
      ..plansError = Exception('SocketException: connection refused');
    await pumpTela(tester, api);

    expect(find.text('Não foi possível carregar as fichas.'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);

    api.plansError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Peito e tríceps'), findsOneWidget);
    expect(find.text('Não foi possível carregar as fichas.'), findsNothing);
  });

  group('excluir', () {
    testWidgets('pede confirmação antes de chamar a API', (tester) async {
      final api = FakeInstructorApi()..plans = [_fichaA, _fichaB];
      await pumpTela(tester, api);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir').first);
      await assentar(tester);

      expect(find.text('Excluir ficha?'), findsOneWidget);
      expect(find.textContaining('A — Peito e tríceps'), findsOneWidget);
      expect(api.deleted, isEmpty);
    });

    testWidgets('"Cancelar" fecha o diálogo sem excluir', (tester) async {
      final api = FakeInstructorApi()..plans = [_fichaA];
      await pumpTela(tester, api);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await assentar(tester);

      expect(find.text('Excluir ficha?'), findsNothing);
      expect(api.deleted, isEmpty);
      expect(find.text('Peito e tríceps'), findsOneWidget);
    });

    testWidgets('confirmar exclui, recarrega a lista e avisa em SnackBar', (
      tester,
    ) async {
      final api = FakeInstructorApi()..plans = [_fichaA, _fichaB];
      await pumpTela(tester, api);
      expect(api.studentPlansCalls, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir').first);
      await assentar(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await assentar(tester);

      expect(api.deleted, ['p1']);
      expect(api.studentPlansCalls, 2); // lista recarregada
      expect(find.text('Ficha excluída.'), findsOneWidget);
      expect(find.text('Peito e tríceps'), findsNothing);
      expect(find.text('Costas'), findsOneWidget);
    });

    testWidgets('falha ao excluir mantém a ficha e mostra a mensagem', (
      tester,
    ) async {
      final api = FakeInstructorApi()
        ..plans = [_fichaA]
        ..deleteError = ApiException(403, 'Sem permissão para excluir.');
      await pumpTela(tester, api);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await assentar(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await assentar(tester);

      expect(find.text('Sem permissão para excluir.'), findsOneWidget);
      expect(find.text('Peito e tríceps'), findsOneWidget);
      // Botões voltam a ficar habilitados pra nova tentativa.
      final excluir = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Excluir'),
      );
      expect(excluir.onPressed, isNotNull);
    });
  });

  group('navegação pro editor', () {
    FichaEditorArgs? recebido;
    String? planoNaUrl;

    Future<void> pumpComRouter(
      WidgetTester tester,
      FakeInstructorApi api,
    ) async {
      recebido = null;
      planoNaUrl = null;
      final router = GoRouter(
        initialLocation: '/instrutor/aluno/a1',
        routes: [
          GoRoute(
            path: '/instrutor/aluno/:id',
            builder: (_, state) => FichasAlunoScreen(
              studentId: state.pathParameters['id']!,
              studentName: 'Ana Beatriz Souza',
            ),
          ),
          GoRoute(
            path: '/instrutor/aluno/:id/ficha',
            builder: (_, state) {
              recebido = state.extra as FichaEditorArgs?;
              planoNaUrl = state.uri.queryParameters['plano'];
              return const Scaffold(body: Text('editor'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [instructorApiProvider.overrideWithValue(api)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('"Nova ficha" abre o editor sem plano, com os rótulos usados', (
      tester,
    ) async {
      final api = FakeInstructorApi()..plans = [_fichaA, _fichaB];
      await pumpComRouter(tester, api);

      await tester.tap(find.text('Nova ficha'));
      await assentar(tester);

      expect(find.text('editor'), findsOneWidget);
      expect(recebido!.plan, isNull);
      expect(recebido!.usedLabels, ['A', 'B']);
      expect(recebido!.studentName, 'Ana Beatriz Souza');
      expect(planoNaUrl, isNull);
    });

    testWidgets('"Editar" abre o editor com a ficha escolhida', (tester) async {
      final api = FakeInstructorApi()..plans = [_fichaA, _fichaB];
      await pumpComRouter(tester, api);

      await tester.tap(find.widgetWithText(TextButton, 'Editar').last);
      await assentar(tester);

      expect(find.text('editor'), findsOneWidget);
      expect(recebido!.plan!.id, 'p2');
      // Rótulos das OUTRAS fichas (a própria não conta como repetida).
      expect(recebido!.usedLabels, ['A']);
      expect(planoNaUrl, 'p2');
    });
  });

  testWidgets('cabe num celular de 360 px, inclusive com a ficha expandida', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FakeInstructorApi()
      ..plans = [
        InstructorWorkoutPlan(
          id: 'p9',
          studentId: 'a1',
          sheetLabel: 'D',
          title: 'Membros inferiores com ênfase em posterior de coxa',
          active: false,
          validUntil: DateTime(2030, 1, 5),
          exercises: const [
            PlanExerciseItem(
              exerciseName: 'Levantamento terra romeno com halteres',
              sets: 4,
              reps: '8-10 cada perna',
              restSeconds: 120,
              notes:
                  'Manter a coluna neutra e descer até sentir o posterior '
                  'alongar, sem dobrar demais os joelhos.',
            ),
          ],
        ),
      ];
    await pumpTela(tester, api);
    await tester.tap(find.textContaining('Membros inferiores'));
    await assentar(tester);

    expect(find.text('válida até 05/01/2030'), findsOneWidget);
    expect(find.text('4 × 8-10 cada perna'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Botões de ação com pelo menos 48 px de altura.
    final editar = tester.getSize(find.widgetWithText(TextButton, 'Editar'));
    expect(editar.height, greaterThanOrEqualTo(48));
  });
}

/// `studentPlans` fica pendente pra sempre (estado de carregamento).
class _ApiQueNuncaResponde extends FakeInstructorApi {
  @override
  Future<List<InstructorWorkoutPlan>> studentPlans(String studentId) =>
      Completer<List<InstructorWorkoutPlan>>().future;
}
