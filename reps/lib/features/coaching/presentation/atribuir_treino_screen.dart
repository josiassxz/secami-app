import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../routines/data/routine_providers.dart';
import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';
import 'coach_widgets.dart';

/// Professor escolhe uma das proprias rotinas para atribuir ao aluno.
/// A rotina e clonada na conta do aluno (origem='atribuida').
class AtribuirTreinoScreen extends ConsumerStatefulWidget {
  const AtribuirTreinoScreen({
    super.key,
    required this.alunoId,
    required this.alunoNome,
  });

  final String alunoId;
  final String alunoNome;

  @override
  ConsumerState<AtribuirTreinoScreen> createState() =>
      _AtribuirTreinoScreenState();
}

class _AtribuirTreinoScreenState extends ConsumerState<AtribuirTreinoScreen> {
  String? _atribuindoId;

  Future<void> _atribuir(String routineId, String nome, String tipo) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _atribuindoId = routineId);
    try {
      final service = ref.read(routineServiceProvider);
      final rotina = await service.findById(routineId);
      final exs = await service.exercisesOf(routineId);
      if (rotina == null) {
        throw CoachException('Treino não encontrado.');
      }
      await ref
          .read(coachRepositoryProvider)
          .atribuirRotina(
            alunoId: widget.alunoId,
            nome: rotina.nome,
            tipo: rotina.tipo,
            diasDaSemana: RoutineService.decodeDias(rotina.diasDaSemana),
            exercicios: [
              for (final e in exs)
                ExercicioAtribuir(
                  exerciseId: e.exerciseId,
                  ordem: e.ordem,
                  seriesPlanejadasJson: e.seriesPlanejadas,
                  notas: e.notas,
                ),
            ],
          );
      ref.invalidate(rotinasAtribuidasProvider(widget.alunoId));
      messenger.showSnackBar(
        SnackBar(content: Text('"$nome" atribuído a ${widget.alunoNome}.')),
      );
      navigator.pop();
    } on CoachException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _atribuindoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rotinas = ref.watch(routinesAtivasProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Atribuir a ${widget.alunoNome}')),
      body: coachSwitcher(
        stateKey: rotinas.when(
          loading: () => 'loading',
          error: (_, _) => 'error',
          data: (l) => l.where((r) => r.origem != 'atribuida').isEmpty
              ? 'empty'
              : 'data-${l.length}',
        ),
        child: rotinas.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: CoachErrorBox(
              mensagem: 'Erro ao carregar seus treinos.',
              onRetry: () => ref.invalidate(routinesAtivasProvider),
            ),
          ),
          data: (lista) {
            // So treinos proprios podem ser atribuidos.
            final proprias = lista
                .where((r) => r.origem != 'atribuida')
                .toList();
            if (proprias.isEmpty) {
              return const Center(
                child: CoachEmptyBox(
                  icone: Icons.fitness_center_outlined,
                  texto:
                      'Você ainda não tem treinos próprios.\nCrie um em '
                      '"Treinos" para poder atribuir.',
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space12,
                AppTheme.space12,
                AppTheme.space12,
                AppTheme.space24,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space4,
                    0,
                    AppTheme.space4,
                    AppTheme.space12,
                  ),
                  child: Text(
                    'Escolha um treino seu para enviar ao aluno. '
                    'Ele recebe uma cópia editável por você.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final r in proprias)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.space8),
                    child: ListTile(
                      leading: Icon(
                        Icons.fitness_center,
                        color: scheme.primary,
                      ),
                      title: Text(r.nome),
                      subtitle: Text(
                        r.tipo == 'fixo' ? 'Treino fixo' : 'Avulso',
                      ),
                      trailing: AnimatedSwitcher(
                        duration: AppTheme.motionFast,
                        child: _atribuindoId == r.id
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : FilledButton(
                                key: const ValueKey('atribuir'),
                                onPressed: _atribuindoId == null
                                    ? () => _atribuir(r.id, r.nome, r.tipo)
                                    : null,
                                child: const Text('Atribuir'),
                              ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
