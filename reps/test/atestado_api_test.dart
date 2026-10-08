// Atestado médico (aluno): leitura defensiva do JSON de `GET /me/atestado`
// (campos ausentes/nulos são omitidos pelo servidor), textos da situação e
// o cliente (`AtestadoApi` + `ApiClient.postMultipart`): partes do multipart,
// token, refresh em 401 e mensagens de erro sempre amigáveis.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/academy/presentation/atestado_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _contrato = '''
{
  "aplicavel": true,
  "situacao": "VENCENDO",
  "bloqueado": false,
  "vencimento": "2027-03-30",
  "diasRestantes": 12,
  "base": "ATESTADO",
  "envio": {
    "id": "8f0c",
    "status": "RECUSADO",
    "enviadoEm": "2026-10-08T14:00:00-03:00",
    "emissaoData": "2026-10-01",
    "motivoRecusa": "PDF ilegível"
  }
}
''';

AtestadoStatus _parse(String json) =>
    AtestadoStatus.fromJson(jsonDecode(json) as Map<String, dynamic>);

Future<ApiException> _falha(Future<dynamic> Function() chamada) async {
  try {
    await chamada();
  } on ApiException catch (e) {
    return e;
  }
  fail('esperava ApiException');
}

void main() {
  group('AtestadoStatus.fromJson', () {
    test('lê o contrato completo', () {
      final s = _parse(_contrato);
      expect(s.aplicavel, isTrue);
      expect(s.situacao, SituacaoAtestado.vencendo);
      expect(s.bloqueado, isFalse);
      expect(s.vencimento, DateTime(2027, 3, 30));
      expect(s.diasRestantes, 12);
      expect(s.base, 'ATESTADO');
      final envio = s.envio!;
      expect(envio.id, '8f0c');
      expect(envio.recusado, isTrue);
      expect(envio.pendente, isFalse);
      expect(envio.motivoRecusa, 'PDF ilegível');
      expect(envio.emissaoData, DateTime(2026, 10, 1));
      // Instante com fuso → convertido pro fuso do aparelho.
      expect(
        envio.enviadoEm,
        DateTime.parse('2026-10-08T14:00:00-03:00').toLocal(),
      );
      expect(envio.enviadoEm!.isUtc, isFalse);
      expect(s.envioRecusado, isTrue);
      expect(s.exigeAtencao, isTrue);
    });

    test('aplicavel: false sem mais nada = não aplicável', () {
      final s = _parse('{"aplicavel": false}');
      expect(s.aplicavel, isFalse);
      expect(s.exigeAtencao, isFalse);
      expect(s.envio, isNull);
      expect(s.vencimento, isNull);
    });

    test('sem "aplicavel" (ou JSON vazio) = não aplicável', () {
      expect(_parse('{}').aplicavel, isFalse);
      expect(_parse('{"situacao": "VENCIDO"}').exigeAtencao, isFalse);
    });

    test('campos ausentes viram padrões seguros', () {
      final s = _parse('{"aplicavel": true}');
      expect(s.aplicavel, isTrue);
      expect(s.situacao, SituacaoAtestado.ok);
      expect(s.bloqueado, isFalse);
      expect(s.vencimento, isNull);
      expect(s.diasRestantes, isNull);
      expect(s.base, isNull);
      expect(s.envio, isNull);
      expect(s.envioPendente, isFalse);
      expect(s.exigeAtencao, isFalse);
    });

    test('nulos explícitos e tipos inesperados não quebram', () {
      final s = _parse('''
        {"aplicavel": true, "situacao": null, "bloqueado": "sim",
         "vencimento": "não é data", "diasRestantes": null, "base": "",
         "envio": "x"}
      ''');
      expect(s.situacao, SituacaoAtestado.ok);
      expect(s.bloqueado, isFalse);
      expect(s.vencimento, isNull);
      expect(s.diasRestantes, isNull);
      expect(s.base, isNull);
      expect(s.envio, isNull);
    });

    test('situação desconhecida = OK; caixa baixa é aceita', () {
      expect(
        _parse('{"aplicavel": true, "situacao": "OUTRA"}').situacao,
        SituacaoAtestado.ok,
      );
      expect(
        _parse('{"aplicavel": true, "situacao": "vencido"}').situacao,
        SituacaoAtestado.vencido,
      );
    });

    test('diasRestantes como número decimal ou texto', () {
      expect(
        _parse('{"aplicavel": true, "diasRestantes": 5.0}').diasRestantes,
        5,
      );
      expect(
        _parse('{"aplicavel": true, "diasRestantes": "-3"}').diasRestantes,
        -3,
      );
    });

    test('envio pendente sem motivo; status desconhecido não conta', () {
      final pendente = _parse(
        '{"aplicavel": true, "situacao": "VENCIDO", "bloqueado": true, '
        '"envio": {"id": "e1", "status": "PENDENTE"}}',
      );
      expect(pendente.envioPendente, isTrue);
      expect(pendente.envio!.motivoRecusa, isNull);
      expect(pendente.envio!.enviadoEm, isNull);
      expect(pendente.exigeAtencao, isTrue);

      final outro = _parse(
        '{"aplicavel": true, "envio": {"status": "APROVADO"}}',
      );
      expect(outro.envio!.status, StatusEnvioAtestado.desconhecido);
      expect(outro.envioPendente, isFalse);
      expect(outro.envioRecusado, isFalse);
      expect(outro.envio!.id, '');
    });

    test('OK com bloqueio também pede atenção', () {
      expect(
        _parse(
          '{"aplicavel": true, "situacao": "OK", '
          '"bloqueado": true}',
        ).exigeAtencao,
        isTrue,
      );
    });

    test('sem diasRestantes, calcula pelos dias até o vencimento', () {
      final s = AtestadoStatus(
        aplicavel: true,
        vencimento: DateTime(2026, 10, 20),
      );
      expect(s.diasAteVencer(hoje: DateTime(2026, 10, 8, 23, 59)), 12);
      expect(s.diasAteVencer(hoje: DateTime(2026, 10, 21)), -1);
      expect(
        const AtestadoStatus(aplicavel: true, diasRestantes: 3).diasAteVencer(),
        3,
      );
      expect(const AtestadoStatus(aplicavel: true).diasAteVencer(), isNull);
    });
  });

  group('textos', () {
    test('situação em palavras', () {
      String situacao(String json) => textoSituacaoAtestado(_parse(json));
      expect(situacao('{"aplicavel": true, "situacao": "OK"}'), 'Em dia');
      expect(
        situacao(
          '{"aplicavel": true, "situacao": "VENCENDO", "diasRestantes": 0}',
        ),
        'Vence hoje',
      );
      expect(
        situacao(
          '{"aplicavel": true, "situacao": "VENCENDO", "diasRestantes": 1}',
        ),
        'Vence amanhã',
      );
      expect(
        situacao(
          '{"aplicavel": true, "situacao": "VENCENDO", "diasRestantes": 9}',
        ),
        'Vence em 9 dias',
      );
      expect(
        situacao('{"aplicavel": true, "situacao": "VENCENDO"}'),
        'Vence em breve',
      );
      expect(situacao('{"aplicavel": true, "situacao": "VENCIDO"}'), 'Vencido');
      expect(
        situacao(
          '{"aplicavel": true, "situacao": "VENCIDO", "bloqueado": true}',
        ),
        'Vencido — acesso bloqueado',
      );
    });

    test('recusa: motivo com e sem ponto final, ou sem motivo', () {
      String? recusa(String envio) =>
          textoRecusaAtestado(_parse('{"aplicavel": true, "envio": $envio}'));
      expect(
        recusa('{"status": "RECUSADO", "motivoRecusa": "PDF ilegível"}'),
        'Seu último envio foi recusado: PDF ilegível.',
      );
      expect(
        recusa('{"status": "RECUSADO", "motivoRecusa": "Sem assinatura."}'),
        'Seu último envio foi recusado: Sem assinatura.',
      );
      expect(
        recusa('{"status": "RECUSADO"}'),
        'Seu último envio foi recusado.',
      );
      expect(recusa('{"status": "PENDENTE"}'), isNull);
    });

    test('em análise, com e sem data de envio', () {
      expect(
        textoEmAnaliseAtestado(
          AtestadoStatus(
            aplicavel: true,
            envio: EnvioAtestado(
              id: 'e1',
              status: StatusEnvioAtestado.pendente,
              enviadoEm: DateTime(2026, 10, 8, 14),
            ),
          ),
        ),
        'Seu novo atestado foi enviado em 08/10/2026 e está em análise pela '
        'academia.',
      );
      expect(
        textoEmAnaliseAtestado(
          const AtestadoStatus(
            aplicavel: true,
            envio: EnvioAtestado(id: '', status: StatusEnvioAtestado.pendente),
          ),
        ),
        'Seu novo atestado foi enviado e está em análise pela academia.',
      );
    });
  });

  group('AtestadoApi (HTTP)', () {
    setUpAll(
      () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
    );
    setUp(
      () => SharedPreferences.setMockInitialValues({
        'secami.access': 'tok-velho',
        'secami.refresh': 'ref-1',
      }),
    );

    final pdf = ArquivoPdf(
      nome: 'atestado.pdf',
      bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 conteudo')),
    );

    Future<EnvioAtestado> enviar(AtestadoApi api, {ArquivoPdf? arquivo}) =>
        api.enviar(
          emissaoData: DateTime(2026, 10, 1),
          medicoNome: 'Dra. Maria Souza',
          medicoCrm: '12345',
          medicoCrmUf: 'GO',
          arquivo: arquivo ?? pdf,
        );

    http.Response json(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

    test('status: GET /me/atestado com token', () async {
      late http.Request recebido;
      final api = AtestadoApi(
        ApiClient(
          client: MockClient((req) async {
            recebido = req;
            return http.Response.bytes(utf8.encode(_contrato), 200);
          }),
        ),
      );
      final s = await api.status();
      expect(recebido.method, 'GET');
      expect(recebido.url.toString(), 'http://localhost:8080/me/atestado');
      expect(recebido.headers['Authorization'], 'Bearer tok-velho');
      expect(s.situacao, SituacaoAtestado.vencendo);
    });

    test('status: resposta que não é objeto vira erro amigável', () async {
      final api = AtestadoApi(
        ApiClient(client: MockClient((_) async => http.Response('[]', 200))),
      );
      final e = await _falha(api.status);
      expect(e.message, contains('resposta inesperada'));
    });

    test('enviar: multipart com "dados" (JSON) e "arquivo" (PDF)', () async {
      late http.Request recebido;
      final api = AtestadoApi(
        ApiClient(
          client: MockClient((req) async {
            recebido = req;
            return json({
              'id': 'e1',
              'status': 'PENDENTE',
              'enviadoEm': '2026-10-08T14:00:00-03:00',
              'emissaoData': '2026-10-01',
            }, 201);
          }),
        ),
      );

      final envio = await enviar(api);

      expect(recebido.method, 'POST');
      expect(recebido.url.toString(), 'http://localhost:8080/me/atestado');
      expect(recebido.headers['Authorization'], 'Bearer tok-velho');
      expect(
        recebido.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final corpo = utf8.decode(recebido.bodyBytes, allowMalformed: true);
      expect(corpo, contains('name="dados"'));
      expect(corpo, contains('content-type: application/json'));
      expect(
        corpo,
        contains(
          '{"emissaoData":"2026-10-01","medicoNome":"Dra. Maria Souza",'
          '"medicoCrm":"12345","medicoCrmUf":"GO"}',
        ),
      );
      expect(corpo, contains('name="arquivo"; filename="atestado.pdf"'));
      expect(corpo, contains('content-type: application/pdf'));
      expect(corpo, contains('%PDF-1.4 conteudo'));

      expect(envio.id, 'e1');
      expect(envio.pendente, isTrue);
      expect(envio.emissaoData, DateTime(2026, 10, 1));
    });

    test('enviar: 401 renova o token e reenvia (partes novas)', () async {
      final chamadas = <String>[];
      final corpos = <String>[];
      final api = AtestadoApi(
        ApiClient(
          client: MockClient((req) async {
            chamadas.add('${req.url.path} ${req.headers['Authorization']}');
            if (req.url.path == '/auth/refresh') {
              return json({
                'accessToken': 'tok-novo',
                'refreshToken': 'ref-2',
              }, 200);
            }
            corpos.add(utf8.decode(req.bodyBytes, allowMalformed: true));
            if (req.headers['Authorization'] == 'Bearer tok-velho') {
              return json({'message': 'Token expirado'}, 401);
            }
            return json({'id': 'e2', 'status': 'PENDENTE'}, 201);
          }),
        ),
      );

      final envio = await enviar(api);

      expect(chamadas, [
        '/me/atestado Bearer tok-velho',
        '/auth/refresh null',
        '/me/atestado Bearer tok-novo',
      ]);
      expect(corpos.last, contains('name="arquivo"; filename="atestado.pdf"'));
      expect(corpos.last, contains('%PDF-1.4 conteudo'));
      expect(envio.id, 'e2');
    });

    test('enviar: 409 e 422 trazem a mensagem do servidor', () async {
      for (final (status, msg) in [
        (409, 'Você já tem um atestado em análise.'),
        (422, 'A data de emissão não pode ser no futuro.'),
      ]) {
        final api = AtestadoApi(
          ApiClient(
            client: MockClient((_) async => json({'message': msg}, status)),
          ),
        );
        final e = await _falha(() => enviar(api));
        expect(e.status, status);
        expect(e.message, msg);
      }
    });

    test('enviar: erro sem mensagem ou com HTML não vaza detalhe', () async {
      final api = AtestadoApi(
        ApiClient(
          client: MockClient(
            (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
          ),
        ),
      );
      final e = await _falha(() => enviar(api));
      expect(e.message, contains('Servidor indisponível'));
      expect(e.message, isNot(contains('<')));
    });

    test('enviar: falha de rede vira mensagem de conexão', () async {
      final api = AtestadoApi(
        ApiClient(
          client: MockClient(
            (_) async => throw http.ClientException('Failed to fetch'),
          ),
        ),
      );
      final e = await _falha(() => enviar(api));
      expect(e.status, 0);
      expect(e.message, contains('Não foi possível conectar ao servidor'));
      expect(e.message, isNot(contains('ClientException')));
    });

    test('enviar: PDF acima de 10MB nem sai do aparelho', () async {
      var chamadas = 0;
      final api = AtestadoApi(
        ApiClient(
          client: MockClient((_) async {
            chamadas++;
            return http.Response('', 201);
          }),
        ),
      );
      final grande = ArquivoPdf(
        nome: 'grande.pdf',
        bytes: Uint8List(maxAtestadoBytes + 1),
      );
      final e = await _falha(() => enviar(api, arquivo: grande));
      expect(e.message, 'O arquivo do atestado deve ter no máximo 10MB.');
      expect(chamadas, 0);
    });

    test('enviar: 201 sem corpo ainda conta como envio em análise', () async {
      final api = AtestadoApi(
        ApiClient(client: MockClient((_) async => http.Response('', 201))),
      );
      final envio = await enviar(api);
      expect(envio.pendente, isTrue);
      expect(envio.emissaoData, DateTime(2026, 10, 1));
    });
  });
}
