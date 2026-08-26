import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/templates_service.dart';

/// Sheet de modelos prontos de treino (PPL, Upper/Lower, Corpo Inteiro).
///
/// Cards em pt-BR, com header editorial e descricao + numero de rotinas
/// destacados. Botao no rodape de cada card aplica o modelo.
class TemplatesSheet extends ConsumerWidget {
  const TemplatesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return FutureBuilder<List<WorkoutTemplate>>(
          future: ref.read(templatesServiceProvider).load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? const [];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Começar a partir de um modelo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${list.length} MODELOS · CRIAM AS ROTINAS PRONTAS',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < list.length; i++) ...[
                  _TemplateCard(template: list[i], index: i + 1),
                  if (i != list.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends ConsumerStatefulWidget {
  const _TemplateCard({required this.template, required this.index});

  final WorkoutTemplate template;
  final int index;

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  bool _applying = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(templatesServiceProvider).apply(widget.template);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.template.rotinas.length} rotina(s) criadas a partir do modelo.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao aplicar modelo: $e')));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = widget.template;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.index.toString().padLeft(2, '0'),
                style: AppTheme.mono(
                  11,
                  weight: FontWeight.w500,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.nome,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.descricao,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetaChip(
                label: '${t.rotinas.length} ROTINAS',
                color: scheme.primary,
                bg: scheme.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 8),
              _MetaChip(
                label:
                    '${t.rotinas.fold<int>(0, (acc, r) => acc + r.exercicios.length)} EXERCÍCIOS',
                color: scheme.onSurface,
                bg: scheme.surfaceContainerHigh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _applying ? null : _apply,
              child: _applying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('USAR ESTE MODELO'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          11,
          color: color,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
