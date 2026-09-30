import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_providers.dart';
import '../../../core/network/erro_amigavel.dart';

/// Avisos/informativos da academia, filtrados por papel no backend. SPEC §9.3.
class AvisosScreen extends ConsumerWidget {
  const AvisosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(noticesProvider),
        child: noticesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 40, color: scheme.error),
                  const SizedBox(height: AppTheme.space12),
                  Text(
                    mensagemDeErro(
                      e,
                      fallback: 'Não foi possível carregar os avisos.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          data: (notices) {
            if (notices.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.space24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppTheme.space12),
                          Text(
                            'Nenhum aviso no momento.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: notices.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space8),
              itemBuilder: (context, i) {
                final n = notices[i];
                final (icon, color) = switch (n.type) {
                  'warning' => (Icons.warning_amber_outlined, scheme.secondary),
                  'success' => (Icons.check_circle_outline, scheme.primary),
                  _ => (Icons.info_outline, scheme.tertiary),
                };
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      foregroundColor: color,
                      child: Icon(icon, size: 20),
                    ),
                    title: Text(
                      n.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(n.content),
                    isThreeLine: n.content.length > 60,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
