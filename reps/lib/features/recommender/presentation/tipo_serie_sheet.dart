import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/planned_set.dart';

/// Abre o seletor de tipo de série, com a explicação de cada um. Retorna o
/// tipo escolhido, ou `null` se o usuário fechar sem escolher.
Future<TipoSerie?> mostrarSeletorTipoSerie(
  BuildContext context,
  TipoSerie atual,
) {
  return showModalBottomSheet<TipoSerie>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _TipoSerieSheet(atual: atual, selecionavel: true),
  );
}

/// Abre a referência "Tipos de série" (somente leitura) — o (?) de ajuda.
Future<void> mostrarAjudaTipoSerie(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const _TipoSerieSheet(selecionavel: false),
  );
}

class _TipoSerieSheet extends StatelessWidget {
  const _TipoSerieSheet({this.atual, required this.selecionavel});

  final TipoSerie? atual;
  final bool selecionavel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selecionavel ? 'TIPO DE SÉRIE' : 'TIPOS DE SÉRIE',
              style: AppTheme.label(11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            for (final t in TipoSerie.values) ...[
              _tile(context, t),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, TipoSerie t) {
    final scheme = Theme.of(context).colorScheme;
    final selecionado = selecionavel && t == atual;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selecionado
            ? scheme.secondaryContainer
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selecionado ? scheme.secondary : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (selecionado)
                Icon(Icons.check, size: 18, color: scheme.secondary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.descricao,
            style: AppTheme.label(11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (!selecionavel) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.of(context).pop(t),
      child: card,
    );
  }
}
