// Widget tests da tela de login LDAP (aluno/professor) — cobre render dos
// campos, validação de formulário vazio e exibição de erro quando o backend
// rejeita as credenciais. Sem rede real: RestAuthService é substituído por
// um fake mínimo via ProviderScope (mais simples/robusto que mockar a rede).

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';
import 'package:reps/features/auth/presentation/ldap_sign_in_screen.dart';

/// Fake mínimo: só `login` tem comportamento customizado (falha). Os demais
/// métodos não são exercitados pelo fluxo de erro testado aqui.
class _FailingRestAuthService implements RestAuthService {
  @override
  Future<SecamiUser> login(String username, String password) =>
      Future<SecamiUser>.error(Exception('usuário ou senha inválidos'));

  @override
  Future<SecamiUser> me() => throw UnimplementedError();

  @override
  Future<SecamiUser?> currentUserOrNull() async => null;

  @override
  Future<void> logout() async {}
}

void main() {
  // _submit() sempre chama Observability.captureError (erro) ou .track
  // (sucesso), que leem Env → dotenv. Sem init, dotenv.get() lança
  // NotInitializedError mesmo com fallback vazio (mesmo padrão usado em
  // test/workout_controller_test.dart).
  setUpAll(() {
    dotenv.testLoad();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: LdapSignInScreen()),
      ),
    );
  }

  testWidgets('renderiza campos de usuário/senha e botão ENTRAR', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Academia SECAMI'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'ENTRAR'), findsOneWidget);
  });

  testWidgets('mostra erros de validação ao enviar formulário vazio', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    // Nota: o botão ENTRAR não tem lógica de habilitar/desabilitar conforme
    // preenchimento dos campos (só desabilita durante o loading da
    // requisição) — a validação acontece ao submeter, via Form.validate().
    await tester.tap(find.widgetWithText(FilledButton, 'ENTRAR'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o usuário'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
  });

  testWidgets('mostra banner de erro quando o login falha', (tester) async {
    await pumpScreen(
      tester,
      overrides: [
        restAuthServiceProvider.overrideWithValue(_FailingRestAuthService()),
      ],
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'aluno');
    await tester.enterText(fields.at(1), 'secami123');
    await tester.tap(find.widgetWithText(FilledButton, 'ENTRAR'));
    await tester.pumpAndSettle();

    expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
    // Sem navegação em caso de erro: o formulário continua na tela.
    expect(find.text('ENTRAR'), findsOneWidget);
  });
}
