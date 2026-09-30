import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Largura máxima do conteúdo das telas do instrutor. São rotas de tela cheia
/// (fora do `HomeShell`), então sem isto uma lista/formulário esticaria de
/// borda a borda numa janela larga do Flutter web.
const instructorContentMaxWidth = 720.0;

/// Centraliza o conteúdo e limita a largura em telas largas; no celular não
/// muda nada (a largura disponível já é menor que o limite).
class InstructorContent extends StatelessWidget {
  const InstructorContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: instructorContentMaxWidth),
        child: child,
      ),
    );
  }
}

/// Estado vazio ou de erro: ícone, mensagem, dica opcional e botão opcional
/// ("Tentar novamente").
class InstructorMessage extends StatelessWidget {
  const InstructorMessage({
    required this.icon,
    required this.message,
    this.hint,
    this.isError = false,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space24,
        vertical: AppTheme.space32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: isError ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTheme.space16),
            OutlinedButton.icon(
              // O tema define largura infinita nos botões (CTA de tela
              // cheia); aqui o botão é compacto e centralizado.
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selo discreto (ex.: "Inativo", "inativa", "válida até 31/12/2026").
class InstructorBadge extends StatelessWidget {
  const InstructorBadge({required this.label, this.color, super.key});

  final String label;

  /// Cor semântica do selo; padrão = neutro.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color == null
            ? scheme.surfaceContainerHigh
            : fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

/// Iniciais para o avatar: primeira letra do primeiro e do último nome.
String iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (partes.isEmpty) return '?';
  final primeira = partes.first.characters.first;
  if (partes.length == 1) return primeira.toUpperCase();
  return (primeira + partes.last.characters.first).toUpperCase();
}

/// "1 exercício" / "N exercícios".
String rotuloExercicios(int n) => n == 1 ? '1 exercício' : '$n exercícios';

/// Resumo da prescrição: "3 × 10-12", "3 séries" ou "10-12". `null` quando
/// nada foi prescrito.
String? resumoPrescricao(int? sets, String? reps) {
  final r = reps?.trim() ?? '';
  if (sets != null && r.isNotEmpty) return '$sets × $r';
  if (sets != null) return sets == 1 ? '1 série' : '$sets séries';
  if (r.isNotEmpty) return r;
  return null;
}
