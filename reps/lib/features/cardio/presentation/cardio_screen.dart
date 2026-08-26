import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/cardio_providers.dart';
import 'cardio_form_sheet.dart';

class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});

  static const _modalidadesLabel = {
    'esteira': 'Esteira',
    'bicicleta': 'Bicicleta',
    'escada': 'Escada',
    'corrida_ar_livre': 'Corrida ao ar livre',
    'remo': 'Remo',
    'eliptico': 'Eliptico',
    'outros': 'Outros',
  };

  /// Icone por modalidade — so identificacao visual rapida na lista (o
  /// texto do rotulo continua sendo a fonte de verdade).
  static const _modalidadesIcon = {
    'esteira': Icons.directions_walk_rounded,
    'bicicleta': Icons.directions_bike_rounded,
    'escada': Icons.stairs_rounded,
    'corrida_ar_livre': Icons.directions_run_rounded,
    'remo': Icons.rowing_rounded,
    'eliptico': Icons.all_inclusive_rounded,
    'outros': Icons.fitness_center_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(cardioListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cardio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const CardioFormSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar cardio'),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          if (list.isEmpty) {
            // Mesmo padrao das outras telas vazias do app (icone + rotulo +
            // descricao curta) — hierarquia em 3s, nada de texto solto.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_heart_outlined,
                      size: 80,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CARDIO',
                      style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma sessão de cardio.\n'
                      'Toque em "Registrar cardio" pra começar.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final df = DateFormat('dd/MM HH:mm');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = list[i];
              final icon =
                  _modalidadesIcon[c.modalidade] ??
                  Icons.directions_run_rounded;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: scheme.outline),
                  boxShadow: AppTheme.cardShadow(scheme),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _modalidadesLabel[c.modalidade] ?? c.modalidade,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            df.format(c.executadoEm.toLocal()),
                            style: AppTheme.label(
                              11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Numeros (duracao/distancia) em mono — mesma convencao
                    // usada pra carga/reps no resto do app.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${c.duracaoMinutos} min',
                          style: AppTheme.mono(
                            14,
                            weight: FontWeight.w700,
                          ).copyWith(color: scheme.onSurface),
                        ),
                        if (c.distanciaKm != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${c.distanciaKm!.toStringAsFixed(2)} km',
                            style: AppTheme.mono(
                              12,
                              weight: FontWeight.w500,
                            ).copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      tooltip: 'Excluir sessão',
                      onPressed: () =>
                          ref.read(cardioServiceProvider).remove(c.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
