import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/deep_link_listener.dart';

class RepsApp extends ConsumerStatefulWidget {
  const RepsApp({super.key});

  @override
  ConsumerState<RepsApp> createState() => _RepsAppState();
}

class _RepsAppState extends ConsumerState<RepsApp> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _msgSub;

  @override
  void initState() {
    super.initState();
    _msgSub = DeepLinkListener.instance.messages.listen((msg) {
      _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantem o SyncEngine vivo por toda a vida do app (antes so instanciava
    // ao abrir telas que liam o routineServiceProvider). Liga o auto-sync.
    ref.watch(syncEngineProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      // Muda a aba/título no modo REST (deploy academia-secami) — no modo
      // reps local-first o app nativo continua se identificando como "reps".
      title: Env.hasRestApi ? 'academia-secami' : 'reps',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // A referência visual (Casa Militar/IPASGO) não tem variante escura —
      // era ThemeMode.dark fixo (herdado do tema pessoal antigo do reps),
      // por isso o fundo aparecia preto em vez do verde/branco da referência.
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
