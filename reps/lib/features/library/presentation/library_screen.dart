import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/exercise_id.dart';
import '../data/custom_exercise_providers.dart';
import '../data/library_repository.dart';
import '../../../domain/entities/exercise.dart';
import 'custom_exercise_form_sheet.dart';
import 'exercise_detail_sheet.dart';
import 'exercise_thumb.dart';
import 'library_filter_state.dart';
part 'widgets/library_screen_widgets.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(libraryFilterProvider.notifier).setTermo(value);
    });
  }

  Future<void> _openForm({String? editId, String? initialNome}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) =>
          CustomExerciseFormSheet(editId: editId, initialNome: initialNome),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(libraryRepositoryProvider);
    final filter = ref.watch(libraryFilterProvider);
    // Sincroniza exercicios personalizados do DB com o repositorio em memoria.
    ref.watch(customExercisesSyncProvider);

    final results = repo.search(
      termo: filter.termo,
      grupos: filter.grupos,
      padroes: filter.padroes,
      equipamentos: filter.equipamentos,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Novo exercício',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header editorial
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Biblioteca',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${results.length} de ${repo.all().length}',
                          style: AppTheme.mono(
                            13,
                          ).copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const Spacer(),
                      if (!filter.isEmpty)
                        TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(libraryFilterProvider.notifier).clear();
                          },
                          child: Text(
                            'limpar',
                            style: AppTheme.label(11, color: scheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EXERCICIOS CURADOS · POR GRUPO · POR MOVIMENTO',
                    style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar exercício…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            _FilterStrip(filter: filter),
            Expanded(
              child: results.isEmpty
                  ? _EmptyState(
                      hasFilter: !filter.isEmpty,
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(libraryFilterProvider.notifier).clear();
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: scheme.outline),
                      itemBuilder: (context, i) {
                        final ex = results[i];
                        return _ExerciseTile(exercise: ex, index: i);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
