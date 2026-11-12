import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_api.dart';
import '../data/academy_providers.dart';

/// Tipo de aluno de Lutas (campo `studentType` do perfil).
const tipoAlunoLutas = 'Lutas';

/// "Pendente" / "Cumprida" / "Concluída".
String textoStatusPunicao(StatusPunicao s) => switch (s) {
  StatusPunicao.pendente => 'Pendente',
  StatusPunicao.cumprida => 'Cumprida',
  StatusPunicao.concluida => 'Concluída',
  StatusPunicao.desconhecido => 'Em aberto',
};

/// Seção "Minhas punições" do Meu Perfil.
///
/// Aparece pro aluno de Lutas ([lutas]) — com o vazio "Nenhuma punição em
/// aberto." — ou pra qualquer aluno que tenha punição em aberto. Fora disso
/// (e enquanto carrega) não ocupa espaço.
class MinhasPunicoesSection extends ConsumerWidget {
  const MinhasPunicoesSection({required this.lutas, super.key});

  final bool lutas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(minhasPunicoesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => lutas
          ? const _PunicoesCard(
              child: Text('Não foi possível carregar suas punições.'),
            )
          : const SizedBox.shrink(),
      data: (punicoes) {
        if (punicoes.isEmpty && !lutas) return const SizedBox.shrink();
        return _PunicoesCard(
          child: punicoes.isEmpty
              ? const Text('Nenhuma punição em aberto.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in punicoes.indexed) ...[
                      if (i > 0) const Divider(height: AppTheme.space24),
                      _PunicaoTile(punicao: p),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _PunicoesCard extends StatelessWidget {
  const _PunicoesCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space24),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.secondary.withValues(alpha: 0.12),
                    foregroundColor: scheme.secondary,
                    child: const Icon(Icons.sports_martial_arts, size: 20),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      'Minhas punições',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              DefaultTextStyle.merge(style: textTheme.bodyMedium, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _PunicaoTile extends StatelessWidget {
  const _PunicaoTile({required this.punicao});

  final Punicao punicao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final aplicadaEm = punicao.aplicadaEm;
    final obs = punicao.observacao;
    final descricao = punicao.descricao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                descricao.isEmpty ? 'Punição' : descricao,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            _StatusChip(status: punicao.status),
          ],
        ),
        if (obs != null) ...[
          const SizedBox(height: AppTheme.space4),
          Text(obs, style: textTheme.bodyMedium),
        ],
        if (aplicadaEm != null) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            'Aplicada em ${DateFormat('dd/MM').format(aplicadaEm)}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StatusPunicao status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pendente = status == StatusPunicao.pendente;
    final (fundo, texto) = pendente
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        textoStatusPunicao(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: texto,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
