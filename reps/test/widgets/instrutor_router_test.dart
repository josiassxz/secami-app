// Fluxo do instrutor pelo GoRouter REAL do app (routerProvider) no modo
// SECAMI: tela de entrada, rotas /instrutor/* registradas fora do shell e
// bloqueio das telas de aluno. Sem rede: sessão e API via ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/router/app_router.dart';
import 'package:reps/core/sync/sync_providers.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/academy_providers.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';
import 'package:reps/features/instructor/data/instructor_api.dart';

import '../support/fake_instructor_api.dart';

void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
  );

  /// Sobe o app com o router de verdade, logado como um usuário com [roles].
  Future<GoRouter> pumpApp(
    WidgetTester tester,
    FakeInstructorApi api,
    List<String> roles,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secamiCurrentUserProvider.overrideWith(
            (ref) => SecamiUser(
              id: 'u1',
              samAccountName: 'instrutor',
              nome: 'Instrutor Teste',
              email: 'instrutor@goias.gov.br',
              roles: roles,
            ),
          ),
          instructorApiProvider.overrideWithValue(api),
          syncStatusProvider.overrideWith((ref) => const Stream.empty()),
          noticesProvider.overrideWith((ref) => const <NoticeDto>[]),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await assentar(tester);
    return router;
  }

  /// Rota no topo da pilha — inclusive as abertas com `context.push`, que
  /// não mudam a `uri` da configuração base.
  String rotaAtual(GoRouter router) {
    final config = router.routerDelegate.currentConfiguration;
    final topo = config.last;
    final matches = topo is ImperativeRouteMatch ? topo.matches : config;
    return matches.uri.toString();
  }

  testWidgets('só instrutor: entra pela Academia e chega ao editor de ficha', (
    tester,
  ) async {
    final api = FakeInstructorApi()
      ..alunos = const [
        StudentSummary(
          id: 'a1',
          fullName: 'Ana Beatriz Souza',
          departmentName: 'SEDUC',
        ),
      ];
    final router = await pumpApp(tester, api, ['professor']);

    // "/" → tela de entrada do instrutor: hub da Academia, dentro do shell.
    expect(rotaAtual(router), '/academia');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Alunos e Fichas'), findsOneWidget);
    expect(find.text('Minha Agenda'), findsNothing);

    // Lista de alunos: tela cheia, sem a bottom nav por cima.
    await tester.tap(find.text('Alunos e Fichas'));
    await assentar(tester);
    expect(rotaAtual(router), '/instrutor/alunos');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Ana Beatriz Souza'), findsOneWidget);

    // Fichas do aluno.
    await tester.tap(find.text('Ana Beatriz Souza'));
    await assentar(tester);
    expect(rotaAtual(router), '/instrutor/aluno/a1');
    expect(find.text('Nenhuma ficha cadastrada.'), findsOneWidget);

    // Editor de ficha nova.
    await tester.tap(find.text('Nova ficha'));
    await assentar(tester);
    expect(rotaAtual(router), '/instrutor/aluno/a1/ficha');
    expect(find.text('Salvar ficha'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('só instrutor é barrado nas telas de aluno', (tester) async {
    final router = await pumpApp(tester, FakeInstructorApi(), ['professor']);

    for (final rota in [
      '/academia/agenda',
      '/academia/treino',
      '/academia/perfil',
      '/coach/treinador',
    ]) {
      router.go(rota);
      await assentar(tester);
      expect(rotaAtual(router), '/academia', reason: rota);
      expect(find.text('Alunos e Fichas'), findsOneWidget, reason: rota);
    }

    // Avisos é de todos os papéis.
    router.go('/academia/avisos');
    await assentar(tester);
    expect(rotaAtual(router), '/academia/avisos');
    expect(find.text('Nenhum aviso no momento.'), findsOneWidget);
  });

  testWidgets('quem não é instrutor não abre /instrutor/* (volta pro hub)', (
    tester,
  ) async {
    // Papel sem tela própria no app: o hub mostra só Avisos.
    final router = await pumpApp(tester, FakeInstructorApi(), ['recepcao']);

    for (final rota in [
      '/instrutor/alunos',
      '/instrutor/aluno/a1',
      '/instrutor/aluno/a1/ficha',
    ]) {
      router.go(rota);
      await assentar(tester);
      expect(rotaAtual(router), '/academia', reason: rota);
    }
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Alunos e Fichas'), findsNothing);
  });
}

/// Deixa o redirect assíncrono e as transições de rota terminarem sem
/// depender de pumpAndSettle (as telas têm spinners).
Future<void> assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}
