import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../recommender/presentation/gerar_treino_sheet.dart';
import '../data/home_stats_provider.dart';
import '../data/routine_providers.dart';
import 'routine_create_sheet.dart';
part 'widgets/routines_screen_widgets.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final routines = ref.watch(routinesAtivasProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: const Text('NOVA ROTINA'),
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
                      children: [
                        Text(
                          'Treinos',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const Spacer(),
                        // Botao tonal (nao so um icone solto): sinaliza que
                        // "gerar treino" e uma acao com peso proprio (IA),
                        // sem competir com o titulo pela hierarquia (§1).
                        IconButton(
                          icon: const Icon(Icons.auto_awesome),
                          tooltip: 'Gerar treino',
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            backgroundColor: scheme.surface,
                            builder: (_) => const GerarTreinoSheet(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HomeStatsBanner(),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'SEMANA'),
                  Tab(text: 'AVULSOS'),
                ],
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.label,
              ),
              Expanded(
                child: routines.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (list) {
                    final fixos = list.where((r) => r.tipo == 'fixo').toList();
                    final avulsos = list
                        .where((r) => r.tipo == 'avulso')
                        .toList();
                    return TabBarView(
                      // Desabilita swipe entre tabs - troca so via clique
                      // na aba. Libera o gesto de swipe para acionar acoes
                      // na linha do card (editar/excluir).
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _RoutinesList(rows: fixos, isFixo: true),
                        _RoutinesList(rows: avulsos, isFixo: false),
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

  Future<void> _create(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const RoutineCreateSheet(),
    );
  }
}
