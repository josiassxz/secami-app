// Widget tests da tela "Minha Agenda" — cobre render de horários e
// agendamentos com dados, os estados vazios de cada seção (o texto
// 'Nenhum agendamento ativo.' é o mesmo exercitado por
// integration_test/secami_login_test.dart — não mudar) e loading. Sem rede:
// os FutureProviders de dados são substituídos via ProviderScope.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reps/features/academy/data/academy_api.dart';
import 'package:reps/features/academy/data/academy_providers.dart';
import 'package:reps/features/academy/presentation/minha_agenda_screen.dart';

const _slotDisponivel = AvailableSlot(
  slotStart: '08:00',
  slotEnd: '09:00',
  maxCapacity: 10,
  civilCount: 3,
  available: true,
);

const _slotIndisponivel = AvailableSlot(
  slotStart: '09:00',
  slotEnd: '10:00',
  maxCapacity: 10,
  civilCount: 10,
  available: false,
  reason: 'Horário cheio para civis.',
);

const _agendamentoAtivo = ScheduledAppointment(
  id: 'a1',
  date: '2026-08-10',
  slotStart: '08:00',
  slotEnd: '09:00',
  status: 'agendado',
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  /// Viewport bem maior que o padrão de teste (800x600): a tela lista dois
  /// blocos (horários + agendamentos) dentro de um único ListView, e o
  /// Sliver por trás só constrói os itens dentro da viewport + cache extent
  /// mesmo passando uma lista literal (`ListView(children: [...])`) — mesma
  /// armadilha documentada em integration_test/secami_login_test.dart.
  /// Aumentar o viewport evita ter que rolar a tela dentro do teste.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpAgenda(
    WidgetTester tester, {
    required List<Override> overrides,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: MinhaAgendaScreen()),
      ),
    );
  }

  testWidgets('renderiza horários disponíveis e agendamentos com dados', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpAgenda(
      tester,
      overrides: [
        availableSlotsProvider.overrideWith(
          (ref) => Future.value(const [_slotDisponivel, _slotIndisponivel]),
        ),
        myAppointmentsProvider.overrideWith(
          (ref) => Future.value(const [_agendamentoAtivo]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('08:00 – 09:00'), findsOneWidget);
    expect(find.text('3/10 vagas ocupadas'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Agendar'), findsOneWidget);
    expect(find.text('Horário cheio para civis.'), findsOneWidget);
    expect(find.text('10/08 · 08:00'), findsOneWidget);
    expect(find.text('Agendado'), findsOneWidget);
  });

  testWidgets('mostra loading enquanto horários e agendamentos carregam', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpAgenda(
      tester,
      overrides: [
        availableSlotsProvider.overrideWith(
          (ref) => Completer<List<AvailableSlot>>().future,
        ),
        myAppointmentsProvider.overrideWith(
          (ref) => Completer<List<ScheduledAppointment>>().future,
        ),
      ],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
  });

  testWidgets('mostra estado vazio de horários quando a lista vem vazia', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpAgenda(
      tester,
      overrides: [
        availableSlotsProvider.overrideWith((ref) => Future.value(const [])),
        myAppointmentsProvider.overrideWith(
          (ref) => Future.value(const [_agendamentoAtivo]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum horário disponível para esta data.'),
      findsOneWidget,
    );
    // A outra seção continua mostrando dado normalmente.
    expect(find.text('Agendado'), findsOneWidget);
  });

  testWidgets('mostra "Nenhum agendamento ativo." quando a lista vem vazia', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpAgenda(
      tester,
      overrides: [
        availableSlotsProvider.overrideWith(
          (ref) => Future.value(const [_slotDisponivel]),
        ),
        myAppointmentsProvider.overrideWith((ref) => Future.value(const [])),
      ],
    );
    await tester.pumpAndSettle();

    // Texto exato usado por integration_test/secami_login_test.dart.
    expect(find.text('Nenhum agendamento ativo.'), findsOneWidget);
    // A outra seção continua mostrando dado normalmente.
    expect(find.text('08:00 – 09:00'), findsOneWidget);
  });

  testWidgets('mostra mensagem de erro quando falha ao carregar horários', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpAgenda(
      tester,
      overrides: [
        availableSlotsProvider.overrideWith(
          (ref) =>
              Future<List<AvailableSlot>>.error(Exception('falha de rede')),
        ),
        myAppointmentsProvider.overrideWith((ref) => Future.value(const [])),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível carregar os horários'),
      findsOneWidget,
    );
  });
}
