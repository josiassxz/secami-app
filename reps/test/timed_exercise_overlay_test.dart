// Stage-07 5.3: widget test do fluxo treino — o overlay de exercício por tempo
// (prancha/isometria). Cobre render do alvo, contagem regressiva e pausa.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/workout/presentation/timed_exercise_overlay.dart';

void main() {
  // Silencia plugins de plataforma tocados no initState/dispose (sem device).
  // NotificationService é no-op sem init(); restam wakelock e audioplayers.
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final canal in const [
      'wakelock_plus',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(canal),
        (_) async => null,
      );
    }
  });

  Future<void> pumpOverlay(WidgetTester tester) {
    return tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TimedExerciseOverlay(
            alvoSegundos: 30,
            nomeExercicio: 'Prancha',
          ),
        ),
      ),
    );
  }

  // O relógio é renderizado como Text separados: mm, ':', ss.
  testWidgets('mostra nome, estado e alvo inicial', (tester) async {
    await pumpOverlay(tester);

    expect(find.text('Prancha'), findsOneWidget);
    expect(find.text('EM EXECUÇÃO'), findsOneWidget);
    expect(find.text('00'), findsOneWidget); // mm
    expect(find.text('30'), findsOneWidget); // ss
  });

  testWidgets('conta regressivamente a cada segundo', (tester) async {
    await pumpOverlay(tester);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('27'), findsOneWidget); // ss = 30 - 3
  });

  testWidgets('+15s aumenta o tempo restante', (tester) async {
    await pumpOverlay(tester);

    await tester.tap(find.text('+15s'));
    await tester.pump();
    expect(find.text('45'), findsOneWidget); // ss = 30 + 15
  });

  testWidgets('PAUSAR congela a contagem', (tester) async {
    await pumpOverlay(tester);

    await tester.tap(find.text('PAUSAR'));
    await tester.pump();
    expect(find.text('RETOMAR'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    // Continua em 30 — pausado não decrementa.
    expect(find.text('30'), findsOneWidget);
  });
}
