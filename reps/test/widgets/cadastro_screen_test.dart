// Widget tests do fluxo de auto-cadastro publico de aluno (`/cadastro`).
// Cobre: render do passo 1, bloqueio de avanco com formulario vazio e o
// fallback de navegacao do botao "Cancelar" quando nao ha rota anterior na
// pilha. Sem rede real: CadastroService e substituido por um fake minimo via
// ProviderScope (mesmo padrao de test/widgets/ldap_sign_in_screen_test.dart).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/features/auth/data/cadastro_service.dart';
import 'package:reps/features/auth/domain/cadastro_models.dart';
import 'package:reps/features/auth/domain/departamento.dart';
import 'package:reps/features/auth/presentation/cadastro_screen.dart';

/// Fake minimo: so os dois metodos publicos de [CadastroService] precisam de
/// comportamento customizado para estes testes (nenhum deles chega a
/// disparar o envio real).
class _FakeCadastroService implements CadastroService {
  _FakeCadastroService({this.departamentosResult = const []});

  final List<Departamento> departamentosResult;

  @override
  Future<List<Departamento>> departamentos() async => departamentosResult;

  @override
  Future<void> enviar(CadastroRequest request, PlatformFile atestado) async {}
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) {
    final router = GoRouter(
      initialLocation: '/cadastro',
      routes: [
        GoRoute(path: '/cadastro', builder: (_, _) => const CadastroScreen()),
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const Scaffold(body: Text('TELA DE LOGIN')),
        ),
      ],
    );
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('renderiza o passo 1 com os campos de dados pessoais', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: [
        cadastroServiceProvider.overrideWithValue(_FakeCadastroService()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Cadastro de aluno'), findsOneWidget);
    expect(find.text('PASSO 1 DE 4'), findsOneWidget);
    expect(find.text('NOME COMPLETO'), findsOneWidget);
    expect(find.text('CPF'), findsOneWidget);
    expect(find.text('SECRETARIA / ÓRGÃO'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('bloqueia avanco do passo 1 com formulario vazio', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: [
        cadastroServiceProvider.overrideWithValue(_FakeCadastroService()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    // Continua no passo 1 (nao avancou pro questionario PAR-Q).
    expect(find.text('Confira os campos destacados.'), findsOneWidget);
    expect(find.text('PASSO 1 DE 4'), findsOneWidget);
  });

  testWidgets('carrega e exibe as secretarias/orgaos no combo', (tester) async {
    await pumpScreen(
      tester,
      overrides: [
        cadastroServiceProvider.overrideWithValue(
          _FakeCadastroService(
            departamentosResult: const [
              Departamento(
                id: 'dep-1',
                name: 'Secretaria de Teste',
                sigla: 'SEC',
                andar: '2',
                active: true,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('SEC — Secretaria de Teste'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('SEC — Secretaria de Teste'), findsOneWidget);
  });

  testWidgets(
    'botao cancelar no passo 1 volta ao login quando nao ha rota anterior',
    (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          cadastroServiceProvider.overrideWithValue(_FakeCadastroService()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('TELA DE LOGIN'), findsOneWidget);
    },
  );
}
