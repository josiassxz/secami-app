// Widget tests da tela de envio de atestado médico (`/academia/atestado`):
// cartão de situação, validação do formulário (PDF obrigatório, limite de
// 10MB), envio com progresso e sem duplo envio, estado de sucesso, mensagens
// do servidor (409/422), envio já em análise no lugar do formulário e
// layout em 360 px e em tela larga. Sem rede: API e seletor de PDF fakes.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/academy/presentation/atestado_screen.dart';

import '../support/fake_atestado_api.dart';

final _vencendo = AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencendo,
  vencimento: DateTime(2027, 3, 30),
  diasRestantes: 12,
  base: 'ATESTADO',
);

final _bloqueadoEmAnalise = AtestadoStatus(
  aplicavel: true,
  situacao: SituacaoAtestado.vencido,
  bloqueado: true,
  vencimento: DateTime(2026, 10, 7),
  diasRestantes: -1,
  envio: EnvioAtestado(
    id: 'e1',
    status: StatusEnvioAtestado.pendente,
    enviadoEm: DateTime(2026, 10, 8, 14),
  ),
);

ArquivoPdf _pdf({String nome = 'atestado.pdf', int bytes = 2048}) =>
    ArquivoPdf(nome: nome, bytes: Uint8List(bytes));

final _botaoEnviar = find.widgetWithText(FilledButton, 'Enviar atestado');

void main() {
  late FakeAtestadoApi api;
  late ArquivoPdf? Function() proximoPdf;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
    api = FakeAtestadoApi(situacao: _vencendo);
    proximoPdf = _pdf;
  });

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<GoRouter> pumpTela(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/academia/atestado',
      routes: [
        GoRoute(
          path: '/academia',
          builder: (_, _) => const Scaffold(body: Text('HUB')),
        ),
        GoRoute(
          path: '/academia/atestado',
          builder: (_, _) => const AtestadoScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          atestadoApiProvider.overrideWithValue(api),
          selecionarPdfProvider.overrideWithValue(() async => proximoPdf()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> escolherData(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('atestado-data-emissao')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> escolherUf(WidgetTester tester, String uf) async {
    await tester.tap(find.byKey(const ValueKey('atestado-medico-uf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(uf).last);
    await tester.pumpAndSettle();
  }

  Future<void> escolherPdf(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Selecionar arquivo PDF'));
    await tester.tap(find.text('Selecionar arquivo PDF'));
    await tester.pumpAndSettle();
  }

  Future<void> tocarEnviar(WidgetTester tester) async {
    await tester.ensureVisible(_botaoEnviar);
    await tester.tap(_botaoEnviar);
    await tester.pump();
  }

  /// Preenche tudo, menos o que for pedido pra deixar de fora.
  Future<void> preencher(WidgetTester tester, {bool comPdf = true}) async {
    await escolherData(tester);
    await tester.enterText(
      find.byKey(const ValueKey('atestado-medico-nome')),
      'Dra. Maria Souza',
    );
    await tester.enterText(
      find.byKey(const ValueKey('atestado-medico-crm')),
      '12345',
    );
    await escolherUf(tester, 'GO');
    if (comPdf) await escolherPdf(tester);
  }

  testWidgets('mostra a situação atual e o formulário', (tester) async {
    viewport(tester, const Size(800, 1400));
    await pumpTela(tester);

    expect(find.text('Atestado médico'), findsWidgets);
    expect(find.text('Vencimento: 30/03/2027'), findsOneWidget);
    expect(find.text('Situação: Vence em 12 dias'), findsOneWidget);
    expect(find.text('DATA DE EMISSÃO'), findsOneWidget);
    expect(find.text('NOME DO MÉDICO'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('UF'), findsWidgets);
    expect(find.text('Selecionar arquivo PDF'), findsOneWidget);
    expect(_botaoEnviar, findsOneWidget);
  });

  testWidgets('formulário vazio: aponta todos os campos e não envia', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    await pumpTela(tester);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Informe a data de emissão do atestado.'), findsOneWidget);
    expect(find.text('Informe o nome do médico'), findsOneWidget);
    expect(find.text('Informe o CRM'), findsOneWidget);
    expect(find.text('Selecione'), findsOneWidget);
    expect(find.text('Anexe o atestado médico em PDF.'), findsOneWidget);
    expect(api.envios, isEmpty);
  });

  testWidgets('PDF é obrigatório', (tester) async {
    viewport(tester, const Size(800, 1400));
    await pumpTela(tester);
    await preencher(tester, comPdf: false);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Anexe o atestado médico em PDF.'), findsOneWidget);
    expect(find.text('Informe o nome do médico'), findsNothing);
    expect(api.envios, isEmpty);
  });

  testWidgets('PDF acima de 10MB é recusado com mensagem amigável', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    proximoPdf = () => _pdf(bytes: maxAtestadoBytes + 1);
    await pumpTela(tester);

    await escolherPdf(tester);

    expect(find.text('O arquivo deve ter no máximo 10MB.'), findsOneWidget);
    expect(find.text('Selecionar arquivo PDF'), findsOneWidget);
  });

  testWidgets('arquivo que não é PDF é recusado', (tester) async {
    viewport(tester, const Size(800, 1400));
    proximoPdf = () => _pdf(nome: 'foto.jpg');
    await pumpTela(tester);

    await escolherPdf(tester);

    expect(find.text('Selecione um arquivo em PDF.'), findsOneWidget);
  });

  testWidgets('envia, mostra o sucesso e recarrega a situação', (tester) async {
    viewport(tester, const Size(800, 1400));
    final router = await pumpTela(tester);
    expect(api.consultas, 1);

    await preencher(tester);
    expect(find.text('atestado.pdf'), findsOneWidget);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(api.envios, hasLength(1));
    final envio = api.envios.single;
    final hoje = DateTime.now();
    expect(envio.emissaoData, DateTime(hoje.year, hoje.month, hoje.day));
    expect(envio.medicoNome, 'Dra. Maria Souza');
    expect(envio.medicoCrm, '12345');
    expect(envio.medicoCrmUf, 'GO');
    expect(envio.arquivo.nome, 'atestado.pdf');

    expect(find.text('Atestado enviado!'), findsOneWidget);
    expect(
      find.text('A academia vai validar e você será avisado aqui no app.'),
      findsOneWidget,
    );
    expect(api.consultas, 2);

    // Sem tela anterior na pilha: "Voltar" leva pro hub da Academia.
    await tester.tap(find.widgetWithText(FilledButton, 'Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/academia',
    );
  });

  testWidgets('mostra progresso durante o envio e não envia duas vezes', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    final segurar = Completer<void>();
    api.segurarEnvio = segurar;
    await pumpTela(tester);
    await preencher(tester);

    await tocarEnviar(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final botao = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(botao.onPressed, isNull);

    await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
    await tester.pump();
    expect(api.envios, hasLength(1));

    segurar.complete();
    await tester.pumpAndSettle();
    expect(find.text('Atestado enviado!'), findsOneWidget);
    expect(api.envios, hasLength(1));
  });

  testWidgets('409: mostra a mensagem do servidor e recarrega a situação', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    api.erroEnvio = ApiException(
      409,
      'Você já tem um atestado em análise. Aguarde a validação da academia.',
    );
    await pumpTela(tester);
    await preencher(tester);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Você já tem um atestado em análise. Aguarde a validação da '
        'academia.',
      ),
      findsOneWidget,
    );
    expect(find.text('Atestado enviado!'), findsNothing);
    expect(api.consultas, 2);
    // Pode tentar de novo (botão liberado).
    expect(tester.widget<FilledButton>(_botaoEnviar).onPressed, isNotNull);
  });

  testWidgets('422: mostra a mensagem da regra de negócio', (tester) async {
    viewport(tester, const Size(800, 1400));
    api.erroEnvio = ApiException(
      422,
      'A data de emissão do atestado não pode ser anterior a 1 ano.',
    );
    await pumpTela(tester);
    await preencher(tester);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('A data de emissão do atestado não pode ser anterior a 1 ano.'),
      findsOneWidget,
    );
    expect(find.text('Atestado enviado!'), findsNothing);
  });

  testWidgets('erro inesperado nunca mostra detalhe técnico', (tester) async {
    viewport(tester, const Size(800, 1400));
    api.erroEnvio = const FormatException('Unexpected character at <html>');
    await pumpTela(tester);
    await preencher(tester);

    await tocarEnviar(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível enviar o atestado agora. Tente de novo em '
        'instantes.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('envio já em análise: mostra o andamento no lugar do form', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    api.situacao = _bloqueadoEmAnalise;
    await pumpTela(tester);

    expect(find.text('Atestado em análise'), findsOneWidget);
    expect(
      find.text(
        'Seu novo atestado foi enviado em 08/10/2026 e está em análise '
        'pela academia.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Seu acesso continua bloqueado até a aprovação.'),
      findsOneWidget,
    );
    expect(find.text('Situação: Vencido — acesso bloqueado'), findsOneWidget);
    expect(_botaoEnviar, findsNothing);
    expect(find.text('NOME DO MÉDICO'), findsNothing);
  });

  testWidgets('envio recusado: mostra o motivo e libera o formulário', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    api.situacao = AtestadoStatus(
      aplicavel: true,
      situacao: SituacaoAtestado.vencido,
      bloqueado: true,
      vencimento: DateTime(2026, 10, 7),
      envio: const EnvioAtestado(
        id: 'e0',
        status: StatusEnvioAtestado.recusado,
        motivoRecusa: 'Atestado sem assinatura do médico.',
      ),
    );
    await pumpTela(tester);

    expect(
      find.text(
        'Seu último envio foi recusado: Atestado sem assinatura do médico.',
      ),
      findsOneWidget,
    );
    expect(_botaoEnviar, findsOneWidget);
  });

  testWidgets('regra não se aplica: sem formulário', (tester) async {
    api.situacao = AtestadoStatus.naoAplicavel;
    await pumpTela(tester);

    expect(
      find.text('O atestado médico não é exigido para o seu perfil.'),
      findsOneWidget,
    );
    expect(_botaoEnviar, findsNothing);
  });

  testWidgets('falha ao carregar a situação ainda deixa enviar', (
    tester,
  ) async {
    viewport(tester, const Size(800, 1400));
    api.falhaStatus = true;
    await pumpTela(tester);

    expect(
      find.text('Não foi possível carregar a situação do seu atestado.'),
      findsOneWidget,
    );
    expect(_botaoEnviar, findsOneWidget);

    api.falhaStatus = false;
    await tester.tap(find.byTooltip('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Vencimento: 30/03/2027'), findsOneWidget);
  });

  testWidgets('cabe num celular de 360 px (com erros e arquivo longo)', (
    tester,
  ) async {
    viewport(tester, const Size(360, 740));
    proximoPdf = () => _pdf(
      nome:
          'atestado-medico-cardiologista-dra-maria-souza-outubro-2026-'
          'versao-final-assinada.pdf',
    );
    api.situacao = AtestadoStatus(
      aplicavel: true,
      situacao: SituacaoAtestado.vencido,
      bloqueado: true,
      vencimento: DateTime(2026, 10, 7),
      envio: const EnvioAtestado(
        id: 'e0',
        status: StatusEnvioAtestado.recusado,
        motivoRecusa: 'O documento enviado não está legível.',
      ),
    );
    await pumpTela(tester);
    await tocarEnviar(tester);
    await tester.pumpAndSettle();
    await escolherPdf(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Informe o CRM'), findsOneWidget);
  });

  testWidgets('em tela larga (web) o conteúdo tem largura máxima', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 1400));
    await pumpTela(tester);

    final largura = tester.getSize(find.byType(Form)).width;
    expect(largura, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });
}
