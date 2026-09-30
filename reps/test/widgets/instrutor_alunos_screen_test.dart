// Widget tests da lista de alunos do instrutor — dados, vazio, erro com
// "tentar novamente", busca com debounce, paginação e navegação. Sem rede:
// instructorApiProvider é substituído por um fake via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/instructor/data/instructor_api.dart';
import 'package:reps/features/instructor/presentation/alunos_instrutor_screen.dart';

import '../support/fake_instructor_api.dart';

const _ana = StudentSummary(
  id: 'a1',
  fullName: 'Ana Beatriz Souza',
  studentType: 'Civil',
  departmentName: 'Secretaria da Economia',
);
const _bruno = StudentSummary(
  id: 'a2',
  fullName: 'Bruno Lima',
  studentType: 'Militar',
  situacao: 'BLOQUEADO',
  active: false,
);
const _carla = StudentSummary(
  id: 'a3',
  fullName: 'Carla',
  studentType: 'Civil',
  departmentName: 'SEDUC',
  situacao: 'INATIVO',
  active: false,
);

void main() {
  Future<void> pumpTela(WidgetTester tester, FakeInstructorApi api) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [instructorApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AlunosInstrutorScreen()),
      ),
    );
    await tester.pump();
  }

  /// Passa do debounce da busca e deixa a resposta do fake chegar.
  Future<void> esperarBusca(WidgetTester tester) async {
    await tester.pump(
      AlunosInstrutorScreen.debounce + const Duration(milliseconds: 50),
    );
    await tester.pump();
  }

  testWidgets('lista os alunos com iniciais, tipo, secretaria e situação', (
    tester,
  ) async {
    final api = FakeInstructorApi()..alunos = const [_ana, _bruno, _carla];
    await pumpTela(tester, api);

    expect(find.text('Alunos'), findsOneWidget); // título da AppBar
    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget); // iniciais no avatar
    expect(find.text('Civil · Secretaria da Economia'), findsOneWidget);

    // Sem secretaria: só o tipo. Situação diferente de ATIVO vira selo.
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('Militar'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);
    expect(find.text('C'), findsOneWidget); // nome de uma palavra só
    // Aluno ativo não ganha selo.
    expect(find.text('Ativo'), findsNothing);

    expect(api.studentCalls, [(q: '', page: 0)]);
    expect(find.text('Carregar mais'), findsNothing); // página única
  });

  testWidgets('mostra progresso enquanto a primeira página carrega', (
    tester,
  ) async {
    final api = FakeInstructorApi()
      ..onStudents = (_, _) => Completer<StudentsPage>().future;
    await pumpTela(tester, api);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('estado vazio: "Nenhum aluno encontrado."', (tester) async {
    final api = FakeInstructorApi();
    await pumpTela(tester, api);

    expect(find.text('Nenhum aluno encontrado.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('erro mostra a mensagem do backend e tenta de novo', (
    tester,
  ) async {
    var falhar = true;
    final api = FakeInstructorApi();
    api.onStudents = (_, _) async {
      if (falhar) throw ApiException(503, 'Servidor indisponível no momento.');
      return const StudentsPage(content: [_ana]);
    };
    await pumpTela(tester, api);

    expect(find.text('Servidor indisponível no momento.'), findsOneWidget);
    expect(find.text('Ana Beatriz Souza'), findsNothing);

    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
    expect(find.text('Servidor indisponível no momento.'), findsNothing);
    expect(api.studentCalls, hasLength(2));
  });

  testWidgets('exceção técnica nunca aparece crua pro usuário', (tester) async {
    final api = FakeInstructorApi()
      ..onStudents = (_, _) async => throw const FormatException('<html>');
    await pumpTela(tester, api);

    expect(find.text('Não foi possível carregar os alunos.'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('<html>'), findsNothing);
  });

  testWidgets('busca só vai à rede depois do debounce, com o termo digitado', (
    tester,
  ) async {
    final api = FakeInstructorApi();
    api.onStudents = (q, _) async => StudentsPage(
      content: (q ?? '').isEmpty ? const [_ana, _bruno] : const [_bruno],
    );
    await pumpTela(tester, api);
    expect(api.studentCalls, hasLength(1));

    await tester.enterText(find.byType(TextField), 'bru');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'bruno');
    await tester.pump(const Duration(milliseconds: 200));
    // Ainda dentro do debounce: nenhuma chamada nova.
    expect(api.studentCalls, hasLength(1));

    await esperarBusca(tester);

    // Uma única busca, já com o termo final.
    expect(api.studentCalls, [(q: '', page: 0), (q: 'bruno', page: 0)]);
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('Ana Beatriz Souza'), findsNothing);
  });

  testWidgets('busca sem resultado mostra o vazio com dica do termo', (
    tester,
  ) async {
    final api = FakeInstructorApi();
    api.onStudents = (q, _) async =>
        StudentsPage(content: (q ?? '').isEmpty ? const [_ana] : const []);
    await pumpTela(tester, api);

    await tester.enterText(find.byType(TextField), 'zzz');
    await esperarBusca(tester);

    expect(find.text('Nenhum aluno encontrado.'), findsOneWidget);
    expect(find.text('Confira o nome ou o CPF digitado.'), findsOneWidget);

    // Limpar a busca volta pra lista completa.
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
    expect(api.studentCalls.last, (q: '', page: 0));
  });

  testWidgets('"Carregar mais" busca a próxima página e acrescenta à lista', (
    tester,
  ) async {
    final api = FakeInstructorApi();
    api.onStudents = (_, page) async => page == 0
        ? const StudentsPage(content: [_ana], totalPages: 2, last: false)
        : const StudentsPage(
            // _ana repetida: não pode duplicar na tela.
            content: [_ana, _bruno],
            totalPages: 2,
            number: 1,
          );
    await pumpTela(tester, api);

    expect(find.text('Bruno Lima'), findsNothing);
    await tester.tap(find.text('Carregar mais'));
    await tester.pump();
    await tester.pump();

    expect(api.studentCalls, [(q: '', page: 0), (q: '', page: 1)]);
    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsOneWidget);
    // Última página: o botão some.
    expect(find.text('Carregar mais'), findsNothing);
  });

  testWidgets('falha ao paginar mantém a lista e avisa em SnackBar', (
    tester,
  ) async {
    final api = FakeInstructorApi();
    api.onStudents = (_, page) async {
      if (page > 0) throw ApiException(0, 'Não foi possível conectar.');
      return const StudentsPage(content: [_ana], totalPages: 2, last: false);
    };
    await pumpTela(tester, api);

    await tester.tap(find.text('Carregar mais'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Não foi possível conectar.'), findsOneWidget);
    expect(find.text('Ana Beatriz Souza'), findsOneWidget);
    expect(find.text('Carregar mais'), findsOneWidget);
  });

  testWidgets('toque no aluno abre as fichas dele, levando o nome', (
    tester,
  ) async {
    final api = FakeInstructorApi()..alunos = const [_ana];
    final router = GoRouter(
      initialLocation: '/instrutor/alunos',
      routes: [
        GoRoute(
          path: '/instrutor/alunos',
          builder: (_, _) => const AlunosInstrutorScreen(),
        ),
        GoRoute(
          path: '/instrutor/aluno/:id',
          builder: (_, state) => Scaffold(
            body: Text('fichas ${state.pathParameters['id']} ${state.extra}'),
          ),
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

    await tester.tap(find.text('Ana Beatriz Souza'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('fichas a1 Ana Beatriz Souza'), findsOneWidget);
  });

  testWidgets('cabe num celular de 360 px sem estourar o layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FakeInstructorApi()
      ..alunos = const [
        StudentSummary(
          id: 'x',
          fullName: 'Maria Aparecida Gonçalves de Oliveira Albuquerque',
          studentType: 'Civil',
          departmentName: 'Secretaria de Estado da Administração de Goiás',
          situacao: 'BLOQUEADO',
        ),
      ];
    await pumpTela(tester, api);

    expect(find.text('Bloqueado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('em tela larga (web) o conteúdo tem largura máxima', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FakeInstructorApi()..alunos = const [_ana];
    await pumpTela(tester, api);

    expect(tester.getSize(find.byType(Card)).width, lessThanOrEqualTo(720));
  });
}
