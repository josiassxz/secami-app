import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../../domain/entities/grupo_exercicio.dart';
import '../../../domain/entities/planned_set.dart';
import '../../library/data/library_repository.dart';
import '../../../domain/entities/exercise.dart';
import '../../library/presentation/exercise_thumb.dart';
import '../../workout/data/workout_controller.dart';
import '../data/routine_providers.dart';
import 'library_picker_sheet.dart';
import 'routine_edit_sheet.dart';
import 'routine_exercise_editor_sheet.dart';

class RoutineBuilderScreen extends ConsumerStatefulWidget {
  const RoutineBuilderScreen({
    required this.routineId,
    this.openPickerOnLoad = false,
    super.key,
  });

  final String routineId;
  final bool openPickerOnLoad;

  @override
  ConsumerState<RoutineBuilderScreen> createState() => _RoutineBuilderState();
}

class _RoutineBuilderState extends ConsumerState<RoutineBuilderScreen> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    if (widget.openPickerOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_autoOpened) {
          _autoOpened = true;
          unawaited(_openPicker());
        }
      });
    }
  }

  /// Abre o picker multi-select. Quando o usuario confirma, adiciona todos
  /// os exercicios selecionados na ordem em que foram marcados.
  Future<void> _openPicker() async {
    final existing = await ref
        .read(routineServiceProvider)
        .exercisesOf(widget.routineId);
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const LibraryPickerSheet(),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final service = ref.read(routineServiceProvider);
    for (var i = 0; i < picked.length; i++) {
      await service.addExercise(
        routineId: widget.routineId,
        exerciseId: picked[i].id,
        ordem: existing.length + i,
        series: const [PlannedSet(numero: 1)],
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          picked.length == 1
              ? '1 exercício adicionado'
              : '${picked.length} exercícios adicionados',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editExercise(RoutineExerciseRow re) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => RoutineExerciseEditorSheet(
        routineExerciseId: re.id,
        exerciseId: re.exerciseId,
        initialSeries: PlannedSet.decode(re.seriesPlanejadas),
        initialNotas: re.notas,
      ),
    );
  }

  Future<void> _confirmDelete(String id, String nome) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir rotina?'),
        content: Text(
          '"$nome" será removida da semana. O histórico continua salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Captura router/messenger ANTES do gap async: depois de sair da rota o
    // `context` deste State fica desativado e usa-lo dispara erro/tela preta.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(routineServiceProvider);
    // Sai da tela ENQUANTO a rotina ainda existe. Se deletassemos primeiro, o
    // watchById emitiria null nesta arvore montada e rebuildaria pra um estado
    // vazio -> tela preta. Saindo antes, a rota some da pilha e a lista
    // (que filtra deleted_at) so deixa de mostrar a rotina depois.
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/routines');
    }
    try {
      await service.remove(id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('"$nome" excluída'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'routine_delete_builder');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _editMeta(RoutineRow routine) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => RoutineEditSheet(routine: routine),
    );
  }

  Future<void> _startWorkout(String routineId) async {
    final sessionId = await ref
        .read(workoutControllerProvider.notifier)
        .startFromRoutine(routineId);
    if (!mounted) return;
    unawaited(context.push('/workout/$sessionId'));
  }

  String _slugFromExerciseId(String id) => ExerciseId.parse(id).librarySlug;

  /// Rótulo do alvo da primeira série (reps ou tempo p/ exercícios isométricos).
  String _alvoLabel(Exercise? ex, PlannedSet first) {
    final timed = (ex?.medidaPorTempo ?? false) || first.porTempo;
    if (timed) {
      final s = first.duracaoAlvoSegundos ?? 45;
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} tempo';
    }
    return '${first.repsAlvoMin}–${first.repsAlvoMax} reps';
  }

  Widget _grupoHeader(
    RoutineExerciseRow re,
    String routineId,
    ColorScheme scheme,
  ) {
    final tipo = GrupoTipo.fromString(re.grupoTipo);
    final txt = tipo == GrupoTipo.circuito
        ? 'CIRCUITO · ${re.rounds ?? '?'} RODADAS'
        : 'BI-SET';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 14, color: scheme.secondary),
          const SizedBox(width: 8),
          Text(txt, style: AppTheme.label(10, color: scheme.secondary)),
        ],
      ),
    );
  }

  Future<void> _onGrupoAction(
    String action,
    String routineId,
    RoutineExerciseRow re,
  ) async {
    final service = ref.read(routineServiceProvider);
    switch (action) {
      case 'agrupar':
        await service.agruparComAnterior(routineId, re.id);
      case 'desagrupar':
        await service.desagrupar(routineId, re.id);
      case 'biset':
        await service.definirTipoGrupo(
          routineId: routineId,
          grupoId: re.grupoId!,
          tipo: GrupoTipo.bi_set,
        );
      case 'circuito':
        final rounds = await _askRounds(re.rounds ?? 3);
        if (rounds == null) return;
        await service.definirTipoGrupo(
          routineId: routineId,
          grupoId: re.grupoId!,
          tipo: GrupoTipo.circuito,
          rounds: rounds,
        );
      case 'remover':
        await service.removeExercise(re.id);
    }
  }

  Future<int?> _askRounds(int inicial) async {
    final ctrl = TextEditingController(text: '$inicial');
    return showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rodadas do circuito'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nº de rodadas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              Navigator.of(dialogCtx).pop(n?.clamp(1, 99));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(routineByIdProvider(widget.routineId));
    final exercisesAsync = ref.watch(
      routineExercisesProvider(widget.routineId),
    );
    final scheme = Theme.of(context).colorScheme;

    return routineAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (routine) {
        if (routine == null) {
          // Rotina removida (por aqui ou via sync de outro device). Mostra um
          // estado simples com botao de voltar. NAO navega automaticamente:
          // o auto-redirect brigava com a navegacao explicita do delete e
          // estourava a pilha -> tela preta.
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rotina removida.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/routines'),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(routine.nome),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar nome / tipo / dias',
                onPressed: () => _editMeta(routine),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Excluir rotina',
                onPressed: () => _confirmDelete(routine.id, routine.nome),
              ),
            ],
          ),
          floatingActionButton: exercisesAsync.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : FloatingActionButton.extended(
                    onPressed: () => _startWorkout(routine.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('INICIAR TREINO'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          body: exercisesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (list) => _buildBody(routine, list, scheme),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    RoutineRow routine,
    List<RoutineExerciseRow> list,
    ColorScheme scheme,
  ) {
    final repo = ref.watch(libraryRepositoryProvider);

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '0',
                style: AppTheme.mono(
                  96,
                  weight: FontWeight.w300,
                ).copyWith(color: scheme.onSurfaceVariant, height: 1),
              ),
              const SizedBox(height: 4),
              Text(
                'EXERCICIOS NESTA ROTINA',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openPicker,
                icon: const Icon(Icons.add),
                label: const Text('ADICIONAR EXERCICIO'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            onReorderItem: (oldI, newI) async {
              final ids = list.map((e) => e.id).toList();
              final id = ids.removeAt(oldI);
              ids.insert(newI, id);
              await ref
                  .read(routineServiceProvider)
                  .reorderExercises(routine.id, ids);
            },
            itemBuilder: (context, i) {
              final re = list[i];
              final ex = repo.findBySlug(_slugFromExerciseId(re.exerciseId));
              final series = PlannedSet.decode(re.seriesPlanejadas);
              final agrupado = re.grupoId != null;
              final primeiroDoGrupo =
                  agrupado && (i == 0 || list[i - 1].grupoId != re.grupoId);
              final podeAgruparAnterior =
                  i > 0 && (!agrupado || list[i - 1].grupoId != re.grupoId);
              return Padding(
                key: ValueKey(re.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (primeiroDoGrupo) _grupoHeader(re, routine.id, scheme),
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        // Borda secundaria marca os membros de um grupo.
                        border: Border.all(
                          color: agrupado ? scheme.secondary : scheme.outline,
                          width: agrupado ? 1.5 : 1,
                        ),
                        boxShadow: AppTheme.cardShadow(scheme),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: AppTheme.mono(
                                  11,
                                ).copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ex == null
                                ? const Icon(Icons.fitness_center)
                                : ExerciseThumb(exercise: ex, size: 44),
                          ],
                        ),
                        title: Text(
                          ex?.nome ?? re.exerciseId,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${series.length} série${series.length == 1 ? '' : 's'}'
                          '${series.isEmpty ? '' : ' · ${_alvoLabel(ex, series.first)}'}',
                          style: AppTheme.label(
                            11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.tune),
                              tooltip: 'Editar séries',
                              onPressed: () => _editExercise(re),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Agrupar / remover',
                              onSelected: (v) =>
                                  _onGrupoAction(v, routine.id, re),
                              itemBuilder: (_) => [
                                if (podeAgruparAnterior)
                                  const PopupMenuItem(
                                    value: 'agrupar',
                                    child: Text('Agrupar com anterior'),
                                  ),
                                if (agrupado)
                                  const PopupMenuItem(
                                    value: 'biset',
                                    child: Text('Tornar bi-set'),
                                  ),
                                if (agrupado)
                                  const PopupMenuItem(
                                    value: 'circuito',
                                    child: Text('Tornar circuito…'),
                                  ),
                                if (agrupado)
                                  const PopupMenuItem(
                                    value: 'desagrupar',
                                    child: Text('Desagrupar'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remover',
                                  child: Text('Remover'),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.drag_handle,
                              color: scheme.onSurfaceVariant,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          child: OutlinedButton.icon(
            onPressed: _openPicker,
            icon: const Icon(Icons.add),
            label: const Text('ADICIONAR EXERCÍCIO'),
          ),
        ),
      ],
    );
  }
}
