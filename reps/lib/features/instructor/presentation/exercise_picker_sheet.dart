import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../data/instructor_api.dart';
import '../data/instructor_providers.dart';
import 'widgets/instructor_widgets.dart';

/// Abre o seletor de exercícios do catálogo. Devolve os exercícios marcados,
/// na ordem em que foram escolhidos (`null` se o seletor for fechado).
///
/// [jaNaFicha] = ids do catálogo que já estão na ficha em edição; só
/// sinaliza na lista (repetir um exercício na mesma ficha é permitido).
Future<List<CatalogExercise>?> showExercisePicker(
  BuildContext context, {
  Set<String> jaNaFicha = const {},
}) {
  return showModalBottomSheet<List<CatalogExercise>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // No web/desktop a folha não estica de borda a borda.
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ExercisePickerSheet(jaNaFicha: jaNaFicha),
  );
}

/// Catálogo de exercícios com busca, filtro por grupo muscular (grupos
/// derivados do próprio catálogo) e seleção múltipla.
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({this.jaNaFicha = const {}, super.key});

  final Set<String> jaNaFicha;

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _busca = '';
  String? _grupo;
  final List<CatalogExercise> _selecionados = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _selecionado(CatalogExercise e) =>
      _selecionados.any((s) => s.id == e.id);

  void _alternar(CatalogExercise e) {
    setState(() {
      if (_selecionado(e)) {
        _selecionados.removeWhere((s) => s.id == e.id);
      } else {
        _selecionados.add(e);
      }
    });
  }

  List<CatalogExercise> _filtrar(List<CatalogExercise> catalogo) {
    final termo = _normalizar(_busca);
    return catalogo.where((e) {
      if (_grupo != null && e.muscleGroup != _grupo) return false;
      return termo.isEmpty || _normalizar(e.name).contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(exerciseCatalogProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space16,
                0,
                AppTheme.space16,
                AppTheme.space12,
              ),
              child: Text('Adicionar exercícios', style: textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _busca = v),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Buscar exercício',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  suffixIcon: _busca.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _busca = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: catalogAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SingleChildScrollView(
                  child: InstructorMessage(
                    icon: Icons.error_outline,
                    isError: true,
                    message: mensagemDeErro(
                      e,
                      fallback: 'Não foi possível carregar os exercícios.',
                    ),
                    actionLabel: 'Tentar novamente',
                    onAction: () => ref.invalidate(exerciseCatalogProvider),
                  ),
                ),
                data: _lista,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: FilledButton(
                  onPressed: _selecionados.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                          List<CatalogExercise>.unmodifiable(_selecionados),
                        ),
                  child: Text(
                    _selecionados.isEmpty
                        ? 'Selecione os exercícios'
                        : 'Adicionar (${_selecionados.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<CatalogExercise> catalogo) {
    if (catalogo.isEmpty) {
      return const SingleChildScrollView(
        child: InstructorMessage(
          icon: Icons.fitness_center_outlined,
          message: 'Nenhum exercício no catálogo.',
          hint: 'Peça à administração da academia para cadastrar exercícios.',
        ),
      );
    }
    final grupos = {
      for (final e in catalogo)
        if (e.muscleGroup != null) e.muscleGroup!,
    }.toList()..sort((a, b) => _normalizar(a).compareTo(_normalizar(b)));
    final filtrados = _filtrar(catalogo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (grupos.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space4,
              ),
              children: [
                _GrupoChip(
                  label: 'Todos',
                  selected: _grupo == null,
                  onSelected: () => setState(() => _grupo = null),
                ),
                for (final g in grupos)
                  _GrupoChip(
                    label: _capitalizar(g),
                    selected: _grupo == g,
                    onSelected: () => setState(() => _grupo = g),
                  ),
              ],
            ),
          ),
        Expanded(
          child: filtrados.isEmpty
              ? const SingleChildScrollView(
                  child: InstructorMessage(
                    icon: Icons.search_off,
                    message: 'Nenhum exercício encontrado.',
                    hint: 'Tente outro nome ou outro grupo muscular.',
                  ),
                )
              : ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final e = filtrados[i];
                    final detalhes = [
                      if (e.muscleGroup != null) _capitalizar(e.muscleGroup!),
                      ?e.equipment,
                      if (widget.jaNaFicha.contains(e.id)) 'já na ficha',
                    ].join(' · ');
                    return CheckboxListTile(
                      value: _selecionado(e),
                      onChanged: (_) => _alternar(e),
                      title: Text(e.name),
                      subtitle: detalhes.isEmpty ? null : Text(detalhes),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GrupoChip extends StatelessWidget {
  const _GrupoChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

/// Busca sem diferenciar maiúsculas nem acentos ("triceps" acha "Tríceps").
String _normalizar(String s) => removeDiacritics(s.trim().toLowerCase());

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
