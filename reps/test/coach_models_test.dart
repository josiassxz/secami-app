// Parsing dos DTOs de coaching a partir das respostas do Supabase
// (incluindo os recursos embutidos: aluno:users!aluno_id, org:organizacoes...).

import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/coaching/domain/coach_models.dart';

void main() {
  group('PessoaResumo', () {
    test('exibicao usa nome quando presente', () {
      final p = PessoaResumo.fromJson({
        'id': 'u1',
        'nome': 'Ana',
        'email': 'ana@x.com',
      });
      expect(p.exibicao, 'Ana');
    });

    test('exibicao cai pro email quando nome vazio/nulo', () {
      expect(
        PessoaResumo.fromJson({
          'id': 'u1',
          'email': 'a@x.com',
          'nome': '  ',
        }).exibicao,
        'a@x.com',
      );
      expect(
        PessoaResumo.fromJson({'id': 'u1', 'email': 'a@x.com'}).exibicao,
        'a@x.com',
      );
    });
  });

  test('VinculoAluno parseia recurso embutido aluno', () {
    final v = VinculoAluno.fromJson({
      'id': 'vinc1',
      'status': 'ativo',
      'aceito_em': '2026-06-01T10:00:00Z',
      'aluno': {'id': 'al1', 'nome': 'Bruno', 'email': 'b@x.com'},
    });
    expect(v.id, 'vinc1');
    expect(v.aluno.id, 'al1');
    expect(v.aluno.exibicao, 'Bruno');
    expect(v.aceitoEm, isNotNull);
  });

  test('VinculoTreinador parseia professor e org opcional', () {
    final comOrg = VinculoTreinador.fromJson({
      'id': 'v2',
      'status': 'ativo',
      'professor': {'id': 'p1', 'email': 'p@x.com'},
      'org': {'nome': 'Academia X'},
    });
    expect(comOrg.professor.exibicao, 'p@x.com');
    expect(comOrg.orgNome, 'Academia X');

    final semOrg = VinculoTreinador.fromJson({
      'id': 'v3',
      'status': 'ativo',
      'professor': {'id': 'p1', 'email': 'p@x.com'},
      'org': null,
    });
    expect(semOrg.orgNome, isNull);
  });

  test('ConviteCriado parseia codigo e expiracao', () {
    final c = ConviteCriado.fromJson({
      'codigo': 'A1B2-C3D4',
      'expira_em': '2026-06-13T10:00:00Z',
    });
    expect(c.codigo, 'A1B2-C3D4');
    expect(c.expiraEm.isAfter(DateTime.utc(2026, 6, 12)), isTrue);
  });

  test('RotinaAtribuida parseia campos e defaults', () {
    final r = RotinaAtribuida.fromJson({'id': 'r1', 'nome': 'Peito'});
    expect(r.nome, 'Peito');
    expect(r.tipo, 'fixo');
    expect(r.ativo, isTrue);
  });

  group('SessaoResumo', () {
    test('finalizada quando finalizado_em presente', () {
      final s = SessaoResumo.fromJson({
        'iniciado_em': '2026-06-01T08:00:00Z',
        'finalizado_em': '2026-06-01T09:00:00Z',
        'duracao_total_segundos': 3600,
      });
      expect(s.finalizada, isTrue);
      expect(s.duracaoSegundos, 3600);
    });

    test('nao finalizada quando finalizado_em nulo', () {
      final s = SessaoResumo.fromJson({
        'iniciado_em': '2026-06-01T08:00:00Z',
        'finalizado_em': null,
      });
      expect(s.finalizada, isFalse);
    });
  });

  test('EvolucaoAluno.vazio detecta ausencia de dados', () {
    const vazio = EvolucaoAluno(
      sessoes30d: 0,
      series30d: 0,
      volumePorGrupo: {},
      ultimasSessoes: [],
    );
    expect(vazio.vazio, isTrue);

    const cheio = EvolucaoAluno(
      sessoes30d: 2,
      series30d: 10,
      volumePorGrupo: {'peito': 1000},
      ultimasSessoes: [],
    );
    expect(cheio.vazio, isFalse);
  });

  test('Organizacao.souDono compara dono_user_id', () {
    final o = Organizacao.fromJson({
      'id': 'o1',
      'nome': 'Box',
      'dono_user_id': 'p1',
    });
    expect(o.souDono('p1'), isTrue);
    expect(o.souDono('outro'), isFalse);
  });

  test('MembroOrg parseia user embutido', () {
    final m = MembroOrg.fromJson({
      'id': 'm1',
      'papel': 'professor',
      'status': 'ativo',
      'user': {'id': 'p2', 'nome': 'Carla', 'email': 'c@x.com'},
    });
    expect(m.pessoa.exibicao, 'Carla');
    expect(m.papel, 'professor');
  });
}
