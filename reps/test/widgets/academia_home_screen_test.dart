// Widget test do hub "Academia" — garante que os 4 cards de acesso rápido
// aparecem com os rótulos exatos consumidos por
// integration_test/secami_login_test.dart (find.text). Sem Riverpod: a tela
// é um StatefulWidget puro (só anima a entrada dos cards).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/presentation/academia_home_screen.dart';

void main() {
  testWidgets('renderiza os 4 cards de acesso rápido com os rótulos certos', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcademiaHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Academia'), findsOneWidget); // título da AppBar
    expect(find.text('Minha Agenda'), findsOneWidget);
    expect(find.text('Meu Treino'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Meu Perfil'), findsOneWidget);
  });
}
