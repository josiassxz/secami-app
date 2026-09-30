// Widget tests da janela de avisos ao entrar no app (SECAMI): um aviso por
// vez, "Não mostrar novamente" chama a dispensa, uma verificação por sessão
// e falha de rede nunca bloqueia a entrada. Sem rede: API e usuário fakes.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/avisos_api.dart';
import 'package:reps/features/academy/presentation/avisos_janela.dart';
import 'package:reps/features/auth/data/rest_auth_service.dart';

class _FakeAvisosApi implements AvisosApi {
  _FakeAvisosApi(this.avisos, {this.falha = false});

  final List<NoticeDto> avisos;
  final bool falha;
  int chamadas = 0;
  final dispensados = <String>[];

  @override
  Future<List<NoticeDto>> janela() async {
    chamadas++;
    if (falha) throw Exception('falha de rede');
    return avisos;
  }

  @override
  Future<void> dispensar(String avisoId) async => dispensados.add(avisoId);
}

const _usuario = SecamiUser(
  id: 'u1',
  samAccountName: '',
  nome: 'Aluno Teste',
  email: 'aluno@goias.gov.br',
  roles: ['aluno'],
);

const _feriado = NoticeDto(
  id: 'n1',
  title: 'Academia fechada no feriado',
  content: 'Sem expediente em 12/10.',
  type: 'warning',
);
const _saude = NoticeDto(
  id: 'n2',
  title: 'Semana da saúde',
  content: 'Avaliação física gratuita.',
  type: 'success',
);

ProviderContainer _container(
  _FakeAvisosApi api, {
  SecamiUser? usuario = _usuario,
}) => ProviderContainer(
  overrides: [
    avisosApiProvider.overrideWithValue(api),
    secamiCurrentUserProvider.overrideWith((ref) async => usuario),
  ],
);

Future<void> _entrar(WidgetTester tester, ProviderContainer c) async {
  // Resolve a sessão antes, como o router faz antes de liberar as telas.
  await c.read(secamiCurrentUserProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: AvisosJanelaGate(child: Scaffold(body: Text('conteudo do app'))),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));

  testWidgets('abre o aviso ao entrar; fechar sem marcar não dispensa', (
    tester,
  ) async {
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);

    expect(find.text('Academia fechada no feriado'), findsOneWidget);
    expect(find.text('Sem expediente em 12/10.'), findsOneWidget);
    expect(find.text('Não mostrar novamente'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Academia fechada no feriado'), findsNothing);
    expect(find.text('conteudo do app'), findsOneWidget);
    expect(api.dispensados, isEmpty);
  });

  testWidgets('"Não mostrar novamente" dispensa o aviso no servidor', (
    tester,
  ) async {
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);

    await tester.tap(find.text('Não mostrar novamente'));
    await tester.pump();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(api.dispensados, ['n1']);
  });

  testWidgets('vários avisos aparecem um de cada vez', (tester) async {
    final api = _FakeAvisosApi([_feriado, _saude]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);

    expect(find.text('Aviso 1 de 2'), findsOneWidget);
    expect(find.text('Academia fechada no feriado'), findsOneWidget);
    expect(find.text('Semana da saúde'), findsNothing);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 2 de 2'), findsOneWidget);
    expect(find.text('Semana da saúde'), findsOneWidget);
    await tester.tap(find.text('Não mostrar novamente'));
    await tester.pump();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(api.dispensados, ['n2']);
  });

  testWidgets('só verifica uma vez por sessão (trocar de tela não reabre)', (
    tester,
  ) async {
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    // Recria o gate (como ao voltar de uma tela cheia pro shell).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: AvisosJanelaGate(child: Scaffold(body: Text('outra aba'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.chamadas, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('sair e entrar de novo mostra o aviso outra vez', (tester) async {
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Nova sessão (como o login faz: refresh do usuário atual).
    await c.refresh(secamiCurrentUserProvider.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.chamadas, 2);
    expect(find.text('Academia fechada no feriado'), findsOneWidget);
  });

  testWidgets('sem avisos: entra normal, sem janela', (tester) async {
    final api = _FakeAvisosApi(const []);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    expect(api.chamadas, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('conteudo do app'), findsOneWidget);
  });

  testWidgets('sem sessão: nem consulta os avisos', (tester) async {
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api, usuario: null);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    expect(api.chamadas, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('falha de rede não bloqueia a entrada', (tester) async {
    final api = _FakeAvisosApi([_feriado], falha: true);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    expect(api.chamadas, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('conteudo do app'), findsOneWidget);
  });

  testWidgets('fora do modo SECAMI (sem API) não faz nada', (tester) async {
    dotenv.testLoad(fileInput: '');
    final api = _FakeAvisosApi([_feriado]);
    final c = _container(api);
    addTearDown(c.dispose);
    await _entrar(tester, c);
    expect(api.chamadas, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
