import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:reps/core/router/home_shell.dart';
import 'package:reps/core/sync/sync_providers.dart';

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/routines',
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/routines',
            builder: (context, state) => const Text('conteudo treinos'),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const Text('conteudo biblioteca'),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [syncStatusProvider.overrideWith((ref) => const Stream.empty())],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  // HomeShell._routes lê Env.hasRestApi → dotenv; sem init, lança
  // NotInitializedError (mesmo padrão de ldap_sign_in_screen_test.dart).
  setUpAll(() {
    dotenv.testLoad();
  });

  testWidgets('em janela estreita (mobile) usa NavigationBar inferior', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('em janela larga (desktop) usa NavigationRail lateral', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
