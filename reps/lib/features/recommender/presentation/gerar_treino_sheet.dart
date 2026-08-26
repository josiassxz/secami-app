import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../routines/presentation/templates_sheet.dart';

/// Sheet de entrada para criar treino: 3 caminhos (RF-003).
///  1. Modelo pronto (fluxo antigo, mantido)
///  2. Analise simplificada (poucas perguntas)
///  3. Analise completa (questionario + triagem PAR-Q+)
class GerarTreinoSheet extends StatelessWidget {
  const GerarTreinoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como criar seu treino?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'ESCOLHA O NIVEL DE PERSONALIZACAO',
              style: AppTheme.label(11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _OpcaoCard(
              numero: '01',
              titulo: 'Usar um modelo',
              descricao:
                  'Modelos prontos (PPL, Upper/Lower, Corpo inteiro). Rapido.',
              icon: Icons.dashboard_customize_outlined,
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  backgroundColor: scheme.surface,
                  builder: (_) => const TemplatesSheet(),
                );
              },
            ),
            const SizedBox(height: 10),
            _OpcaoCard(
              numero: '02',
              titulo: 'Analise simplificada',
              descricao: 'Objetivo, dias e local. Geramos um treino na hora.',
              icon: Icons.bolt_outlined,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/recomendador?modo=simplificada');
              },
            ),
            const SizedBox(height: 10),
            _OpcaoCard(
              numero: '03',
              titulo: 'Analise completa',
              descricao:
                  'Questionario + triagem de seguranca. Recomendacao '
                  'detalhada e mais segura.',
              icon: Icons.assignment_outlined,
              destaque: true,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/recomendador?modo=completa');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoCard extends StatelessWidget {
  const _OpcaoCard({
    required this.numero,
    required this.titulo,
    required this.descricao,
    required this.icon,
    required this.onTap,
    this.destaque = false,
  });

  final String numero;
  final String titulo;
  final String descricao;
  final IconData icon;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: destaque ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: destaque ? scheme.primary : scheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: destaque ? scheme.primary : scheme.onSurfaceVariant,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        numero,
                        style: AppTheme.mono(
                          11,
                          weight: FontWeight.w500,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        titulo,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricao,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
