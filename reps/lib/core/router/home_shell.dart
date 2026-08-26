import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/env.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_status.dart';
import '../theme/app_theme.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static final _routes = [
    ('/routines', Icons.list_alt_outlined, Icons.list_alt, 'Treinos'),
    ('/library', Icons.menu_book_outlined, Icons.menu_book, 'Biblioteca'),
    ('/history', Icons.history_outlined, Icons.history, 'Histórico'),
    if (Env.hasRestApi)
      ('/academia', Icons.school_outlined, Icons.school, 'Academia'),
    ('/settings', Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _routes.length; i++) {
      if (loc.startsWith(_routes[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusProvider);
    return Scaffold(
      body: Column(
        children: [
          syncAsync.maybeWhen(
            data: (s) => _SyncBanner(
              status: s,
              // Toque no banner de erro tenta sincronizar de novo na hora.
              onRetry: () => ref.read(syncEngineProvider).runOnce(),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex(context),
          onDestinationSelected: (i) => context.go(_routes[i].$1),
          destinations: [
            for (final r in _routes)
              NavigationDestination(
                icon: Icon(r.$2),
                selectedIcon: Icon(r.$3),
                label: r.$4,
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.status, this.onRetry});

  final SyncStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (status.phase == SyncPhase.idle && status.lastError == null) {
      return const SizedBox.shrink();
    }
    final isError = status.phase == SyncPhase.error || status.lastError != null;
    final scheme = Theme.of(context).colorScheme;
    String text;
    Color dotColor;
    Color textColor;
    switch (status.phase) {
      case SyncPhase.pushing:
        text = 'ENVIANDO ALTERAÇÕES';
        dotColor = scheme.secondary;
        textColor = scheme.secondary;
      case SyncPhase.pulling:
        text = 'BUSCANDO ATUALIZAÇÕES';
        dotColor = scheme.secondary;
        textColor = scheme.secondary;
      case SyncPhase.error:
        text = 'OFFLINE — TOQUE PARA SINCRONIZAR';
        dotColor = scheme.error;
        textColor = scheme.error;
      case SyncPhase.idle:
        if (status.lastError != null) {
          text = 'OFFLINE — TOQUE PARA SINCRONIZAR';
          dotColor = scheme.error;
          textColor = scheme.error;
        } else {
          return const SizedBox.shrink();
        }
    }
    final canRetry = isError && onRetry != null;
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTap: canRetry ? onRetry : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: scheme.outline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 6, height: 6, color: dotColor),
              const SizedBox(width: 8),
              Text(text, style: AppTheme.label(11, color: textColor)),
              if (status.isRunning) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
