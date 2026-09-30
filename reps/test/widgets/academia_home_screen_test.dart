// Widget tests do hub "Academia" — os cards de acesso rápido dependem dos
// papéis do usuário logado (aluno, instrutor, os dois ou nenhum). Os rótulos
// de aluno são os mesmos consumidos por
// integration_test/secami_login_test.dart (find.text) — não mudar.
// Sem rede: secamiCurrentUserProvider é substituído via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/features/academy/presentation/academia_home_screen.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';

SecamiUser _user(List<String> roles) => SecamiUser(
  id: 'u1',
  samAccountName: 'fulano',
  nome: 'Fulano de Tal',
  email: 'fulano@goias.gov.br',
  roles: roles,
);

void main() {
  Future<void> pumpHub(WidgetTester tester, List<String> roles) async {
    // Viewport alto: a grade é preguiçosa e, no 800x600 padrão de teste, a
    // 3ª linha de cards (instrutor que também é aluno) ficaria sem construir.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secamiCurrentUserProvider.overrideWith((ref) => _user(roles)),
        ],
        child: const MaterialApp(home: AcademiaHomeScreen()),
      ),
    );
    await tester.pump();
    // Entrada animada dos cards (AppTheme.motionSlow = 320 ms).
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Rótulos dos cards, na ordem em que aparecem na grade.
  List<String> rotulos(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: find.byType(GridView), matching: find.byType(Text)),
      )
      .map((t) => t.data!)
      .toList();

  testWidgets('aluno vê os 4 cards de aluno, como antes', (tester) async {
    await pumpHub(tester, ['aluno']);

    expect(find.text('Academia'), findsOneWidget); // título da AppBar
    expect(rotulos(tester), [
      'Minha Agenda',
      'Meu Treino',
      'Avisos',
      'Meu Perfil',
    ]);
    expect(find.text('Alunos e Fichas'), findsNothing);
  });

  testWidgets('instrutor (papel professor) vê "Alunos e Fichas" e Avisos', (
    tester,
  ) async {
    await pumpHub(tester, ['professor']);

    expect(rotulos(tester), ['Alunos e Fichas', 'Avisos']);
    // Nada do que depende de cadastro de aluno.
    expect(find.text('Minha Agenda'), findsNothing);
    expect(find.text('Meu Treino'), findsNothing);
    expect(find.text('Meu Perfil'), findsNothing);
    // O termo da interface é "Instrutor", nunca "professor".
    expect(find.textContaining('rofessor'), findsNothing);
  });

  testWidgets('instrutor que também é aluno vê o card do instrutor primeiro', (
    tester,
  ) async {
    await pumpHub(tester, ['aluno', 'professor']);

    expect(rotulos(tester), [
      'Alunos e Fichas',
      'Minha Agenda',
      'Meu Treino',
      'Avisos',
      'Meu Perfil',
    ]);
  });

  testWidgets('sem papel de aluno nem de instrutor (admin) vê só Avisos', (
    tester,
  ) async {
    await pumpHub(tester, ['admin', 'recepcao']);

    expect(rotulos(tester), ['Avisos']);
  });

  testWidgets('mostra progresso enquanto a sessão ainda não resolveu', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secamiCurrentUserProvider.overrideWith(
            (ref) => Completer<SecamiUser?>().future,
          ),
        ],
        child: const MaterialApp(home: AcademiaHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Avisos'), findsNothing);
  });

  testWidgets('toque em "Alunos e Fichas" abre /instrutor/alunos', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/academia',
      routes: [
        GoRoute(
          path: '/academia',
          builder: (_, _) => const AcademiaHomeScreen(),
        ),
        GoRoute(
          path: '/instrutor/alunos',
          builder: (_, _) => const Scaffold(body: Text('tela de alunos')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secamiCurrentUserProvider.overrideWith((ref) => _user(['professor'])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Alunos e Fichas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('tela de alunos'), findsOneWidget);
  });

  test('academiaHubItems: rotas por papel', () {
    List<String> rotas(List<String> roles) =>
        academiaHubItems(_user(roles)).map((i) => i.$1).toList();

    expect(rotas(['professor']), ['/instrutor/alunos', '/academia/avisos']);
    expect(rotas(['aluno']), [
      '/academia/agenda',
      '/academia/treino',
      '/academia/avisos',
      '/academia/perfil',
    ]);
    expect(academiaHubItems(null).map((i) => i.$1), ['/academia/avisos']);
  });
}
