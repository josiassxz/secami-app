// Widget tests da seção "Minhas punições" no Meu Perfil: só aparece pro
// aluno de Lutas (ou quando há punição em aberto). Sem rede: providers de
// dados substituídos via ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/academy_providers.dart';
import 'package:reps/features/academy/data/atestado_api.dart';
import 'package:reps/features/academy/presentation/meu_perfil_screen.dart';

Map<String, dynamic> _perfil(String tipo) => {
  'fullName': 'Carlos Lima',
  'cpf': '123.456.789-09',
  'studentType': tipo,
};

final _pendente = Punicao(
  id: 'p1',
  itens: const [
    ItemPunicao(itemId: 'i1', nome: '10 flexões'),
    ItemPunicao(itemId: 'i2', nome: '1 Coca-Cola'),
  ],
  observacao: 'Chegou atrasado',
  status: StatusPunicao.pendente,
  aplicadaEm: DateTime(2026, 11, 3, 10),
);

final _cumprida = Punicao(
  id: 'p2',
  itens: const [ItemPunicao(itemId: 'i3', nome: '20 abdominais')],
  status: StatusPunicao.cumprida,
  aplicadaEm: DateTime(2026, 11, 7, 18),
);

Future<void> _pump(
  WidgetTester tester, {
  required String tipo,
  required Future<List<Punicao>> Function() punicoes,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith((ref) async => _perfil(tipo)),
        atestadoStatusProvider.overrideWith(
          (ref) async => AtestadoStatus.naoAplicavel,
        ),
        minhasPunicoesProvider.overrideWith((ref) => punicoes()),
      ],
      child: const MaterialApp(home: MeuPerfilScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('não aparece pra quem não é de Lutas e não tem punição', (
    tester,
  ) async {
    await _pump(tester, tipo: 'Civil', punicoes: () async => const []);

    expect(find.text('Minhas punições'), findsNothing);
    expect(find.text('Nenhuma punição em aberto.'), findsNothing);
    expect(find.text('DADOS PESSOAIS'), findsOneWidget);
  });

  testWidgets('não aparece pra quem não é de Lutas quando a consulta falha', (
    tester,
  ) async {
    await _pump(
      tester,
      tipo: 'Militar',
      punicoes: () async => throw Exception('404'),
    );

    expect(find.text('Minhas punições'), findsNothing);
  });

  testWidgets('aluno de Lutas sem punição vê o vazio', (tester) async {
    await _pump(tester, tipo: 'Lutas', punicoes: () async => const []);

    expect(find.text('Minhas punições'), findsOneWidget);
    expect(find.text('Nenhuma punição em aberto.'), findsOneWidget);
  });

  testWidgets('lista as punições com itens, nota, status e data', (
    tester,
  ) async {
    await _pump(
      tester,
      tipo: 'Lutas',
      punicoes: () async => [_pendente, _cumprida],
    );

    expect(find.text('Minhas punições'), findsOneWidget);
    expect(find.text('10 flexões + 1 Coca-Cola'), findsOneWidget);
    expect(find.text('Chegou atrasado'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Aplicada em 03/11'), findsOneWidget);
    expect(find.text('20 abdominais'), findsOneWidget);
    expect(find.text('Cumprida'), findsOneWidget);
    expect(find.text('Aplicada em 07/11'), findsOneWidget);
    expect(find.text('Nenhuma punição em aberto.'), findsNothing);
  });
}
