import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Estado vazio padrao das telas de coaching.
class CoachEmptyBox extends StatelessWidget {
  const CoachEmptyBox({super.key, required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space32,
        horizontal: AppTheme.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 32, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Estado de erro com acao de retry.
class CoachErrorBox extends StatelessWidget {
  const CoachErrorBox({
    super.key,
    required this.mensagem,
    required this.onRetry,
  });
  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space24,
        horizontal: AppTheme.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: scheme.error, size: 26),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

/// Envolve um estado vazio/erro numa lista rolavel (mantem pull-to-refresh
/// funcionando) e centraliza o conteudo verticalmente mesmo em telas altas,
/// em vez de ficar "colado" no topo.
Widget coachCenteredList(Widget child) {
  return CustomScrollView(
    slivers: [
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
    ],
  );
}

/// Cross-fade curto entre loading/erro/dado — confirma pro usuario que o
/// conteudo mudou, sem chamar atencao pra si mesmo (design-system.md §8).
Widget coachSwitcher({required String stateKey, required Widget child}) {
  return AnimatedSwitcher(
    duration: AppTheme.motionBase,
    switchInCurve: AppTheme.easingStandard,
    switchOutCurve: AppTheme.easingStandard,
    child: KeyedSubtree(key: ValueKey(stateKey), child: child),
  );
}

/// Dialog de confirmacao destrutiva (encerrar vinculo, etc).
Future<bool> confirmarCoach(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmar = 'Confirmar',
}) async {
  final scheme = Theme.of(context).colorScheme;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.link_off, color: scheme.error),
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}
