import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../data/instructor_api.dart';
import '../data/instructor_providers.dart';
import 'exercise_picker_sheet.dart';
import 'widgets/instructor_widgets.dart';

/// Dados passados pela tela de fichas ao abrir o editor (`extra` da rota).
class FichaEditorArgs {
  const FichaEditorArgs({
    this.plan,
    this.usedLabels = const [],
    this.studentName,
  });

  /// Ficha a editar; `null` = criar uma nova.
  final InstructorWorkoutPlan? plan;

  /// Rótulos (A–D) já usados pelas OUTRAS fichas do aluno — define o rótulo
  /// padrão de uma ficha nova e o aviso de rótulo repetido.
  final List<String> usedLabels;

  final String? studentName;
}

/// Criação/edição de uma ficha de treino do aluno [studentId].
///
/// Com [args] (navegação normal) o formulário abre na hora. Sem [args] — a
/// página foi recarregada no Flutter web e o `extra` da rota se perdeu — as
/// fichas do aluno são buscadas de novo: [planId] (query `?plano=`) diz qual
/// editar; sem ele, é uma ficha nova.
class FichaEditorScreen extends ConsumerStatefulWidget {
  const FichaEditorScreen({
    required this.studentId,
    this.args,
    this.planId,
    super.key,
  });

  final String studentId;
  final FichaEditorArgs? args;
  final String? planId;

  @override
  ConsumerState<FichaEditorScreen> createState() => _FichaEditorScreenState();
}

class _FichaEditorScreenState extends ConsumerState<FichaEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final List<_ItemForm> _itens = [];

  InstructorWorkoutPlan? _plan;
  List<String> _rotulosUsados = const [];
  String _rotulo = sheetLabels.first;
  bool _ativa = true;
  DateTime? _validade;

  bool _pronto = false;
  bool _naoEncontrada = false;
  Object? _erroCarga;
  bool _salvando = false;
  bool _semExercicios = false;

  /// Falha da última tentativa de salvar (validação ou resposta do backend).
  /// Fica no rodapé, acima do botão — um SnackBar flutuante cobriria
  /// justamente o "Salvar ficha" na hora de tentar de novo.
  String? _erroAoSalvar;

  /// Depois da primeira tentativa de salvar com erro, os campos passam a se
  /// revalidar enquanto o instrutor corrige — o aviso some assim que o campo
  /// fica válido, sem esperar um novo toque em "Salvar ficha".
  bool _tentouSalvar = false;
  static const _avisoRevisar = 'Revise os campos destacados.';

  void _limparAvisoDeRevisao() {
    if (_erroAoSalvar == _avisoRevisar) setState(() => _erroAoSalvar = null);
  }

  bool get _editando => _plan != null;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null) {
      _iniciar(plan: args.plan, rotulosUsados: args.usedLabels);
    } else {
      _carregarFichas();
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    for (final item in _itens) {
      item.dispose();
    }
    super.dispose();
  }

  void _iniciar({
    required InstructorWorkoutPlan? plan,
    required List<String> rotulosUsados,
  }) {
    _plan = plan;
    _rotulosUsados = rotulosUsados;
    _tituloCtrl.text = plan?.title ?? '';
    _ativa = plan?.active ?? true;
    _validade = plan?.validUntil;
    if (plan != null && sheetLabels.contains(plan.sheetLabel)) {
      _rotulo = plan.sheetLabel;
    } else {
      // Ficha nova: primeiro rótulo ainda livre (todas usadas → A).
      _rotulo = sheetLabels.firstWhere(
        (l) => !rotulosUsados.contains(l),
        orElse: () => sheetLabels.first,
      );
    }
    _itens.addAll([
      for (final e in plan?.exercises ?? const <PlanExerciseItem>[])
        _ItemForm.fromItem(e),
    ]);
    _pronto = true;
  }

  /// Sem `extra` (refresh no web): busca as fichas direto na API — não pelo
  /// provider, que é autoDispose e não tem quem o mantenha vivo aqui.
  Future<void> _carregarFichas() async {
    if (_erroCarga != null) setState(() => _erroCarga = null);
    try {
      final planos = await ref
          .read(instructorApiProvider)
          .studentPlans(widget.studentId);
      if (!mounted) return;
      final id = widget.planId;
      final plan = id == null
          ? null
          : planos.where((p) => p.id == id).firstOrNull;
      setState(() {
        if (id != null && plan == null) {
          _naoEncontrada = true;
          return;
        }
        _iniciar(
          plan: plan,
          rotulosUsados: [
            for (final p in planos)
              if (p.id != id) p.sheetLabel,
          ],
        );
      });
    } catch (e) {
      if (mounted) setState(() => _erroCarga = e);
    }
  }

  void _voltarParaFichas() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Aberta direto pela URL: não há tela anterior na pilha.
      context.go('/instrutor/aluno/${widget.studentId}');
    }
  }

  Future<void> _escolherValidade() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final atual = _validade;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual ?? hoje,
      // Validade já vencida continua editável (firstDate não pode ser
      // posterior a initialDate).
      firstDate: atual != null && atual.isBefore(hoje) ? atual : hoje,
      lastDate: DateTime(hoje.year + 5, hoje.month, hoje.day),
      // O app não carrega flutter_localizations: os rótulos do seletor que
      // dá pra traduzir por parâmetro vão em pt-BR aqui.
      helpText: 'Válida até',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      fieldLabelText: 'Data',
      errorFormatText: 'Data inválida.',
      errorInvalidText: 'Data fora do período permitido.',
    );
    if (escolhida != null && mounted) setState(() => _validade = escolhida);
  }

  Future<void> _adicionarExercicios() async {
    final escolhidos = await showExercisePicker(
      context,
      jaNaFicha: {for (final item in _itens) ?item.exerciseId},
    );
    if (escolhidos == null || escolhidos.isEmpty || !mounted) return;
    setState(() {
      _itens.addAll(escolhidos.map(_ItemForm.fromCatalog));
      _semExercicios = false;
      if (_erroAoSalvar == _avisoRevisar) _erroAoSalvar = null;
    });
  }

  void _removerExercicio(_ItemForm item) {
    setState(() => _itens.remove(item));
    // Os campos ainda usam os controllers até o próximo frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  void _reordenar(int de, int para) {
    setState(() => _itens.insert(para, _itens.removeAt(de)));
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final camposOk = _formKey.currentState?.validate() ?? false;
    // Não depende só dos validators dos campos: confere os números direto
    // nos controllers, caso algum campo não esteja construído.
    final numerosOk = _itens.every((i) => i.numerosValidos);
    final temExercicio = _itens.isNotEmpty;
    final messenger = ScaffoldMessenger.of(context);
    if (!camposOk || !numerosOk || !temExercicio) {
      setState(() {
        _tentouSalvar = true;
        _semExercicios = !temExercicio;
        _erroAoSalvar = _avisoRevisar;
      });
      return;
    }

    final plan = _plan;
    final payload = WorkoutPlanPayload(
      studentId: widget.studentId,
      sheetLabel: _rotulo,
      title: _tituloCtrl.text.trim(),
      active: _ativa,
      validUntil: _validade,
      exercises: [for (final item in _itens) item.toItem()],
    );
    final api = ref.read(instructorApiProvider);

    setState(() {
      _salvando = true;
      _semExercicios = false;
      _erroAoSalvar = null;
    });
    try {
      if (plan == null) {
        await api.createPlan(payload);
      } else {
        await api.updatePlan(plan.id, payload);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erroAoSalvar = mensagemDeErro(
          e,
          fallback: 'Não foi possível salvar a ficha.',
        );
      });
      return;
    }
    // Sucesso: `_salvando` fica ligado até a tela fechar (sem envio duplo).
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(plan == null ? 'Ficha criada.' : 'Ficha atualizada.'),
        ),
      );
    if (!mounted) return;
    ref.invalidate(studentPlansProvider(widget.studentId));
    _voltarParaFichas();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aluno = widget.args?.studentName?.trim() ?? '';
    final titulo = !_pronto && widget.planId != null
        ? 'Editar ficha'
        : (_editando ? 'Editar ficha' : 'Nova ficha');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo),
            if (aluno.isNotEmpty)
              Text(
                aluno,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: SafeArea(child: InstructorContent(child: _corpo())),
    );
  }

  Widget _corpo() {
    if (_naoEncontrada) {
      return SingleChildScrollView(
        child: InstructorMessage(
          icon: Icons.assignment_late_outlined,
          message: 'Ficha não encontrada.',
          hint: 'Ela pode ter sido excluída.',
          actionLabel: 'Ver fichas do aluno',
          onAction: () => context.go('/instrutor/aluno/${widget.studentId}'),
        ),
      );
    }
    if (_erroCarga != null) {
      return SingleChildScrollView(
        child: InstructorMessage(
          icon: Icons.error_outline,
          isError: true,
          message: mensagemDeErro(
            _erroCarga,
            fallback: 'Não foi possível carregar a ficha.',
          ),
          actionLabel: 'Tentar novamente',
          onAction: _carregarFichas,
        ),
      );
    }
    if (!_pronto) return const Center(child: CircularProgressIndicator());

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Form(
              key: _formKey,
              autovalidateMode: _tentouSalvar
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              onChanged: _limparAvisoDeRevisao,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _tituloCtrl,
                    enabled: !_salvando,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ex.: Peito e tríceps',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o título da ficha.'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.space20),
                  Text('Ficha', style: textTheme.titleSmall),
                  const SizedBox(height: AppTheme.space8),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    showSelectedIcon: false,
                    // Ocupa a largura toda: alvos de toque maiores no celular.
                    expandedInsets: EdgeInsets.zero,
                    segments: [
                      for (final l in sheetLabels)
                        ButtonSegment(value: l, label: Text(l)),
                    ],
                    selected: {_rotulo},
                    onSelectionChanged: _salvando
                        ? null
                        : (s) => setState(() => _rotulo = s.first),
                  ),
                  if (_rotulosUsados.contains(_rotulo)) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'O aluno já tem outra ficha $_rotulo.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Ativa'),
                          subtitle: const Text(
                            'Fichas inativas não aparecem para o aluno.',
                          ),
                          value: _ativa,
                          onChanged: _salvando
                              ? null
                              : (v) => setState(() => _ativa = v),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.event_outlined),
                          title: const Text('Válida até'),
                          subtitle: Text(
                            _validade == null
                                ? 'Sem data de validade'
                                : DateFormat('dd/MM/yyyy').format(_validade!),
                          ),
                          trailing: _validade == null
                              ? Icon(
                                  Icons.chevron_right,
                                  color: scheme.onSurfaceVariant,
                                )
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remover validade',
                                  onPressed: _salvando
                                      ? null
                                      : () => setState(() => _validade = null),
                                ),
                          onTap: _salvando ? null : _escolherValidade,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Exercícios', style: textTheme.titleLarge),
                      ),
                      if (_itens.isNotEmpty)
                        Text(
                          rotuloExercicios(_itens.length),
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  if (_itens.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space12),
                      child: Text(
                        _semExercicios
                            ? 'Adicione pelo menos um exercício.'
                            : 'Nenhum exercício adicionado ainda.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: _semExercicios
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...[
                    if (_itens.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space8),
                        child: Text(
                          'Arraste pela alça para mudar a ordem.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorderItem: _reordenar,
                      children: [
                        for (final (i, item) in _itens.indexed)
                          _ExercicioCard(
                            key: item.key,
                            index: i,
                            item: item,
                            enabled: !_salvando,
                            onRemove: () => _removerExercicio(item),
                          ),
                      ],
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _salvando ? null : _adicionarExercicios,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar exercício'),
                  ),
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_erroAoSalvar != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 18, color: scheme.error),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Text(
                          _erroAoSalvar!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space12),
                ],
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar ficha'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado de edição de um exercício da ficha (um controller por campo).
class _ItemForm {
  _ItemForm({
    required this.exerciseId,
    required this.exerciseName,
    int? sets,
    String? reps,
    int? restSeconds,
    String? notes,
  }) : setsCtrl = TextEditingController(text: sets?.toString() ?? ''),
       repsCtrl = TextEditingController(text: reps ?? ''),
       restCtrl = TextEditingController(text: restSeconds?.toString() ?? ''),
       notesCtrl = TextEditingController(text: notes ?? '');

  factory _ItemForm.fromItem(PlanExerciseItem e) => _ItemForm(
    exerciseId: e.exerciseId,
    exerciseName: e.exerciseName,
    sets: e.sets,
    reps: e.reps,
    restSeconds: e.restSeconds,
    notes: e.notes,
  );

  factory _ItemForm.fromCatalog(CatalogExercise e) =>
      _ItemForm(exerciseId: e.id, exerciseName: e.name);

  /// Identidade estável do item na lista reordenável.
  final Key key = UniqueKey();
  final String? exerciseId;
  final String exerciseName;
  final TextEditingController setsCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController restCtrl;
  final TextEditingController notesCtrl;

  bool get numerosValidos =>
      validarInteiro(setsCtrl.text) == null &&
      validarInteiro(restCtrl.text) == null;

  PlanExerciseItem toItem() => PlanExerciseItem(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    sets: int.tryParse(setsCtrl.text.trim()),
    reps: _textoOuNull(repsCtrl.text),
    restSeconds: int.tryParse(restCtrl.text.trim()),
    notes: _textoOuNull(notesCtrl.text),
  );

  void dispose() {
    setsCtrl.dispose();
    repsCtrl.dispose();
    restCtrl.dispose();
    notesCtrl.dispose();
  }
}

String? _textoOuNull(String v) {
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Campo numérico opcional: vazio é válido; preenchido, tem de ser um inteiro
/// não negativo.
@visibleForTesting
String? validarInteiro(String? valor) {
  final t = valor?.trim() ?? '';
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  return (n == null || n < 0) ? 'Número inválido' : null;
}

class _ExercicioCard extends StatelessWidget {
  const _ExercicioCard({
    required this.index,
    required this.item,
    required this.enabled,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _ItemForm item;
  final bool enabled;
  final VoidCallback onRemove;

  /// A partir desta largura os três campos curtos cabem numa linha só.
  static const _larguraTresColunas = 480.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final series = TextFormField(
      controller: item.setsCtrl,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: const InputDecoration(labelText: 'Séries', isDense: true),
      validator: validarInteiro,
    );
    final repeticoes = TextFormField(
      controller: item.repsCtrl,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      inputFormatters: [LengthLimitingTextInputFormatter(40)],
      decoration: const InputDecoration(
        labelText: 'Repetições',
        hintText: 'Ex.: 10-12',
        isDense: true,
      ),
    );
    final descanso = TextFormField(
      controller: item.restCtrl,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: const InputDecoration(
        labelText: 'Descanso (s)',
        hintText: 'Em segundos',
        isDense: true,
      ),
      validator: validarInteiro,
    );
    final observacoes = TextFormField(
      controller: item.notesCtrl,
      enabled: enabled,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [LengthLimitingTextInputFormatter(300)],
      decoration: const InputDecoration(
        labelText: 'Observações',
        isDense: true,
      ),
    );
    const gap = SizedBox(width: AppTheme.space8, height: AppTheme.space8);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    enabled: enabled,
                    child: Tooltip(
                      message: 'Arrastar para reordenar',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.drag_indicator,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${index + 1}. ${item.exerciseName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: scheme.error,
                    tooltip: 'Remover exercício',
                    onPressed: enabled ? onRemove : null,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final largo = constraints.maxWidth >= _larguraTresColunas;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: series),
                            gap,
                            Expanded(flex: 3, child: repeticoes),
                            if (largo) ...[
                              gap,
                              Expanded(flex: 3, child: descanso),
                            ],
                          ],
                        ),
                        if (!largo) ...[gap, descanso],
                        gap,
                        observacoes,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
