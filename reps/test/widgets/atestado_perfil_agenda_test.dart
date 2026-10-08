// Widget tests do atestado médico nas telas do aluno: cartão "Atestado
// médico" no Meu Perfil (vencimento, situação e atalho pro envio) e a faixa
// de acesso bloqueado no topo da Minha Agenda. Sem rede: providers de dados
// substituídos via ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reps/features/academy/data/academy_providers.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/academy/presentation/meu_perfil_screen.dart';
import 'package:reps/features/academy/presentation/minha_agenda_screen.dart';

const _perfilCivil = <String, dynamic>{
  'fullName': 'Ana Beatriz Souza',
  'cpf': '123.456.789-09',
  'studentType': 'Civil',
  'atestadoValido': true,
};

final _emDia = AtestadoStatus(
  aplicavel: true,
  vencimento: DateTime(2027, 6, 1),
  diasRestantes: 236,
  base: 'CADASTRO',
);

final _vencendo = AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencendo,
  vencimento: DateTime(2026, 10, 20),
  diasRestantes: 12,
);

final _bloqueado = AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencido,
  bloqueado: true,
  vencimento: DateTime(2026, 10, 7),
  diasRestantes: -1,
);

/// Sobe [tela] em `/tela` com a tela de envio registrada em
/// `/academia/atestado`.
Future<void> _pump(
  WidgetTester tester,
  Widget tela,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/tela',
    routes: [
      GoRoute(path: '/tela', builder: (_, _) => tela),
      GoRoute(
        path: '/academia/atestado',
        builder: (_, _) => const Scaffold(body: Text('tela de envio')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Meu Perfil — cartão do atestado', () {
    List<Override> overrides(Future<AtestadoStatus> Function() atestado) => [
      myProfileProvider.overrideWith((ref) async => _perfilCivil),
      atestadoStatusProvider.overrideWith((ref) => atestado()),
    ];

    testWidgets('mostra vencimento, situação e o botão de envio', (
      tester,
    ) async {
      await _pump(
        tester,
        const MeuPerfilScreen(),
        overrides(() async => _vencendo),
      );

      expect(find.text('Atestado médico'), findsOneWidget);
      expect(find.text('Vencimento: 20/10/2026'), findsOneWidget);
      expect(find.text('Situação: Vence em 12 dias'), findsOneWidget);
      // O resumo antigo do perfil não aparece junto.
      expect(find.text('Atestado médico válido'), findsNothing);

      await tester.tap(find.text('Enviar novo atestado'));
      await tester.pumpAndSettle();
      expect(find.text('tela de envio'), findsOneWidget);
    });

    testWidgets('em dia: situação "Em dia" e base do cadastro', (tester) async {
      await _pump(
        tester,
        const MeuPerfilScreen(),
        overrides(() async => _emDia),
      );

      expect(find.text('Vencimento: 01/06/2027'), findsOneWidget);
      expect(find.text('Situação: Em dia'), findsOneWidget);
      expect(
        find.text('Validade contada a partir do seu cadastro.'),
        findsOneWidget,
      );
      expect(find.text('Enviar novo atestado'), findsOneWidget);
    });

    testWidgets('regra não se aplica: sem cartão de atestado', (tester) async {
      await _pump(
        tester,
        const MeuPerfilScreen(),
        overrides(() async => AtestadoStatus.naoAplicavel),
      );

      expect(find.text('Ana Beatriz Souza'), findsOneWidget);
      expect(find.text('Atestado médico'), findsNothing);
      expect(find.text('Enviar novo atestado'), findsNothing);
      expect(find.text('Atestado médico válido'), findsNothing);
    });

    testWidgets('falha ao consultar: volta ao resumo antigo do perfil', (
      tester,
    ) async {
      await _pump(
        tester,
        const MeuPerfilScreen(),
        overrides(() => Future.error(Exception('rede'))),
      );

      expect(find.text('Atestado médico válido'), findsOneWidget);
      expect(find.text('Enviar novo atestado'), findsNothing);
    });
  });

  group('Minha Agenda — faixa de acesso bloqueado', () {
    List<Override> overrides(AtestadoStatus atestado) => [
      availableSlotsProvider.overrideWith((ref) async => const []),
      myAppointmentsProvider.overrideWith((ref) async => const []),
      atestadoStatusProvider.overrideWith((ref) async => atestado),
    ];

    testWidgets('bloqueado: faixa no topo com o botão de envio', (
      tester,
    ) async {
      await _pump(tester, const MinhaAgendaScreen(), overrides(_bloqueado));

      final faixa = find.text('Seu acesso está bloqueado: atestado vencido.');
      expect(faixa, findsOneWidget);
      // No topo: acima do seletor de data.
      expect(
        tester.getTopLeft(faixa).dy,
        lessThan(
          tester.getTopLeft(find.text('Toque para escolher outra data')).dy,
        ),
      );

      await tester.tap(find.text('Enviar novo atestado'));
      await tester.pumpAndSettle();
      expect(find.text('tela de envio'), findsOneWidget);
    });

    testWidgets('bloqueado com envio em análise: informa e leva ao envio', (
      tester,
    ) async {
      final emAnalise = AtestadoStatus(
        aplicavel: true,
        situacao: SituacaoAtestado.vencido,
        bloqueado: true,
        vencimento: DateTime(2026, 10, 7),
        envio: EnvioAtestado(
          id: 'e1',
          status: StatusEnvioAtestado.pendente,
          enviadoEm: DateTime(2026, 10, 8, 14),
        ),
      );
      await _pump(tester, const MinhaAgendaScreen(), overrides(emAnalise));

      expect(
        find.text('Seu acesso está bloqueado: atestado vencido.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Seu novo atestado foi enviado em 08/10/2026 e está em análise '
          'pela academia.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ver atestado em análise'), findsOneWidget);
    });

    testWidgets('sem bloqueio (mesmo perto de vencer): sem faixa', (
      tester,
    ) async {
      await _pump(tester, const MinhaAgendaScreen(), overrides(_vencendo));

      expect(
        find.text('Seu acesso está bloqueado: atestado vencido.'),
        findsNothing,
      );
      expect(find.text('Nenhum agendamento ativo.'), findsOneWidget);
    });

    testWidgets('falha ao consultar o atestado: agenda normal, sem faixa', (
      tester,
    ) async {
      await _pump(tester, const MinhaAgendaScreen(), [
        availableSlotsProvider.overrideWith((ref) async => const []),
        myAppointmentsProvider.overrideWith((ref) async => const []),
        atestadoStatusProvider.overrideWith(
          (ref) => Future<AtestadoStatus>.error(Exception('rede')),
        ),
      ]);

      expect(
        find.text('Seu acesso está bloqueado: atestado vencido.'),
        findsNothing,
      );
      expect(find.text('Nenhum agendamento ativo.'), findsOneWidget);
    });
  });
}
