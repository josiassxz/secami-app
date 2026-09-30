import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../data/instructor_api.dart';
import '../data/instructor_providers.dart';
import 'ficha_editor_screen.dart';
import 'widgets/instructor_widgets.dart';

/// Fichas de treino (A–D) de um aluno, vistas pelo instrutor: consultar,
/// criar, editar e excluir.
class FichasAlunoScreen extends ConsumerStatefulWidget {
  const FichasAlunoScreen({
    required this.studentId,
    this.studentName,
    super.key,
  });

  final String studentId;

  /// Nome vindo da lista de alunos (`extra` da rota). `null` quando a tela é
  /// aberta direto pela URL (ex.: atualizar a página no Flutter web) — aí o
  /// nome vem das próprias fichas, quando houver.
  final String? studentName;

  @override
  ConsumerState<FichasAlunoScreen> createState() => _FichasAlunoScreenState();
}

class _FichasAlunoScreenState extends ConsumerState<FichasAlunoScreen> {
  /// Ficha com exclusão em andamento (bloqueia toque duplo).
  String? _excluindoId;

  String _nomeAluno(List<InstructorWorkoutPlan> planos) {
    final informado = widget.studentName?.trim() ?? '';
    if (informado.isNotEmpty) return informado;
    for (final p in planos) {
      if (p.studentName.trim().isNotEmpty) return p.studentName.trim();
    }
    return 'Aluno';
  }

  Future<void> _atualizar() async {
    final provider = studentPlansProvider(widget.studentId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // A falha já aparece no estado de erro da tela.
    }
  }

  Future<void> _abrirEditor(
    List<InstructorWorkoutPlan> planos, {
    InstructorWorkoutPlan? plan,
  }) async {
    // `?plano=` deixa a edição sobreviver a um refresh no web (o `extra` se
    // perde); o editor recarrega a ficha pelo id nesse caso.
    final query = plan == null
        ? ''
        : '?plano=${Uri.encodeQueryComponent(plan.id)}';
    await context.push(
      '/instrutor/aluno/${widget.studentId}/ficha$query',
      extra: FichaEditorArgs(
        plan: plan,
        studentName: _nomeAluno(planos),
        usedLabels: [
          for (final p in planos)
            if (p.id != plan?.id) p.sheetLabel,
        ],
      ),
    );
  }

  Future<void> _excluir(InstructorWorkoutPlan plan) async {
    if (_excluindoId != null) return;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(instructorApiProvider);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir ficha?'),
        content: Text(
          'A ficha ${plan.sheetLabel} — ${plan.title} será excluída e o '
          'aluno deixará de vê-la em "Meu Treino".',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            // O tema dá largura infinita ao FilledButton (CTA de tela cheia);
            // numa linha de ações de diálogo ele precisa ser compacto.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 48),
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _excluindoId = plan.id);
    try {
      await api.deletePlan(plan.id);
      if (mounted) ref.invalidate(studentPlansProvider(widget.studentId));
      messenger.showSnackBar(const SnackBar(content: Text('Ficha excluída.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(e, fallback: 'Não foi possível excluir a ficha.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _excluindoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(studentPlansProvider(widget.studentId));
    final planos = _ordenar(plansAsync.valueOrNull ?? const []);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _nomeAluno(planos),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Fichas de treino',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(planos),
        icon: const Icon(Icons.add),
        label: const Text('Nova ficha'),
      ),
      body: InstructorContent(
        child: RefreshIndicator(
          onRefresh: _atualizar,
          child: plansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                InstructorMessage(
                  icon: Icons.error_outline,
                  isError: true,
                  message: mensagemDeErro(
                    e,
                    fallback: 'Não foi possível carregar as fichas.',
                  ),
                  actionLabel: 'Tentar novamente',
                  onAction: () =>
                      ref.invalidate(studentPlansProvider(widget.studentId)),
                ),
              ],
            ),
            data: (_) {
              if (planos.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    InstructorMessage(
                      icon: Icons.assignment_outlined,
                      message: 'Nenhuma ficha cadastrada.',
                      hint: 'Toque em "Nova ficha" para criar a primeira.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                // Folga no fim pra o FAB não cobrir as ações da última ficha.
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space16,
                  AppTheme.space16,
                  AppTheme.space16,
                  96,
                ),
                itemCount: planos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space12),
                itemBuilder: (context, i) {
                  final plan = planos[i];
                  return _FichaCard(
                    key: ValueKey(plan.id),
                    plan: plan,
                    busy: _excluindoId == plan.id,
                    onEdit: () => _abrirEditor(planos, plan: plan),
                    onDelete: () => _excluir(plan),
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

/// Ordem previsível na tela: A, B, C, D (e título como desempate).
List<InstructorWorkoutPlan> _ordenar(List<InstructorWorkoutPlan> planos) {
  return [...planos]..sort((a, b) {
    final porRotulo = a.sheetLabel.compareTo(b.sheetLabel);
    return porRotulo != 0 ? porRotulo : a.title.compareTo(b.title);
  });
}

class _FichaCard extends StatefulWidget {
  const _FichaCard({
    required this.plan,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final InstructorWorkoutPlan plan;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_FichaCard> createState() => _FichaCardState();
}

class _FichaCardState extends State<_FichaCard> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final validade = plan.validUntil;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _aberta = !_aberta),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: plan.active
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    foregroundColor: plan.active
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    child: Text(
                      plan.sheetLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.title, style: textTheme.titleMedium),
                        const SizedBox(height: AppTheme.space4),
                        Wrap(
                          spacing: AppTheme.space8,
                          runSpacing: AppTheme.space4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              rotuloExercicios(plan.exercises.length),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (!plan.active)
                              const InstructorBadge(label: 'inativa'),
                            if (validade != null)
                              InstructorBadge(
                                label:
                                    'válida até '
                                    '${DateFormat('dd/MM/yyyy').format(validade)}',
                                color: _vencida(validade) ? scheme.error : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Tooltip(
                    message: _aberta
                        ? 'Ocultar exercícios'
                        : 'Mostrar exercícios',
                    child: Icon(
                      _aberta ? Icons.expand_less : Icons.expand_more,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppTheme.motionBase,
            curve: AppTheme.easingStandard,
            alignment: Alignment.topCenter,
            child: _aberta
                ? _ExerciciosDaFicha(exercises: plan.exercises)
                : const SizedBox(width: double.infinity),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: widget.busy ? null : widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: AppTheme.space4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: scheme.error,
                  ),
                  onPressed: widget.busy ? null : widget.onDelete,
                  icon: widget.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _vencida(DateTime validade) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  return validade.isBefore(hoje);
}

class _ExerciciosDaFicha extends StatelessWidget {
  const _ExerciciosDaFicha({required this.exercises});

  final List<PlanExerciseItem> exercises;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space16,
          0,
          AppTheme.space16,
          AppTheme.space16,
        ),
        child: Text(
          'Nenhum exercício nesta ficha.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        0,
        AppTheme.space16,
        AppTheme.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, ex) in exercises.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: _ExercicioResumo(exercise: ex)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExercicioResumo extends StatelessWidget {
  const _ExercicioResumo({required this.exercise});

  final PlanExerciseItem exercise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prescricao = resumoPrescricao(exercise.sets, exercise.reps);
    final descanso = exercise.restSeconds;
    final notas = exercise.notes?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.exerciseName,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (prescricao != null || descanso != null) ...[
          const SizedBox(height: AppTheme.space4),
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space4,
            children: [
              if (prescricao != null) InstructorBadge(label: prescricao),
              if (descanso != null)
                InstructorBadge(label: 'descanso ${descanso}s'),
            ],
          ),
        ],
        if (notas.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            notas,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
