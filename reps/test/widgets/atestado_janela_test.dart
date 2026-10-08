// Widget tests da janela do atestado médico ao entrar no app (SECAMI): as
// variantes (perto de vencer, vencido/bloqueado, em análise, recusado), quando
// NÃO aparece, falha de rede sem bloquear, a ordem em relação aos avisos (uma
// janela de cada vez, a do atestado antes) e uma verificação por sessão.
// Sem rede: APIs e usuário fakes.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/academy/data/avisos_api.dart';
import 'package:reps/features/academy/presentation/avisos_janela.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';

import '../support/fake_atestado_api.dart';

class _FakeAvisosApi implements AvisosApi {
  _FakeAvisosApi([this.avisos = const []]);

  final List<NoticeDto> avisos;
  int chamadas = 0;
  final dispensados = <String>[];

  @override
  Future<List<NoticeDto>> janela() async {
    chamadas++;
    return avisos;
  }

  @override
  Future<void> dispensar(String avisoId) async => dispensados.add(avisoId);
}

SecamiUser _usuario(List<String> roles) => SecamiUser(
  id: 'u1',
  samAccountName: '',
  nome: 'Aluno Teste',
  email: 'aluno@goias.gov.br',
  roles: roles,
);

const _feriado = NoticeDto(
  id: 'n1',
  title: 'Academia fechada no feriado',
  content: 'Sem expediente em 12/10.',
  type: 'warning',
);

AtestadoStatus _vencendo(int dias, {EnvioAtestado? envio}) => AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencendo,
  vencimento: DateTime(2027, 3, 30),
  diasRestantes: dias,
  base: 'ATESTADO',
  envio: envio,
);

AtestadoStatus _bloqueado({EnvioAtestado? envio}) => AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencido,
  bloqueado: true,
  vencimento: DateTime(2026, 10, 7),
  diasRestantes: -1,
  base: 'ATESTADO',
  envio: envio,
);

final _pendente = EnvioAtestado(
  id: 'e1',
  status: StatusEnvioAtestado.pendente,
  enviadoEm: DateTime(2026, 10, 8, 14),
  emissaoData: DateTime(2026, 10, 1),
);

const _recusado = EnvioAtestado(
  id: 'e0',
  status: StatusEnvioAtestado.recusado,
  motivoRecusa: 'PDF ilegível',
);

ProviderContainer _container({
  required FakeAtestadoApi atestado,
  _FakeAvisosApi? avisos,
  List<String> roles = const ['aluno'],
}) => ProviderContainer(
  overrides: [
    avisosApiProvider.overrideWithValue(avisos ?? _FakeAvisosApi()),
    atestadoApiProvider.overrideWithValue(atestado),
    secamiCurrentUserProvider.overrideWith((ref) async => _usuario(roles)),
  ],
);

/// Sobe o gate dentro de um GoRouter (como no app), com a tela de envio
/// registrada em `/academia/atestado`.
Future<GoRouter> _entrar(WidgetTester tester, ProviderContainer c) async {
  await c.read(secamiCurrentUserProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const AvisosJanelaGate(
          child: Scaffold(body: Text('conteudo do app')),
        ),
      ),
      GoRoute(
        path: '/academia/atestado',
        builder: (_, _) => const Scaffold(body: Text('tela de envio')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));

  group('variantes da janela', () {
    testWidgets('perto de vencer: dias, data, aviso do bloqueio e botões', (
      tester,
    ) async {
      final api = FakeAtestadoApi(situacao: _vencendo(12));
      final c = _container(atestado: api);
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Seu atestado está perto de vencer'), findsOneWidget);
      expect(
        find.text('Seu atestado vence em 12 dias (30/03/2027).'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Depois dessa data seu acesso à academia será bloqueado até a '
          'academia validar um novo atestado.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Enviar novo atestado'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Agora não'), findsOneWidget);
      // Sem "não mostrar novamente": volta a cada entrada.
      expect(find.text('Não mostrar novamente'), findsNothing);

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('conteudo do app'), findsOneWidget);
    });

    testWidgets('vence hoje (0 dias)', (tester) async {
      final c = _container(atestado: FakeAtestadoApi(situacao: _vencendo(0)));
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(
        find.text('Seu atestado vence hoje (30/03/2027).'),
        findsOneWidget,
      );
    });

    testWidgets('vence amanhã (1 dia)', (tester) async {
      final c = _container(atestado: FakeAtestadoApi(situacao: _vencendo(1)));
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(
        find.text('Seu atestado vence amanhã (30/03/2027).'),
        findsOneWidget,
      );
    });

    testWidgets('vencido/bloqueado: "Acesso bloqueado" com Enviar e Fechar', (
      tester,
    ) async {
      final c = _container(atestado: FakeAtestadoApi(situacao: _bloqueado()));
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Acesso bloqueado'), findsOneWidget);
      expect(
        find.text(
          'Seu atestado venceu em 07/10/2026. Envie um novo atestado para a '
          'academia validar e liberar seu acesso.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Enviar novo atestado'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Fechar'), findsOneWidget);
      expect(find.text('Agora não'), findsNothing);

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('em análise (bloqueado): informa o envio e só "Entendi"', (
      tester,
    ) async {
      final c = _container(
        atestado: FakeAtestadoApi(situacao: _bloqueado(envio: _pendente)),
      );
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Atestado em análise'), findsOneWidget);
      expect(
        find.text(
          'Seu novo atestado foi enviado em 08/10/2026 e está em análise '
          'pela academia.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Seu acesso continua bloqueado até a aprovação.'),
        findsOneWidget,
      );
      expect(find.text('Enviar novo atestado'), findsNothing);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('conteudo do app'), findsOneWidget);
    });

    testWidgets('em análise sem bloqueio não fala em acesso bloqueado', (
      tester,
    ) async {
      final c = _container(
        atestado: FakeAtestadoApi(situacao: _vencendo(5, envio: _pendente)),
      );
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Atestado em análise'), findsOneWidget);
      expect(
        find.text('Seu acesso continua bloqueado até a aprovação.'),
        findsNothing,
      );
    });

    testWidgets('recusado: mostra o motivo (perto de vencer)', (tester) async {
      final c = _container(
        atestado: FakeAtestadoApi(situacao: _vencendo(12, envio: _recusado)),
      );
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Seu atestado está perto de vencer'), findsOneWidget);
      expect(
        find.text('Seu último envio foi recusado: PDF ilegível.'),
        findsOneWidget,
      );
    });

    testWidgets('recusado: mostra o motivo (bloqueado)', (tester) async {
      final c = _container(
        atestado: FakeAtestadoApi(situacao: _bloqueado(envio: _recusado)),
      );
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(find.text('Acesso bloqueado'), findsOneWidget);
      expect(
        find.text('Seu último envio foi recusado: PDF ilegível.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Enviar novo atestado'),
        findsOneWidget,
      );
    });
  });

  group('quando não aparece', () {
    testWidgets('atestado em dia: sem janela', (tester) async {
      final api = FakeAtestadoApi(
        situacao: AtestadoStatus(
          aplicavel: true,
          vencimento: DateTime(2027, 6, 1),
          diasRestantes: 236,
        ),
      );
      final c = _container(atestado: api);
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(api.consultas, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('regra não se aplica (aplicavel: false): sem janela', (
      tester,
    ) async {
      final api = FakeAtestadoApi();
      final c = _container(atestado: api);
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(api.consultas, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('quem não é aluno nem consulta o atestado', (tester) async {
      final api = FakeAtestadoApi(situacao: _bloqueado());
      final c = _container(atestado: api, roles: const ['professor']);
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(api.consultas, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('falha ao consultar não bloqueia a entrada nem os avisos', (
      tester,
    ) async {
      final api = FakeAtestadoApi(situacao: _bloqueado(), falhaStatus: true);
      final avisos = _FakeAvisosApi([_feriado]);
      final c = _container(atestado: api, avisos: avisos);
      addTearDown(c.dispose);
      await _entrar(tester, c);

      expect(api.consultas, 1);
      expect(find.text('Acesso bloqueado'), findsNothing);
      expect(find.text('Academia fechada no feriado'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('conteudo do app'), findsOneWidget);
    });
  });

  group('junto com os avisos', () {
    testWidgets('a do atestado vem antes; depois os avisos funcionam', (
      tester,
    ) async {
      final avisos = _FakeAvisosApi([_feriado]);
      final c = _container(
        atestado: FakeAtestadoApi(situacao: _vencendo(12)),
        avisos: avisos,
      );
      addTearDown(c.dispose);
      await _entrar(tester, c);

      // Uma janela de cada vez: só a do atestado agora.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Seu atestado está perto de vencer'), findsOneWidget);
      expect(find.text('Academia fechada no feriado'), findsNothing);

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Academia fechada no feriado'), findsOneWidget);
      await tester.tap(find.text('Não mostrar novamente'));
      await tester.pump();
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(avisos.dispensados, ['n1']);
    });

    testWidgets(
      '"Enviar novo atestado" abre a tela de envio; avisos ao voltar',
      (tester) async {
        final avisos = _FakeAvisosApi([_feriado]);
        final c = _container(
          atestado: FakeAtestadoApi(situacao: _bloqueado()),
          avisos: avisos,
        );
        addTearDown(c.dispose);
        final router = await _entrar(tester, c);

        await tester.tap(find.text('Enviar novo atestado'));
        await tester.pumpAndSettle();

        expect(find.text('tela de envio'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/academia/atestado',
        );
        // Nada abre por cima do formulário de envio...
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Academia fechada no feriado'), findsNothing);

        // ...os avisos desta entrada aparecem quando o aluno volta.
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('conteudo do app'), findsOneWidget);
        expect(find.text('Academia fechada no feriado'), findsOneWidget);
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(avisos.chamadas, 1);
      },
    );
  });

  group('uma vez por entrada no app', () {
    testWidgets('trocar de tela não reabre; nova sessão reabre', (
      tester,
    ) async {
      final api = FakeAtestadoApi(situacao: _bloqueado());
      final c = _container(atestado: api);
      addTearDown(c.dispose);
      await _entrar(tester, c);
      expect(find.text('Acesso bloqueado'), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      // Recria o gate (como ao voltar de uma tela cheia pro shell).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: AvisosJanelaGate(child: Scaffold(body: Text('outra aba'))),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.consultas, 1);
      expect(find.byType(AlertDialog), findsNothing);

      // Nova sessão (sair e entrar de novo): volta a aparecer.
      await c.refresh(secamiCurrentUserProvider.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.consultas, 2);
      expect(find.text('Acesso bloqueado'), findsOneWidget);
    });
  });
}
