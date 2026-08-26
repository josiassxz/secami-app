import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';
import 'convite_sheet.dart';
import 'coach_widgets.dart';

/// Lado PROFESSOR: lista de alunos vinculados + convidar.
class MeusAlunosScreen extends ConsumerWidget {
  const MeusAlunosScreen({super.key});

  Future<void> _encerrar(
    BuildContext context,
    WidgetRef ref,
    VinculoAluno v,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmarCoach(
      context,
      titulo: 'Encerrar vínculo?',
      mensagem:
          'Você deixará de acompanhar ${v.aluno.exibicao}. '
          'Os treinos que você atribuiu permanecem com o aluno.',
      confirmar: 'Encerrar',
    );
    if (!ok) return;
    try {
      await ref.read(coachRepositoryProvider).encerrarVinculo(v.id);
      ref.invalidate(meusAlunosProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vínculo encerrado.')),
      );
    } on CoachException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alunos = ref.watch(meusAlunosProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus alunos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ConviteSheet.mostrar(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Convidar'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(meusAlunosProvider),
        child: coachSwitcher(
          stateKey: alunos.when(
            loading: () => 'loading',
            error: (_, _) => 'error',
            data: (l) => l.isEmpty ? 'empty' : 'data-${l.length}',
          ),
          child: alunos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => coachCenteredList(
              CoachErrorBox(
                mensagem: e is CoachException
                    ? e.mensagem
                    : 'Erro ao carregar alunos.',
                onRetry: () => ref.invalidate(meusAlunosProvider),
              ),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return coachCenteredList(
                  const CoachEmptyBox(
                    icone: Icons.groups_outlined,
                    texto:
                        'Nenhum aluno ainda.\nToque em "Convidar" para gerar '
                        'um código.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space12,
                  AppTheme.space12,
                  AppTheme.space12,
                  96,
                ),
                itemCount: lista.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space8),
                itemBuilder: (context, i) {
                  final v = lista[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Text(
                          v.aluno.exibicao.characters.first.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(
                        v.aluno.exibicao,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        v.aluno.email,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      onTap: () => context.push(
                        '/coach/aluno/${v.aluno.id}',
                        extra: v.aluno.exibicao,
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Mais opções',
                        onSelected: (op) {
                          if (op == 'encerrar') _encerrar(context, ref, v);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'encerrar',
                            child: Text(
                              'Encerrar vínculo',
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
