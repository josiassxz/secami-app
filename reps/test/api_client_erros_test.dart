// ApiClient/mensagemDeErro: nenhuma resposta ou exceção técnica (HTML de
// proxy, JSON inválido, TypeError, timeout) pode chegar crua na UI.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/core/network/erro_amigavel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _html = '<!DOCTYPE html><html><body>502 Bad Gateway</body></html>';

ApiClient _clientCom(http.Response Function(http.Request) handler) =>
    ApiClient(client: MockClient((req) async => handler(req)));

Future<ApiException> _falha(Future<dynamic> Function() chamada) async {
  try {
    await chamada();
  } on ApiException catch (e) {
    return e;
  }
  fail('esperava ApiException');
}

void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ApiClient — resposta que não é JSON', () {
    test('502 com HTML vira mensagem de servidor indisponível', () async {
      final api = _clientCom((_) => http.Response(_html, 502));
      final e = await _falha(() => api.get('/x'));
      expect(e.status, 502);
      expect(e.message, contains('Servidor indisponível'));
      expect(e.message, isNot(contains('<')));
    });

    test(
      '200 com HTML (proxy no lugar da API) não devolve null nem vaza',
      () async {
        final api = _clientCom((_) => http.Response(_html, 200));
        final e = await _falha(() => api.get('/x'));
        expect(e.message, contains('resposta inesperada'));
        expect(e.message, isNot(contains('DOCTYPE')));
      },
    );

    test('corpo vazio em 200/204 continua válido (null)', () async {
      final api = _clientCom((_) => http.Response('', 204));
      expect(await api.delete('/x'), isNull);
    });

    test(
      '"message" que não é string cai na mensagem padrão do status',
      () async {
        final api = _clientCom((_) => http.Response('{"message": 42}', 400));
        final e = await _falha(() => api.get('/x'));
        expect(e.message, contains('Não foi possível completar'));
      },
    );

    test('"message" do backend é repassada', () async {
      final api = _clientCom(
        (_) => http.Response.bytes(
          utf8.encode('{"message":"Horário cheio."}'),
          409,
        ),
      );
      final e = await _falha(() => api.post('/x'));
      expect(e.message, 'Horário cheio.');
    });
  });

  group('ApiClient — falha de rede', () {
    test('exceção do client vira mensagem de conexão', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => throw http.ClientException('Failed to fetch'),
        ),
      );
      final e = await _falha(() => api.get('/x'));
      expect(e.status, 0);
      expect(e.message, isNot(contains('Failed to fetch')));
      expect(e.message, contains('conectar'));
    });
  });

  group('mensagemDeErro', () {
    test('ApiException usa a própria mensagem', () {
      expect(mensagemDeErro(ApiException(409, 'Já existe.')), 'Já existe.');
    });

    test('qualquer outra exceção usa o fallback, nunca o toString', () {
      final f = mensagemDeErro(
        const FormatException('Unexpected token < in JSON'),
        fallback: 'Falhou ao carregar.',
      );
      expect(f, 'Falhou ao carregar.');
      expect(mensagemDeErro(TypeError()), mensagemErroGenerica);
    });

    test('timeout vira mensagem de conexão', () {
      expect(mensagemDeErro(TimeoutException('x')), mensagemErroConexao);
    });
  });
}
