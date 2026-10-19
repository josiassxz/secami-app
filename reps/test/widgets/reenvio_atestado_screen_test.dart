// Widget tests do reenvio público de atestado (`/cadastro/reenvio`), aberto
// pelo login quando o cadastro foi recusado: motivo no topo, validação do
// formulário, envio com as credenciais digitadas no login, tela de sucesso,
// mensagem do servidor e a tela sem `extra` (refresh no web). Sem rede:
// CadastroService e seletor de PDF fakes.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/auth/data/cadastro_service.dart';
import 'package:reps/features/auth/domain/cadastro_models.dart';
import 'package:reps/features/auth/domain/departamento.dart';
import 'package:reps/features/auth/presentation/reenvio_atestado_screen.dart';

class _Reenvio {
  _Reenvio(this.dados, this.arquivo);

  final Map<String, Object> dados;
  final ArquivoPdf arquivo;
}

class _FakeCadastroService implements CadastroService {
  _FakeCadastroService({this.erro});

  final CadastroApiException? erro;
  final reenvios = <_Reenvio>[];

  @override
  Future<List<Departamento>> departamentos() async => const [];

  @override
  Future<void> enviar(CadastroRequest request, PlatformFile atestado) async {}

  @override
  Future<void> reenviarAtestado({
    required String identificador,
    required String senha,
    required String medicoNome,
    required String medicoCrm,
    required String medicoCrmUf,
    required DateTime emissaoData,
    required ArquivoPdf arquivo,
  }) async {
    reenvios.add(
      _Reenvio({
        'identificador': identificador,
        'senha': senha,
        'medicoNome': medicoNome,
        'medicoCrm': medicoCrm,
        'medicoCrmUf': medicoCrmUf,
        'emissaoData': emissaoData,
      }, arquivo),
    );
    final e = erro;
    if (e != null) throw e;
  }
}

const _args = ReenvioAtestadoArgs(
  identificador: 'fulana@gmail.com',
  senha: 'segredo123',
  mensagemRecusa: 'Seu cadastro foi recusado: atestado ilegível',
);

final _botaoEnviar = find.widgetWithText(FilledButton, 'Enviar atestado');

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpTela(
    WidgetTester tester,
    _FakeCadastroService service, {
    ReenvioAtestadoArgs? args = _args,
  }) async {
    viewport(tester);
    final router = GoRouter(
      initialLocation: '/cadastro/reenvio',
      initialExtra: args,
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const Scaffold(body: Text('TELA DE LOGIN')),
        ),
        GoRoute(
          path: '/cadastro/reenvio',
          builder: (_, state) => ReenvioAtestadoScreen(
            args: state.extra is ReenvioAtestadoArgs
                ? state.extra as ReenvioAtestadoArgs
                : null,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cadastroServiceProvider.overrideWithValue(service),
          selecionarPdfProvider.overrideWithValue(
            () async => ArquivoPdf(nome: 'novo.pdf', bytes: Uint8List(2048)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preencher(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('atestado-data-emissao')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('atestado-medico-nome')),
      'Dra. Maria Souza',
    );
    await tester.enterText(
      find.byKey(const ValueKey('atestado-medico-crm')),
      '12345',
    );
    await tester.tap(find.byKey(const ValueKey('atestado-medico-uf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar arquivo PDF'));
    await tester.pumpAndSettle();
  }

  Future<void> tocarEnviar(WidgetTester tester) async {
    await tester.ensureVisible(_botaoEnviar);
    await tester.tap(_botaoEnviar);
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o motivo da recusa e o formulário', (tester) async {
    await pumpTela(tester, _FakeCadastroService());

    expect(
      find.text('Seu cadastro foi recusado: atestado ilegível'),
      findsOneWidget,
    );
    expect(find.text('DATA DE EMISSÃO'), findsOneWidget);
    expect(find.text('NOME DO MÉDICO'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.byKey(const ValueKey('atestado-medico-uf')), findsOneWidget);
    expect(find.text('Selecionar arquivo PDF'), findsOneWidget);
    expect(_botaoEnviar, findsOneWidget);
  });

  testWidgets('envio vazio é bloqueado pela validação', (tester) async {
    final service = _FakeCadastroService();
    await pumpTela(tester, service);

    await tocarEnviar(tester);

    expect(find.text('Informe a data de emissão do atestado.'), findsOneWidget);
    expect(find.text('Informe o nome do médico'), findsOneWidget);
    expect(find.text('Informe o CRM'), findsOneWidget);
    expect(find.text('Selecione'), findsOneWidget);
    expect(find.text('Anexe o atestado médico em PDF.'), findsOneWidget);
    expect(service.reenvios, isEmpty);
  });

  testWidgets('envia com as credenciais do login e mostra o sucesso', (
    tester,
  ) async {
    final service = _FakeCadastroService();
    await pumpTela(tester, service);

    await preencher(tester);
    await tocarEnviar(tester);

    expect(service.reenvios, hasLength(1));
    final envio = service.reenvios.single;
    final agora = DateTime.now();
    expect(envio.dados, {
      'identificador': 'fulana@gmail.com',
      'senha': 'segredo123',
      'medicoNome': 'Dra. Maria Souza',
      'medicoCrm': '12345',
      'medicoCrmUf': 'GO',
      'emissaoData': DateTime(agora.year, agora.month, agora.day),
    });
    expect(envio.arquivo.nome, 'novo.pdf');

    expect(find.text('Atestado enviado!'), findsOneWidget);
    expect(
      find.text(
        'Seu cadastro voltou para análise. Você será avisado quando for '
        'aprovado.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Voltar ao login'));
    await tester.pumpAndSettle();
    expect(find.text('TELA DE LOGIN'), findsOneWidget);
  });

  testWidgets('mostra a mensagem do servidor quando o envio falha', (
    tester,
  ) async {
    final service = _FakeCadastroService(
      erro: CadastroApiException(422, 'E-mail/usuário ou senha inválidos.'),
    );
    await pumpTela(tester, service);

    await preencher(tester);
    await tocarEnviar(tester);

    expect(find.text('E-mail/usuário ou senha inválidos.'), findsOneWidget);
    expect(find.text('Atestado enviado!'), findsNothing);
    expect(_botaoEnviar, findsOneWidget);
  });

  testWidgets('sem os dados do login (refresh) manda de volta pro login', (
    tester,
  ) async {
    await pumpTela(tester, _FakeCadastroService(), args: null);

    expect(find.text('DATA DE EMISSÃO'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Ir para o login'));
    await tester.pumpAndSettle();
    expect(find.text('TELA DE LOGIN'), findsOneWidget);
  });
}
