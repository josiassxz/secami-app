// Widget tests do editor de ficha (lado instrutor) — valores padrão,
// validação (título obrigatório, pelo menos 1 exercício), seletor de
// exercícios do catálogo, corpo enviado em POST/PUT, erro amigável e bloqueio
// de envio duplo. Sem rede: instructorApiProvider é um fake via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/instructor/data/instructor_api.dart';
import 'package:reps/features/instructor/presentation/ficha_editor_screen.dart';

import '../support/fake_instructor_api.dart';

const _catalogo = [
  CatalogExercise(
    id: 'e1',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
  ),
  CatalogExercise(id: 'e2', name: 'Crucifixo', muscleGroup: 'Peito'),
  CatalogExercise(
    id: 'e3',
    name: 'Tríceps corda',
    muscleGroup: 'Tríceps',
    equipment: 'Polia',
  ),
  CatalogExercise(id: 'e4', name: 'Prancha'),
];

final _fichaExistente = InstructorWorkoutPlan(
  id: 'p1',
  studentId: 'a1',
  studentName: 'Ana Beatriz Souza',
  sheetLabel: 'B',
  title: 'Costas e bíceps',
  active: false,
  validUntil: DateTime(2030, 12, 31),
  exercises: const [
    PlanExerciseItem(
      exerciseId: 'e7',
      exerciseName: 'Remada curvada',
      sets: 4,
      reps: '8-10',
      restSeconds: 90,
      notes: 'Coluna neutra',
    ),
    // Exercício digitado livremente (sem id de catálogo) tem de ser mantido.
    PlanExerciseItem(exerciseName: 'Rosca direta', ordem: 1, sets: 3),
  ],
);

void main() {
  /// Abre o editor por cima de uma tela-base (como no app: o editor é
  /// empilhado sobre a lista de fichas e faz `pop` ao salvar).
  Future<void> abrirEditor(
    WidgetTester tester,
    FakeInstructorApi api, {
    FichaEditorArgs? args = const FichaEditorArgs(),
    String query = '',
    Size viewport = const Size(800, 1600),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/instrutor/aluno/a1',
      routes: [
        GoRoute(
          path: '/instrutor/aluno/:id',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(
                  '/instrutor/aluno/a1/ficha$query',
                  extra: args,
                ),
                child: const Text('abrir editor'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/instrutor/aluno/:id/ficha',
          builder: (_, state) => FichaEditorScreen(
            studentId: state.pathParameters['id']!,
            planId: state.uri.queryParameters['plano'],
            args: state.extra as FichaEditorArgs?,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [instructorApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('abrir editor'));
    await assentar(tester);
  }

  Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

  Future<void> salvar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar ficha'));
    await assentar(tester);
  }

  /// Abre o seletor, marca [nomes] e confirma.
  Future<void> adicionarExercicios(
    WidgetTester tester,
    List<String> nomes,
  ) async {
    await tester.tap(find.text('Adicionar exercício'));
    await assentar(tester);
    for (final nome in nomes) {
      await tester.tap(find.text(nome));
      await tester.pump();
    }
    await tester.tap(
      find.widgetWithText(FilledButton, 'Adicionar (${nomes.length})'),
    );
    await assentar(tester);
  }

  String rotuloSelecionado(WidgetTester tester) => tester
      .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
      .selected
      .single;

  group('ficha nova', () {
    testWidgets('abre com os padrões: rótulo A, ativa, sem validade', (
      tester,
    ) async {
      final api = FakeInstructorApi();
      await abrirEditor(tester, api);

      expect(find.text('Nova ficha'), findsOneWidget);
      expect(rotuloSelecionado(tester), 'A');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Sem data de validade'), findsOneWidget);
      expect(find.text('Nenhum exercício adicionado ainda.'), findsOneWidget);
    });

    testWidgets('rótulo padrão = primeiro ainda não usado pelo aluno', (
      tester,
    ) async {
      final api = FakeInstructorApi();
      await abrirEditor(
        tester,
        api,
        args: const FichaEditorArgs(
          usedLabels: ['A', 'B'],
          studentName: 'Ana Beatriz Souza',
        ),
      );

      expect(rotuloSelecionado(tester), 'C');
      expect(find.text('Ana Beatriz Souza'), findsOneWidget);
      // Trocar pra um rótulo já usado avisa, sem impedir.
      expect(find.textContaining('já tem outra ficha'), findsNothing);
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(rotuloSelecionado(tester), 'B');
      expect(find.text('O aluno já tem outra ficha B.'), findsOneWidget);
    });

    testWidgets('com A–D todas em uso, o padrão volta pra A', (tester) async {
      final api = FakeInstructorApi();
      await abrirEditor(
        tester,
        api,
        args: const FichaEditorArgs(usedLabels: ['A', 'B', 'C', 'D']),
      );

      expect(rotuloSelecionado(tester), 'A');
    });
  });

  group('validação', () {
    testWidgets('título é obrigatório e a ficha precisa de 1 exercício', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);

      await salvar(tester);

      expect(find.text('Informe o título da ficha.'), findsOneWidget);
      expect(find.text('Adicione pelo menos um exercício.'), findsOneWidget);
      expect(find.text('Revise os campos destacados.'), findsOneWidget);
      expect(api.created, isEmpty);
      // Continua no editor.
      expect(find.text('Nova ficha'), findsOneWidget);
    });

    testWidgets('os avisos somem assim que o instrutor corrige, sem precisar '
        'tocar em salvar de novo', (tester) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);
      await salvar(tester);
      expect(find.text('Informe o título da ficha.'), findsOneWidget);
      expect(find.text('Revise os campos destacados.'), findsOneWidget);

      await tester.enterText(campo('Título'), 'Ficha A - Peito');
      await tester.pump();

      expect(find.text('Informe o título da ficha.'), findsNothing);
      expect(find.text('Revise os campos destacados.'), findsNothing);
      // O aviso de exercício só sai quando um exercício entra.
      expect(find.text('Adicione pelo menos um exercício.'), findsOneWidget);
      await adicionarExercicios(tester, ['Prancha']);
      expect(find.text('Adicione pelo menos um exercício.'), findsNothing);
    });

    testWidgets('título só com espaços não vale', (tester) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);
      await adicionarExercicios(tester, ['Prancha']);

      await tester.enterText(campo('Título'), '   ');
      await salvar(tester);

      expect(find.text('Informe o título da ficha.'), findsOneWidget);
      expect(api.created, isEmpty);
    });

    testWidgets('com título mas sem exercício, não envia', (tester) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);

      await tester.enterText(campo('Título'), 'Peito e tríceps');
      await salvar(tester);

      expect(find.text('Informe o título da ficha.'), findsNothing);
      expect(find.text('Adicione pelo menos um exercício.'), findsOneWidget);
      expect(api.created, isEmpty);

      // Adicionar um exercício limpa o aviso.
      await adicionarExercicios(tester, ['Prancha']);
      expect(find.text('Adicione pelo menos um exercício.'), findsNothing);
    });

    testWidgets('campos numéricos só aceitam inteiros não negativos', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);
      await adicionarExercicios(tester, ['Prancha']);
      await tester.enterText(campo('Título'), 'Core');

      // Sinal de menos, letras e decimais nem chegam a entrar no campo.
      await tester.enterText(campo('Séries'), '-3');
      await tester.enterText(campo('Descanso (s)'), '4.5s');
      await salvar(tester);

      final item = api.created.single.exercises.single;
      expect(item.sets, 3);
      expect(item.restSeconds, 45);
    });

    test('validarInteiro: vazio ok; negativo e não numérico, inválidos', () {
      expect(validarInteiro(null), isNull);
      expect(validarInteiro(''), isNull);
      expect(validarInteiro(' 12 '), isNull);
      expect(validarInteiro('0'), isNull);
      expect(validarInteiro('-1'), 'Número inválido');
      expect(validarInteiro('3.5'), 'Número inválido');
      expect(validarInteiro('abc'), 'Número inválido');
    });
  });

  group('seletor de exercícios', () {
    testWidgets('lista o catálogo, filtra por grupo e por busca', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);

      await tester.tap(find.text('Adicionar exercício'));
      await assentar(tester);

      expect(find.text('Adicionar exercícios'), findsOneWidget);
      for (final e in _catalogo) {
        expect(find.text(e.name), findsOneWidget);
      }
      expect(find.text('Peito · Barra'), findsOneWidget);
      // Grupos derivados do catálogo (mais "Todos").
      expect(find.widgetWithText(ChoiceChip, 'Todos'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Peito'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Tríceps'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));

      // Filtro por grupo muscular.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Peito'));
      await tester.pump();
      expect(find.text('Supino reto'), findsOneWidget);
      expect(find.text('Crucifixo'), findsOneWidget);
      expect(find.text('Tríceps corda'), findsNothing);
      expect(find.text('Prancha'), findsNothing);

      // Busca dentro do grupo, sem diferenciar acento/maiúscula.
      await tester.enterText(find.byType(TextField).last, 'SUPINO');
      await tester.pump();
      expect(find.text('Supino reto'), findsOneWidget);
      expect(find.text('Crucifixo'), findsNothing);

      // Volta pra "Todos" com a busca sem acento.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.enterText(find.byType(TextField).last, 'triceps');
      await tester.pump();
      expect(find.text('Tríceps corda'), findsOneWidget);
      expect(find.text('Supino reto'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'xyz');
      await tester.pump();
      expect(find.text('Nenhum exercício encontrado.'), findsOneWidget);
    });

    testWidgets('adiciona vários de uma vez, na ordem em que foram marcados', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);

      await tester.tap(find.text('Adicionar exercício'));
      await assentar(tester);
      // Nada marcado: botão desabilitado.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Selecione os exercícios'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Tríceps corda'));
      await tester.tap(find.text('Supino reto'));
      await tester.tap(find.text('Prancha'));
      await tester.pump();
      // Desmarcar tira da seleção.
      await tester.tap(find.text('Prancha'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar (2)'));
      await assentar(tester);

      expect(find.text('Adicionar exercícios'), findsNothing); // fechou
      expect(find.text('1. Tríceps corda'), findsOneWidget);
      expect(find.text('2. Supino reto'), findsOneWidget);
      expect(find.text('2 exercícios'), findsOneWidget);

      // Reabrir sinaliza o que já está na ficha.
      await tester.tap(find.text('Adicionar exercício'));
      await assentar(tester);
      expect(find.text('Peito · Barra · já na ficha'), findsOneWidget);
    });

    testWidgets('erro ao carregar o catálogo mostra mensagem e tenta de novo', (
      tester,
    ) async {
      final api = FakeInstructorApi()
        ..catalog = _catalogo
        ..catalogError = Exception('timeout');
      await abrirEditor(tester, api);

      await tester.tap(find.text('Adicionar exercício'));
      await assentar(tester);
      expect(
        find.text('Não foi possível carregar os exercícios.'),
        findsOneWidget,
      );
      expect(find.textContaining('timeout'), findsNothing);

      api.catalogError = null;
      await tester.tap(find.text('Tentar novamente'));
      await assentar(tester);
      expect(find.text('Supino reto'), findsOneWidget);
    });
  });

  group('salvar', () {
    testWidgets('ficha nova envia POST com o corpo certo e volta pra lista', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(
        tester,
        api,
        args: const FichaEditorArgs(usedLabels: ['A']),
      );

      await tester.enterText(campo('Título'), '  Peito e tríceps  ');
      await tester.tap(find.byType(Switch)); // desativa
      await adicionarExercicios(tester, ['Supino reto', 'Tríceps corda']);

      await tester.enterText(campo('Séries').at(0), '3');
      await tester.enterText(campo('Repetições').at(0), '10-12');
      await tester.enterText(campo('Descanso (s)').at(0), '60');
      await tester.enterText(campo('Observações').at(0), ' Cadência lenta ');
      await tester.enterText(campo('Séries').at(1), '4');

      await salvar(tester);

      expect(api.updated, isEmpty);
      expect(api.created.single.toJson(), {
        'studentId': 'a1',
        'sheetLabel': 'B',
        'title': 'Peito e tríceps',
        'active': false,
        'validUntil': null,
        'exercises': [
          {
            'exerciseId': 'e1',
            'exerciseName': 'Supino reto',
            'sets': 3,
            'reps': '10-12',
            'restSeconds': 60,
            'notes': 'Cadência lenta',
          },
          {
            'exerciseId': 'e3',
            'exerciseName': 'Tríceps corda',
            'sets': 4,
            'reps': null,
            'restSeconds': null,
            'notes': null,
          },
        ],
      });
      // Fechou o editor e avisou.
      expect(find.text('abrir editor'), findsOneWidget);
      expect(find.text('Salvar ficha'), findsNothing);
      expect(find.text('Ficha criada.'), findsOneWidget);
    });

    testWidgets('edição abre preenchida e envia PUT pra ficha certa', (
      tester,
    ) async {
      final api = FakeInstructorApi()..plans = [_fichaExistente];
      await abrirEditor(
        tester,
        api,
        args: FichaEditorArgs(plan: _fichaExistente, usedLabels: const ['A']),
      );

      expect(find.text('Editar ficha'), findsOneWidget);
      expect(find.text('Costas e bíceps'), findsOneWidget);
      expect(rotuloSelecionado(tester), 'B');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('31/12/2030'), findsOneWidget);
      expect(find.text('1. Remada curvada'), findsOneWidget);
      expect(find.text('2. Rosca direta'), findsOneWidget);
      expect(find.text('8-10'), findsOneWidget);
      expect(find.text('Coluna neutra'), findsOneWidget);

      await tester.enterText(campo('Título'), 'Costas');
      await tester.tap(find.text('D'));
      await tester.tap(find.byType(Switch)); // reativa
      await tester.tap(find.byTooltip('Remover validade'));
      await tester.pump();
      expect(find.text('Sem data de validade'), findsOneWidget);
      await tester.enterText(campo('Repetições').at(1), '12');

      await salvar(tester);

      expect(api.created, isEmpty);
      final envio = api.updated.single;
      expect(envio.id, 'p1');
      expect(envio.payload.toJson(), {
        'studentId': 'a1',
        'sheetLabel': 'D',
        'title': 'Costas',
        'active': true,
        'validUntil': null,
        'exercises': [
          {
            'exerciseId': 'e7',
            'exerciseName': 'Remada curvada',
            'sets': 4,
            'reps': '8-10',
            'restSeconds': 90,
            'notes': 'Coluna neutra',
          },
          {
            'exerciseId': null,
            'exerciseName': 'Rosca direta',
            'sets': 3,
            'reps': '12',
            'restSeconds': null,
            'notes': null,
          },
        ],
      });
      expect(find.text('Ficha atualizada.'), findsOneWidget);
      expect(find.text('abrir editor'), findsOneWidget);
    });

    testWidgets('validade mantida vai no corpo como YYYY-MM-DD', (
      tester,
    ) async {
      final api = FakeInstructorApi();
      await abrirEditor(
        tester,
        api,
        args: FichaEditorArgs(plan: _fichaExistente),
      );

      await salvar(tester);

      expect(api.updated.single.payload.toJson()['validUntil'], '2030-12-31');
    });

    testWidgets('reordenar e remover exercícios muda a ordem enviada', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(tester, api);
      await tester.enterText(campo('Título'), 'Treino A');
      await adicionarExercicios(tester, [
        'Supino reto',
        'Crucifixo',
        'Tríceps corda',
      ]);
      await tester.enterText(campo('Séries').at(0), '5');

      // Leva o 1º (Supino) pro fim — mesmo callback que o arrasto dispara.
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 2);
      await tester.pump();
      expect(find.text('1. Crucifixo'), findsOneWidget);
      expect(find.text('3. Supino reto'), findsOneWidget);

      // Remove o do meio (Tríceps corda).
      await tester.tap(find.byTooltip('Remover exercício').at(1));
      await assentar(tester);
      expect(find.text('Tríceps corda'), findsNothing);
      expect(find.text('2. Supino reto'), findsOneWidget);

      await salvar(tester);

      final enviados = api.created.single.exercises;
      expect(enviados.map((e) => e.exerciseName), ['Crucifixo', 'Supino reto']);
      // O valor digitado acompanha o exercício na reordenação.
      expect(enviados.last.sets, 5);
      expect(enviados.first.sets, isNull);
    });

    testWidgets('erro do backend aparece em pt-BR e permite tentar de novo', (
      tester,
    ) async {
      final api = FakeInstructorApi()
        ..catalog = _catalogo
        ..saveError = ApiException(404, 'Aluno não encontrado.');
      await abrirEditor(tester, api);
      await tester.enterText(campo('Título'), 'Treino');
      await adicionarExercicios(tester, ['Prancha']);

      await salvar(tester);

      expect(find.text('Aluno não encontrado.'), findsOneWidget);
      // Continua no editor, com o botão liberado e tocável (a mensagem fica
      // acima do botão, não por cima dele).
      expect(find.text('abrir editor'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar ficha'),
            )
            .onPressed,
        isNotNull,
      );

      api.saveError = null;
      await salvar(tester);
      expect(api.created, hasLength(2));
      expect(find.text('Aluno não encontrado.'), findsNothing);
      expect(find.text('abrir editor'), findsOneWidget);
    });

    testWidgets('exceção técnica vira mensagem genérica, nunca texto cru', (
      tester,
    ) async {
      final api = FakeInstructorApi()
        ..catalog = _catalogo
        ..saveError = StateError('type Null is not a subtype of String');
      await abrirEditor(tester, api);
      await tester.enterText(campo('Título'), 'Treino');
      await adicionarExercicios(tester, ['Prancha']);

      await salvar(tester);

      expect(find.text('Não foi possível salvar a ficha.'), findsOneWidget);
      expect(find.textContaining('subtype'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('mostra progresso no botão e não envia duas vezes', (
      tester,
    ) async {
      final gate = Completer<void>();
      final api = FakeInstructorApi()
        ..catalog = _catalogo
        ..saveGate = gate.future;
      await abrirEditor(tester, api);
      await tester.enterText(campo('Título'), 'Treino');
      await adicionarExercicios(tester, ['Prancha']);

      await tester.tap(find.widgetWithText(FilledButton, 'Salvar ficha'));
      await tester.pump();

      // Requisição em andamento: spinner no lugar do rótulo, botão travado.
      expect(find.text('Salvar ficha'), findsNothing);
      final botao = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(botao).onPressed, isNull);
      await tester.tap(botao, warnIfMissed: false);
      await tester.pump();
      expect(api.created, hasLength(1));

      gate.complete();
      await assentar(tester);
      expect(api.created, hasLength(1));
      expect(find.text('abrir editor'), findsOneWidget);
    });
  });

  group('sem `extra` (refresh no Flutter web)', () {
    testWidgets('com ?plano=<id> recarrega a ficha e edita', (tester) async {
      final api = FakeInstructorApi()..plans = [_fichaExistente];
      await abrirEditor(tester, api, args: null, query: '?plano=p1');

      expect(api.studentPlansCalls, 1);
      expect(find.text('Editar ficha'), findsOneWidget);
      expect(find.text('Costas e bíceps'), findsOneWidget);
      expect(find.text('1. Remada curvada'), findsOneWidget);

      await salvar(tester);
      expect(api.updated.single.id, 'p1');
      expect(api.created, isEmpty);
    });

    testWidgets('sem plano na URL é ficha nova, com rótulo livre', (
      tester,
    ) async {
      final api = FakeInstructorApi()..plans = [_fichaExistente]; // usa a B
      await abrirEditor(tester, api, args: null);

      expect(find.text('Nova ficha'), findsOneWidget);
      expect(rotuloSelecionado(tester), 'A');
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(find.text('O aluno já tem outra ficha B.'), findsOneWidget);
    });

    testWidgets('plano que não existe mais não vira ficha nova em silêncio', (
      tester,
    ) async {
      final api = FakeInstructorApi()..plans = [_fichaExistente];
      await abrirEditor(tester, api, args: null, query: '?plano=sumiu');

      expect(find.text('Ficha não encontrada.'), findsOneWidget);
      expect(find.text('Salvar ficha'), findsNothing);
    });

    testWidgets('falha ao recarregar mostra erro com "Tentar novamente"', (
      tester,
    ) async {
      final api = FakeInstructorApi()
        ..plans = [_fichaExistente]
        ..plansError = ApiException(500, 'Servidor indisponível.');
      await abrirEditor(tester, api, args: null, query: '?plano=p1');

      expect(find.text('Servidor indisponível.'), findsOneWidget);

      api.plansError = null;
      await tester.tap(find.text('Tentar novamente'));
      await assentar(tester);
      expect(find.text('Costas e bíceps'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('cabe num celular de 360 px com exercícios na ficha', (
      tester,
    ) async {
      final api = FakeInstructorApi()..catalog = _catalogo;
      await abrirEditor(
        tester,
        api,
        args: FichaEditorArgs(
          plan: _fichaExistente,
          usedLabels: const ['B'],
          studentName: 'Maria Aparecida Gonçalves de Oliveira Albuquerque',
        ),
        viewport: const Size(360, 740),
      );
      expect(tester.takeException(), isNull);

      // Botões de ação com pelo menos 48 px de altura.
      final salvarBtn = tester.getSize(
        find.widgetWithText(FilledButton, 'Salvar ficha'),
      );
      expect(salvarBtn.height, greaterThanOrEqualTo(48));
      final rotulos = tester.getSize(find.byType(SegmentedButton<String>));
      expect(rotulos.height, greaterThanOrEqualTo(48));

      // O seletor também cabe.
      await tester.ensureVisible(find.text('Adicionar exercício'));
      await tester.pump();
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'Adicionar exercício'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Adicionar exercício'));
      await assentar(tester);
      expect(find.text('Supino reto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('em tela larga (web) o formulário tem largura máxima', (
      tester,
    ) async {
      final api = FakeInstructorApi();
      await abrirEditor(
        tester,
        api,
        args: FichaEditorArgs(plan: _fichaExistente),
        viewport: const Size(1600, 1000),
      );

      expect(tester.getSize(campo('Título')).width, lessThanOrEqualTo(720));
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Salvar ficha')).width,
        lessThanOrEqualTo(720),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Deixa animações curtas (rota, folha, SnackBar) terminarem sem depender de
/// pumpAndSettle (há spinners nessas telas).
Future<void> assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
