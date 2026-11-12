// Punições de Lutas (aluno): leitura defensiva do JSON de `GET /me/punicoes`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/presentation/punicoes_widgets.dart';

const _contrato = '''
{
  "id": "p1",
  "studentId": "s1",
  "studentName": "Carlos Lima",
  "itens": [
    {"itemId": "i1", "nome": "10 flexões"},
    {"itemId": "i2", "nome": "1 Coca-Cola"}
  ],
  "observacao": "Chegou atrasado",
  "status": "CUMPRIDA",
  "aplicadaEm": "2026-11-03T13:00:00Z",
  "aplicadaPorNome": "Instrutor João",
  "cumpridaEm": "2026-11-05T10:00:00-03:00",
  "cumpridaPorNome": "Instrutor João",
  "concluidaEm": null
}
''';

Punicao _parse(String json) =>
    Punicao.fromJson(jsonDecode(json) as Map<String, dynamic>);

void main() {
  test('lê o contrato completo', () {
    final p = _parse(_contrato);
    expect(p.id, 'p1');
    expect(p.studentId, 's1');
    expect(p.studentName, 'Carlos Lima');
    expect(p.itens.map((i) => i.itemId), ['i1', 'i2']);
    expect(p.descricao, '10 flexões + 1 Coca-Cola');
    expect(p.observacao, 'Chegou atrasado');
    expect(p.status, StatusPunicao.cumprida);
    expect(p.aplicadaEm, DateTime.utc(2026, 11, 3, 13).toLocal());
    expect(p.aplicadaEm!.isUtc, isFalse);
    expect(p.aplicadaPorNome, 'Instrutor João');
    expect(p.cumpridaEm, isNotNull);
    expect(p.cumpridaPorNome, 'Instrutor João');
    expect(p.concluidaEm, isNull);
  });

  test('campos ausentes/nulos não quebram', () {
    final p = _parse('{"id": "p2", "status": "PENDENTE", "observacao": " "}');
    expect(p.status, StatusPunicao.pendente);
    expect(p.itens, isEmpty);
    expect(p.descricao, '');
    expect(p.observacao, isNull);
    expect(p.aplicadaEm, isNull);
  });

  test('status desconhecido e textos do status', () {
    expect(_parse('{"status": "OUTRO"}').status, StatusPunicao.desconhecido);
    expect(_parse('{"status": "concluida"}').status, StatusPunicao.concluida);
    expect(textoStatusPunicao(StatusPunicao.pendente), 'Pendente');
    expect(textoStatusPunicao(StatusPunicao.cumprida), 'Cumprida');
  });
}
