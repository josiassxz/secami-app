import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';
import 'coach_widgets.dart';

/// Lado ALUNO: ver quem me acompanha e resgatar um codigo de convite.
class MeuTreinadorScreen extends ConsumerStatefulWidget {
  const MeuTreinadorScreen({super.key});

  @override
  ConsumerState<MeuTreinadorScreen> createState() => _MeuTreinadorScreenState();
}

class _MeuTreinadorScreenState extends ConsumerState<MeuTreinadorScreen> {
  final _codigoCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _vincular() async {
    final messenger = ScaffoldMessenger.of(context);
    // Consentimento explicito antes de compartilhar dados (LGPD).
    final consentiu = await _consentirCompartilhamento(context);
    if (!consentiu) return;
    setState(() => _enviando = true);
    try {
      await ref.read(coachRepositoryProvider).resgatarConvite(_codigoCtrl.text);
      _codigoCtrl.clear();
      ref.invalidate(meusTreinadoresProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Código resgatado com sucesso!')),
      );
    } on CoachException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<bool> _consentirCompartilhamento(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.privacy_tip_outlined, color: scheme.primary),
        title: const Text('Compartilhar seus dados?'),
        content: const Text(
          'Ao vincular, você autoriza este treinador a ver seus treinos, '
          'séries, cargas e evolução, e a atribuir treinos para você.\n\n'
          'Seus dados continuam seus: você pode encerrar o vínculo quando '
          'quiser, e o acesso cessa na hora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Concordo e vincular'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _encerrar(VinculoTreinador v) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmarCoach(
      context,
      titulo: 'Encerrar vínculo?',
      mensagem:
          '${v.professor.exibicao} deixará de ver seus treinos e evolução.',
      confirmar: 'Encerrar',
    );
    if (!ok) return;
    try {
      await ref.read(coachRepositoryProvider).encerrarVinculo(v.id);
      ref.invalidate(meusTreinadoresProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vínculo encerrado.')),
      );
    } on CoachException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final treinadores = ref.watch(meusTreinadoresProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu treinador')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(meusTreinadoresProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: const Icon(Icons.link, size: 18),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Text(
                            'Tenho um treinador',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Digite o código que seu treinador enviou.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space12),
                    TextField(
                      controller: _codigoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Código do convite',
                        hintText: 'A1B2-C3D4',
                      ),
                      onSubmitted: (_) => _enviando ? null : _vincular(),
                    ),
                    const SizedBox(height: AppTheme.space12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _enviando ? null : _vincular,
                        child: AnimatedSwitcher(
                          duration: AppTheme.motionFast,
                          child: _enviando
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Vincular',
                                  key: ValueKey('vincular'),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
              child: Text(
                'Quem me acompanha',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            coachSwitcher(
              stateKey: treinadores.when(
                loading: () => 'loading',
                error: (_, _) => 'error',
                data: (l) => l.isEmpty ? 'empty' : 'data-${l.length}',
              ),
              child: treinadores.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppTheme.space24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => CoachErrorBox(
                  mensagem: e is CoachException
                      ? e.mensagem
                      : 'Erro ao carregar.',
                  onRetry: () => ref.invalidate(meusTreinadoresProvider),
                ),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const CoachEmptyBox(
                      icone: Icons.sports_outlined,
                      texto: 'Nenhum treinador vinculado ainda.',
                    );
                  }
                  return Column(
                    children: [
                      for (final v in lista)
                        Card(
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.space8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onPrimaryContainer,
                              child: Text(
                                v.professor.exibicao.characters.first
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(
                              v.professor.exibicao,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              v.orgNome ?? v.professor.email,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            trailing: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              onPressed: () => _encerrar(v),
                              child: const Text('Encerrar'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
