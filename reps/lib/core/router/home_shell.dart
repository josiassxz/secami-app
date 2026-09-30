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

  /// Acima disso é "desktop": navegação vira rail lateral (em vez da barra
  /// inferior) e o conteúdo fica centralizado com largura máxima, em vez de
  /// esticar borda a borda numa janela larga. Mesmo corte usado pelo
  /// Material 3 pra classe de janela "expanded" (M3 window size classes).
  static const _desktopBreakpoint = 840.0;
  static const _contentMaxWidth = 1100.0;

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
    final syncBanner = syncAsync.maybeWhen(
      data: (s) => _SyncBanner(
        status: s,
        // Toque no banner de erro tenta sincronizar de novo na hora.
        onRetry: () => ref.read(syncEngineProvider).runOnce(),
      ),
      orElse: () => const SizedBox.shrink(),
    );
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            syncBanner,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex(context),
                    onDestinationSelected: (i) => context.go(_routes[i].$1),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final r in _routes)
                        NavigationRailDestination(
                          icon: Icon(r.$2),
                          selectedIcon: Icon(r.$3),
                          label: Text(r.$4),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _contentMaxWidth,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          syncBanner,
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
