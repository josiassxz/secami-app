// Stage-07 5.3 — integration test do caminho feliz.
//
// NÃO roda no CI atual: precisa de device/emulador. Executar com:
//   flutter test integration_test/app_test.dart -d <device>
// ou via driver:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d <device>
//
// Escopo (smoke): o app sobe em modo convidado sem crash e renderiza a
// navegação principal. Pontos de expansão (TODO) marcados abaixo conforme o
// fluxo de treino ganhar `ValueKey`s estáveis nos widgets-alvo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reps/app.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app sobe em modo convidado e renderiza a navegação', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RepsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sobe sem crash (Supabase em off-mode quando sem .env; local-first).
    expect(find.byType(MaterialApp), findsOneWidget);

    // TODO(stage-07): estender o caminho feliz quando os widgets do fluxo
    // tiverem ValueKey: criar rotina -> iniciar treino -> confirmar série ->
    // finalizar, assertando a persistência via providers.
  });
}
