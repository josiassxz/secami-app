// Migração E9 — smoke test do modo SECAMI (LDAP/REST) contra um backend
// REAL rodando em localhost:8080 (ver plataforma/backend). NÃO roda no CI
// (precisa do backend no ar e de um simulador/device). Executar com:
//   flutter test integration_test/secami_login_test.dart -d <device-id>
//
// Exercita de verdade (não é só "compila"): boot em modo SECAMI, redirect
// para /sign-in sem sessão, login LDAP (usuário dev "aluno"/"secami123") via
// rede real, redirect pós-login, navegação pelas telas de academia, e o
// ciclo completo de agendar → cancelar um horário pela UI.
//
// Pré-requisitos no backend (mesmos da suíte de testes E3): o Student
// vinculado ao usuário "aluno" precisa ter photo_id e atestado_data válidos
// (senão o agendamento é recusado pela regra de negócio — ver
// SchedulingService), e nenhum agendamento ativo pendente (senão a regra de
// "1 por dia"/"máx 2 ativos" barra o teste).
//
// pumpAndSettle SEMPRE com timeout explícito: sem isso, uma tela presa em
// "loading" (spinner com animação perpétua) trava o teste para sempre em vez
// de falhar com um erro claro (PumpAndSettleTimedOutException).
//
// scrollUntilVisible em vez de find() direto na seção "Meus agendamentos":
// MinhaAgendaScreen usa ListView(children: [...]) — mesmo passando uma lista
// literal (não .builder), o Sliver por trás AINDA virtualiza por viewport +
// cache extent. A seção fica abaixo da dobra e não é encontrada por find()
// até a tela ser rolada até ela (via de regra para qualquer ListView/Sliver).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reps/app.dart';
import 'package:reps/core/config/env.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settleTimeout = Duration(seconds: 10);

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  _settleTimeout,
);

/// Rola a tela (Scrollable em primeiro plano — o mais recente na pilha do
/// Navigator aparece primeiro na travessia do finder) até `finder` aparecer.
///
/// `scrollUntilVisible` só verifica se o finder já dá `match` na árvore de
/// elementos — em uma `ListView(children: [...])` com poucos itens, TODOS
/// já existem como Element desde o primeiro frame (não é lazy-built como um
/// `.builder`), então o laço encerra sem rolar de verdade, deixando o widget
/// fora da viewport visível (o design mais espaçoso da tela aumentou a
/// altura do conteúdo até o ponto de isso importar). `ensureVisible` corrige
/// isso rolando pela geometria real do RenderBox, não só a presença na
/// árvore — mantém as duas chamadas: a primeira ajuda quando o finder ainda
/// nem existe (listas realmente lazy em outras telas), a segunda garante a
/// posição.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login LDAP + navegação + agendar/cancelar horário (backend real)', (
    tester,
  ) async {
    await Env.load();
    await initializeDateFormatting('pt_BR');
    expect(
      Env.hasRestApi,
      isTrue,
      reason: 'Configure API_BASE_URL no .env antes de rodar este teste.',
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RepsApp(),
      ),
    );
    await _settle(tester);

    // Sem sessão -> router redireciona para /sign-in (SPEC §12.4: sem modo
    // convidado quando hasRestApi).
    expect(find.text('Academia SECAMI'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'aluno');
    await tester.enterText(fields.at(1), 'secami123');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ENTRAR'));
    await _settle(tester);

    // Pós-login cai em /routines (dentro do HomeShell, com bottom nav).
    expect(find.text('Academia SECAMI'), findsNothing);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);

    // Navega para o hub da Academia.
    await tester.tap(find.byIcon(Icons.school_outlined));
    await _settle(tester);
    expect(find.text('Minha Agenda'), findsOneWidget);
    expect(find.text('Meu Treino'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Meu Perfil'), findsOneWidget);

    // ---- Minha Agenda: fluxo completo de agendar + cancelar ----
    await tester.tap(find.text('Minha Agenda'));
    await _settle(tester);
    expect(find.text('Horários'), findsOneWidget);
    expect(find.textContaining('Erro'), findsNothing);

    // Rola até o primeiro botão "Agendar" (passa pela seção de horários).
    final agendarBtn = find.widgetWithText(FilledButton, 'Agendar').first;
    await _scrollTo(tester, agendarBtn);
    await tester.tap(agendarBtn);
    await _settle(tester);

    // O SnackBar "Agendado com sucesso!" (duração padrão 4s) fica parado na
    // tela sem gerar frames novos depois da animação de entrada — pumpAndSettle
    // retorna antes dele sumir, e ele cobre o botão "Cancelar" (que fica perto
    // do rodapé depois do scroll). Espera o tempo real de exibição passar
    // antes de interagir de novo perto do rodapé (integration_test roda em
    // tempo real, não em fake clock).
    await tester.pump(const Duration(seconds: 5));

    // Rola até "Meus agendamentos": agendamento real criado no backend ->
    // deixa de mostrar o estado vazio.
    await _scrollTo(tester, find.text('Meus agendamentos'));
    expect(find.text('Nenhum agendamento ativo.'), findsNothing);

    // Cancela pelo botão "Cancelar" (IconButton com tooltip) e confirma que
    // volta ao estado vazio (delete real no backend).
    final cancelarBtn = find.byTooltip('Cancelar');
    await _scrollTo(tester, cancelarBtn);
    expect(cancelarBtn, findsOneWidget);
    await tester.tap(cancelarBtn);
    await _settle(tester);
    await _scrollTo(tester, find.text('Meus agendamentos'));
    expect(find.text('Nenhum agendamento ativo.'), findsOneWidget);

    await tester.pageBack();
    await _settle(tester);

    // Avisos: lista real (pode estar vazia, mas não pode dar erro).
    await tester.tap(find.text('Avisos'));
    await _settle(tester);
    expect(find.textContaining('Erro'), findsNothing);

    await tester.pageBack();
    await _settle(tester);

    // Meu Perfil: carrega o perfil do aluno vinculado no backend.
    await tester.tap(find.text('Meu Perfil'));
    await _settle(tester);
    expect(find.textContaining('Erro'), findsNothing);
    expect(find.text('Salvar alterações'), findsOneWidget);
  });
}
