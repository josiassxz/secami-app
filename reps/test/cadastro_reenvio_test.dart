// Reenvio público de atestado depois de um cadastro recusado
// (`CadastroService.reenviarAtestado` → `POST /cadastro/reenvio`): partes
// do multipart, sem token, e mensagens de erro do backend repassadas.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/auth/data/cadastro_service.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  final pdf = ArquivoPdf(
    nome: 'atestado.pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 conteudo')),
  );

  Future<void> reenviar(CadastroService service, {ArquivoPdf? arquivo}) =>
      service.reenviarAtestado(
        identificador: 'fulana@gmail.com',
        senha: 'segredo123',
        medicoNome: 'Dra. Maria Souza',
        medicoCrm: '12345',
        medicoCrmUf: 'GO',
        emissaoData: DateTime(2026, 10, 1),
        arquivo: arquivo ?? pdf,
      );

  http.Response json(Object body, int status) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<CadastroApiException> falha(Future<void> Function() chamada) async {
    try {
      await chamada();
    } on CadastroApiException catch (e) {
      return e;
    }
    fail('esperava CadastroApiException');
  }

  test('multipart com "dados" (JSON) e "atestado" (PDF), sem token', () async {
    late http.Request recebido;
    final service = CadastroService(
      client: MockClient((req) async {
        recebido = req;
        return json({'id': 'r1', 'status': 'pendente'}, 200);
      }),
    );

    await reenviar(service);

    expect(recebido.method, 'POST');
    expect(recebido.url.toString(), 'http://localhost:8080/cadastro/reenvio');
    expect(recebido.headers.containsKey('Authorization'), isFalse);
    expect(
      recebido.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final corpo = utf8.decode(recebido.bodyBytes, allowMalformed: true);
    expect(corpo, contains('name="dados"'));
    expect(corpo, contains('content-type: application/json'));
    final inicio = corpo.indexOf('{"identificador"');
    final fim = corpo.indexOf('}', inicio);
    final dados =
        jsonDecode(corpo.substring(inicio, fim + 1)) as Map<String, dynamic>;
    expect(dados, {
      'identificador': 'fulana@gmail.com',
      'senha': 'segredo123',
      'medicoNome': 'Dra. Maria Souza',
      'medicoCrm': '12345',
      'medicoCrmUf': 'GO',
      'atestadoEmissaoData': '2026-10-01',
    });
    expect(corpo, contains('name="atestado"; filename="atestado.pdf"'));
    expect(corpo, contains('content-type: application/pdf'));
    expect(corpo, contains('%PDF-1.4 conteudo'));
  });

  test('erro do backend chega com a mensagem pronta', () async {
    for (final (status, msg) in [
      (422, 'E-mail/usuário ou senha inválidos.'),
      (409, 'Seu cadastro já está em análise. Aguarde a aprovação.'),
      (404, 'Cadastro não encontrado.'),
    ]) {
      final service = CadastroService(
        client: MockClient((_) async => json({'message': msg}, status)),
      );
      final e = await falha(() => reenviar(service));
      expect(e.status, status);
      expect(e.message, msg);
    }
  });

  test('409 sem corpo usa o texto do reenvio (não o do cadastro)', () async {
    final service = CadastroService(
      client: MockClient((_) async => http.Response('', 409)),
    );
    final e = await falha(() => reenviar(service));
    expect(e.message, contains('já está em análise'));
  });

  test('PDF acima de 10MB nem sai do aparelho', () async {
    var chamou = false;
    final service = CadastroService(
      client: MockClient((_) async {
        chamou = true;
        return http.Response('', 200);
      }),
    );
    final e = await falha(
      () => reenviar(
        service,
        arquivo: ArquivoPdf(
          nome: 'grande.pdf',
          bytes: Uint8List(maxAtestadoBytes + 1),
        ),
      ),
    );
    expect(e.message, contains('10MB'));
    expect(chamou, isFalse);
  });

  test('sem conexão vira mensagem amigável', () async {
    final service = CadastroService(
      client: MockClient((_) async => throw http.ClientException('boom')),
    );
    final e = await falha(() => reenviar(service));
    expect(e.message, contains('Sem conexão'));
  });
}
