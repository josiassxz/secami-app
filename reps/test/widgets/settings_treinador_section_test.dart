// Widget tests da seção "Treinador" dos Ajustes — no modo SECAMI os atalhos
// dependem do papel (aluno / instrutor); no modo legado (Supabase) a seção
// continua igual. Sem rede: sessão e preferências via ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/sync/sync_providers.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';
import 'package:reps/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

SecamiUser _secami(List<String> roles) => SecamiUser(
  id: 'u1',
  samAccountName: 'fulano',
  nome: 'Fulano de Tal',
  email: 'fulano@goias.gov.br',
  roles: roles,
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A lista de Ajustes é longa e preguiçosa: viewport alto pra seção
  /// "Treinador" ser construída sem precisar rolar.
  void viewportAlto(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpAjustes(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    viewportAlto(tester);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncStatusProvider.overrideWith((ref) => const Stream.empty()),
          ...overrides,
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('modo SECAMI (backend REST)', () {
    setUp(
      () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
    );

    Future<void> pumpComPapeis(WidgetTester tester, List<String> roles) =>
        pumpAjustes(
          tester,
          overrides: [
            secamiCurrentUserProvider.overrideWith((ref) => _secami(roles)),
          ],
        );

    testWidgets('instrutor vê só "Alunos e fichas de treino"', (tester) async {
      await pumpComPapeis(tester, ['professor']);

      expect(find.text('TREINADOR'), findsOneWidget);
      expect(find.text('Alunos e fichas de treino'), findsOneWidget);
      expect(
        find.text('Prescreva fichas para os alunos da academia'),
        findsOneWidget,
      );
      expect(find.text('Meu treinador'), findsNothing);
      expect(find.text('Meus alunos'), findsNothing);
      expect(find.text('Minha academia'), findsNothing);
      // O termo da interface é "Instrutor", nunca "professor".
      expect(find.textContaining('rofessor'), findsNothing);
    });

    testWidgets('o atalho do instrutor abre /instrutor/alunos', (tester) async {
      await pumpComPapeis(tester, ['professor']);

      await tester.tap(find.text('Alunos e fichas de treino'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('tela de alunos'), findsOneWidget);
    });

    testWidgets('aluno vê só "Meu treinador"', (tester) async {
      await pumpComPapeis(tester, ['aluno']);

      expect(find.text('TREINADOR'), findsOneWidget);
      expect(find.text('Meu treinador'), findsOneWidget);
      expect(find.text('Alunos e fichas de treino'), findsNothing);
      expect(find.text('Meus alunos'), findsNothing);
      expect(find.text('Minha academia'), findsNothing);
    });

    testWidgets('instrutor que também é aluno vê os dois atalhos', (
      tester,
    ) async {
      await pumpComPapeis(tester, ['aluno', 'professor']);

      expect(find.text('Meu treinador'), findsOneWidget);
      expect(find.text('Alunos e fichas de treino'), findsOneWidget);
    });

    testWidgets('sem papel de aluno nem de instrutor, a seção some inteira', (
      tester,
    ) async {
      await pumpComPapeis(tester, ['admin']);

      expect(find.text('TREINADOR'), findsNothing);
      expect(find.text('Meu treinador'), findsNothing);
      expect(find.text('Alunos e fichas de treino'), findsNothing);
      // O resto dos Ajustes continua lá.
      expect(find.text('SINCRONIZAÇÃO'), findsOneWidget);
      expect(find.text('TIMER DE DESCANSO'), findsOneWidget);
    });
  });

  group('modo legado (Supabase)', () {
    setUp(() => dotenv.testLoad());

    testWidgets('seção "Treinador" continua com os 3 atalhos de sempre', (
      tester,
    ) async {
      await pumpAjustes(
        tester,
        overrides: [
          currentUserProvider.overrideWithValue(
            const User(
              id: 'u1',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              email: 'fulano@exemplo.com',
              createdAt: '2026-01-01T00:00:00Z',
            ),
          ),
        ],
      );

      expect(find.text('TREINADOR'), findsOneWidget);
      final y = [
        for (final titulo in ['Meus alunos', 'Meu treinador', 'Minha academia'])
          tester.getTopLeft(find.text(titulo)).dy,
      ];
      // Mesma ordem de antes.
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
      expect(find.text('Alunos e fichas de treino'), findsNothing);
    });
  });
}
