import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/logging/observability.dart';

void main() {
  test('redige e-mail', () {
    final r = Observability.redactErrorMessage(
      'falha ao inserir usuario joao.silva+test@exemplo.com.br',
    );
    expect(r.contains('<email>'), isTrue);
    expect(r.contains('exemplo.com'), isFalse);
  });

  test('redige uuid', () {
    final r = Observability.redactErrorMessage(
      'row 123e4567-e89b-12d3-a456-426614174000 violates policy',
    );
    expect(r.contains('<uuid>'), isTrue);
    expect(r.contains('123e4567'), isFalse);
  });

  test('redige token JWT-like', () {
    final r = Observability.redactErrorMessage(
      'token eyJhbGciOiJIUzI1NiIsInR5.eyJzdWIiOiIxMjM0NT.SflKxwRJSMeKKF invalido',
    );
    expect(r.contains('<jwt>'), isTrue);
    expect(r.contains('eyJhbGci'), isFalse);
  });

  test('redige multiplas ocorrencias no mesmo texto', () {
    final r = Observability.redactErrorMessage(
      'a@a.com e b@b.com falharam; '
      '123e4567-e89b-12d3-a456-426614174000 e '
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
    expect('<email>'.allMatches(r).length, 2);
    expect('<uuid>'.allMatches(r).length, 2);
  });

  test('trunca mensagem longa em 500 + reticencias', () {
    final longo = 'x' * 1000;
    final r = Observability.redactErrorMessage(longo);
    expect(r.endsWith('...'), isTrue);
    expect(r.length, 503); // 500 + '...'
  });

  test('mensagem limpa passa intacta com prefixo runtimeType', () {
    final r = Observability.redactErrorMessage('erro simples de rede');
    expect(r, 'String: erro simples de rede');
  });
}
