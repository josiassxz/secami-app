// Migração E9 — verifica o ciclo de sync offline-first (Drift local -> REST
// SECAMI) disparado por uma ação real do usuário, contra um backend REAL
// rodando em localhost:8080. NÃO roda no CI (precisa do backend no ar e de
// um simulador/device). Executar com:
//   flutter test integration_test/secami_sync_test.dart -d <device-id>
//
// Cria uma rotina pela UI (escreve no Drift local, marca dirty) e espera o
// debounce do auto-sync (3s, ver SyncEngine.startAutoSync) + o push real via
// RestSyncTransport. Depois do teste, confirma no Postgres (fora deste
// arquivo, via psql) que a rotina chegou ao backend com o nome usado aqui —
// prova que o motor de sync (876 linhas, só trocou de transporte) funciona
// de ponta a ponta com o transporte REST novo, não só via curl direto.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reps/app.dart';
import 'package:reps/core/config/env.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settleTimeout = Duration(seconds: 10);

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  _settleTimeout,
);

/// Nome único por execução — sem Math.random()/DateTime.now() como fonte de
/// aleatoriedade "de verdade", só como sufixo legível pra distinguir de
/// rotinas de execuções anteriores ao conferir no Postgres depois.
final String _nomeRotina = 'Teste Sync E2E ${DateTime.now().millisecondsSinceEpoch}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('criar rotina localmente sincroniza com o backend REST real', (
    tester,
  ) async {
    await Env.load();
    expect(
      Env.hasRestApi,
      isTrue,
      reason: 'Configure API_BASE_URL no .env antes de rodar este teste.',
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RepsApp(),
      ),
    );
    await _settle(tester);

    // Login LDAP (mesmo usuário dev das outras suítes).
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'aluno');
    await tester.enterText(fields.at(1), 'secami123');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ENTRAR'));
    await _settle(tester);

    // Pós-login cai em /routines (Treinos) — a tela padrão do app.
    // findsWidgets: "Treinos" aparece no header da tela E no rótulo da aba.
    expect(find.text('Treinos'), findsWidgets);

    // Abre o bottom sheet de nova rotina.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'NOVA ROTINA'));
    await _settle(tester);
    expect(find.text('Nova rotina'), findsOneWidget);

    // Preenche o nome e cria (o service grava no Drift local e marca dirty
    // ANTES de navegar — é esse INSERT local que dispara o auto-sync).
    await tester.enterText(find.byType(TextField).first, _nomeRotina);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'CRIAR E ESCOLHER EXERCÍCIOS'));
    await _settle(tester);

    // Espera real (LiveTestWidgetsFlutterBinding = clock real) além do
    // debounce de 3s do auto-sync, dando folga pro round-trip de rede real
    // (push da rotina pro backend via RestSyncTransport).
    await tester.pump(const Duration(seconds: 8));
    await _settle(tester);
  });
}
