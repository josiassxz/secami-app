import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';

/// Bottom sheet que gera e exibe um codigo de convite.
/// [tipo] = 'professor_aluno' (convida aluno) ou 'org_professor'
/// (convida professor pra academia, requer [orgId]).
class ConviteSheet extends ConsumerStatefulWidget {
  const ConviteSheet({super.key, this.tipo = 'professor_aluno', this.orgId});

  final String tipo;
  final String? orgId;

  static Future<void> mostrar(
    BuildContext context, {
    String tipo = 'professor_aluno',
    String? orgId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => ConviteSheet(tipo: tipo, orgId: orgId),
    );
  }

  bool get paraProfessor => tipo == 'org_professor';

  @override
  ConsumerState<ConviteSheet> createState() => _ConviteSheetState();
}

class _ConviteSheetState extends ConsumerState<ConviteSheet> {
  late Future<ConviteCriado> _futuro;

  Future<ConviteCriado> _gerar() => ref
      .read(coachRepositoryProvider)
      .criarConvite(tipo: widget.tipo, orgId: widget.orgId);

  @override
  void initState() {
    super.initState();
    _futuro = _gerar();
  }

  void _regerar() {
    setState(() {
      _futuro = _gerar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.paraProfessor ? 'Convidar professor' : 'Convidar aluno',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.paraProfessor
                  ? 'Compartilhe com o professor. Ele resgata o código em '
                        'Ajustes → Meu treinador.'
                  : 'Compartilhe este código. O aluno digita em '
                        'Ajustes → Meu treinador.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FutureBuilder<ConviteCriado>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  final msg = snap.error is CoachException
                      ? (snap.error as CoachException).mensagem
                      : 'Erro ao gerar o convite.';
                  return Column(
                    children: [
                      Text(msg, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _regerar,
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  );
                }
                final convite = snap.data!;
                return _CodigoView(
                  convite: convite,
                  onRegerar: _regerar,
                  paraProfessor: widget.paraProfessor,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CodigoView extends StatelessWidget {
  const _CodigoView({
    required this.convite,
    required this.onRegerar,
    required this.paraProfessor,
  });
  final ConviteCriado convite;
  final VoidCallback onRegerar;
  final bool paraProfessor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            convite.codigo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: convite.codigo));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      text: paraProfessor
                          ? 'Entre na nossa academia no app reps: '
                                'use o código ${convite.codigo} em '
                                'Ajustes → Meu treinador.'
                          : 'Use o código ${convite.codigo} no app reps '
                                '(Ajustes → Meu treinador) para me adicionar '
                                'como seu treinador.',
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRegerar,
          child: const Text('Gerar outro código'),
        ),
      ],
    );
  }
}
