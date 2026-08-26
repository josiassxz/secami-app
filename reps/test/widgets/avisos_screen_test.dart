// Widget tests da tela "Avisos" — cobre render da lista, estado vazio,
// loading e erro. Sem rede: noticesProvider é substituído via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/academy_providers.dart';
import 'package:reps/features/academy/presentation/avisos_screen.dart';

void main() {
  Future<void> pumpAvisos(WidgetTester tester, {required Override override}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: const MaterialApp(home: AvisosScreen()),
      ),
    );
  }

  testWidgets('renderiza a lista de avisos com título e conteúdo', (
    tester,
  ) async {
    await pumpAvisos(
      tester,
      override: noticesProvider.overrideWith(
        (ref) => Future.value(const [
          NoticeDto(
            title: 'Academia fechada no feriado',
            content: 'Sem expediente em 07/09.',
            type: 'warning',
          ),
          NoticeDto(
            title: 'Nova ficha disponível',
            content: 'Procure seu professor para retirar.',
            type: 'info',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Academia fechada no feriado'), findsOneWidget);
    expect(find.text('Sem expediente em 07/09.'), findsOneWidget);
    expect(find.text('Nova ficha disponível'), findsOneWidget);
    expect(find.text('Procure seu professor para retirar.'), findsOneWidget);
  });

  testWidgets('mostra estado vazio quando não há avisos', (tester) async {
    await pumpAvisos(
      tester,
      override: noticesProvider.overrideWith((ref) => Future.value(const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum aviso no momento.'), findsOneWidget);
  });

  testWidgets('mostra loading enquanto os avisos carregam', (tester) async {
    await pumpAvisos(
      tester,
      override: noticesProvider.overrideWith(
        (ref) => Completer<List<NoticeDto>>().future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('mostra mensagem de erro quando falha ao carregar avisos', (
    tester,
  ) async {
    await pumpAvisos(
      tester,
      override: noticesProvider.overrideWith(
        (ref) => Future<List<NoticeDto>>.error(Exception('falha de rede')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro:'), findsOneWidget);
  });
}
