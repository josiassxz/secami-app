// Regras de acesso por papel do modo SECAMI (redirect do GoRouter e tela de
// entrada pós-login) — função pura, sem subir o app.

import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/router/secami_access.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';

SecamiUser _user(List<String> roles) => SecamiUser(
  id: 'u1',
  samAccountName: 'fulano',
  nome: 'Fulano',
  email: 'fulano@goias.gov.br',
  roles: roles,
);

void main() {
  final aluno = _user(['aluno']);
  final instrutor = _user(['professor']);
  final ambos = _user(['aluno', 'professor']);
  final admin = _user(['admin']);

  group('SecamiUser — papéis', () {
    test('isInstrutor = papel professor do backend', () {
      expect(instrutor.isInstrutor, isTrue);
      expect(instrutor.isProfessor, isTrue);
      expect(aluno.isInstrutor, isFalse);
      expect(admin.isInstrutor, isFalse);
    });

    test('isSomenteInstrutor = instrutor que não é aluno', () {
      expect(instrutor.isSomenteInstrutor, isTrue);
      expect(ambos.isSomenteInstrutor, isFalse);
      expect(aluno.isSomenteInstrutor, isFalse);
      expect(admin.isSomenteInstrutor, isFalse);
    });
  });

  group('sem sessão', () {
    test('rotas públicas abrem; o resto vai pro login', () {
      expect(secamiRedirect(null, '/sign-in'), isNull);
      expect(secamiRedirect(null, '/cadastro'), isNull);
      expect(secamiRedirect(null, '/'), '/sign-in');
      expect(secamiRedirect(null, '/routines'), '/sign-in');
      expect(secamiRedirect(null, '/instrutor/alunos'), '/sign-in');
    });
  });

  group('tela de entrada pós-login', () {
    test('só instrutor cai na Academia; os demais, em Treinos', () {
      expect(rotaInicialSecami(instrutor), '/academia');
      expect(rotaInicialSecami(aluno), '/routines');
      expect(rotaInicialSecami(ambos), '/routines');
      expect(rotaInicialSecami(admin), '/routines');
      expect(rotaInicialSecami(null), '/routines');
    });

    test('logado nas telas de entrada é levado pra tela inicial do papel', () {
      for (final loc in ['/', '/sign-in', '/sign-up', '/cadastro']) {
        expect(secamiRedirect(instrutor, loc), '/academia', reason: loc);
        expect(secamiRedirect(aluno, loc), '/routines', reason: loc);
      }
      expect(secamiRedirect(ambos, '/forgot-password'), '/routines');
    });
  });

  group('telas de aluno', () {
    const rotas = [
      '/academia/agenda',
      '/academia/treino',
      '/academia/perfil',
      '/coach/treinador',
    ];

    test('quem não é aluno volta pro hub', () {
      for (final loc in rotas) {
        expect(secamiRedirect(instrutor, loc), '/academia', reason: loc);
        expect(secamiRedirect(admin, loc), '/academia', reason: loc);
      }
    });

    test('aluno (inclusive instrutor que é aluno) abre normalmente', () {
      for (final loc in rotas) {
        expect(secamiRedirect(aluno, loc), isNull, reason: loc);
        expect(secamiRedirect(ambos, loc), isNull, reason: loc);
      }
    });
  });

  group('telas do instrutor', () {
    const rotas = [
      '/instrutor/alunos',
      '/instrutor/aluno/abc-123',
      '/instrutor/aluno/abc-123/ficha',
    ];

    test('quem não é instrutor volta pro hub', () {
      for (final loc in rotas) {
        expect(secamiRedirect(aluno, loc), '/academia', reason: loc);
        expect(secamiRedirect(admin, loc), '/academia', reason: loc);
      }
    });

    test('instrutor abre normalmente', () {
      for (final loc in rotas) {
        expect(secamiRedirect(instrutor, loc), isNull, reason: loc);
        expect(secamiRedirect(ambos, loc), isNull, reason: loc);
      }
    });
  });

  test('telas comuns ficam abertas pra qualquer papel', () {
    const rotas = [
      '/routines',
      '/library',
      '/history',
      '/settings',
      '/academia',
      '/academia/avisos',
    ];
    for (final user in [aluno, instrutor, ambos, admin]) {
      for (final loc in rotas) {
        expect(secamiRedirect(user, loc), isNull, reason: loc);
      }
    }
  });
}
