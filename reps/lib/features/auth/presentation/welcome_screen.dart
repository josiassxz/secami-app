import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Mark editorial: numero gigante de fundo (referencia academia: numero de serie)
            Positioned(
              top: -40,
              right: -30,
              child: Text(
                '01',
                style: AppTheme.mono(360, weight: FontWeight.w800).copyWith(
                  color: scheme.primary.withValues(alpha: 0.06),
                  height: 0.85,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: marca + meta
                  Row(
                    children: [
                      _Wordmark(scheme: scheme),
                      const Spacer(),
                      Text(
                        'V0.1',
                        style: AppTheme.mono(
                          11,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  _EntranceFade(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Hero(),
                        const SizedBox(height: AppTheme.space32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Text(
                                'Diario de treino tecnico, local-first.\n'
                                'Sugere carga, substitui exercício, timer no pulso.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.55,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  // CTAs
                  FilledButton(
                    onPressed: () async {
                      ref.read(guestIdentityProvider).getOrCreate();
                      await Observability.track('guest_mode_chosen');
                      if (!context.mounted) return;
                      context.go('/routines');
                    },
                    child: const Text('TREINAR SEM CADASTRO'),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/sign-in'),
                          child: const Text('ENTRAR'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/sign-up'),
                          child: const Text('CRIAR CONTA'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  Text(
                    'Você pode criar conta depois sem perder seu histórico.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.rectangle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'REPS',
          style: AppTheme.label(
            13,
            color: scheme.onSurface,
          ).copyWith(letterSpacing: 0.24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sem firula.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          'Só treino.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

/// Fade + leve subida (12dp) na entrada da tela — feedback de que a tela
/// terminou de carregar, sem "bounce" (design-system.md §8).
class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.motionSlow,
      curve: AppTheme.easingStandard,
      builder: (context, t, childWidget) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: childWidget,
        ),
      ),
      child: child,
    );
  }
}
