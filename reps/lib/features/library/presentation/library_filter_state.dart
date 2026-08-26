import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/exercise.dart';

@immutable
class LibraryFilter {
  const LibraryFilter({
    this.termo = '',
    this.grupos = const {},
    this.padroes = const {},
    this.equipamentos = const {},
  });

  final String termo;
  final Set<GrupoMuscular> grupos;
  final Set<PadraoMovimento> padroes;
  final Set<Equipamento> equipamentos;

  bool get isEmpty =>
      termo.isEmpty &&
      grupos.isEmpty &&
      padroes.isEmpty &&
      equipamentos.isEmpty;

  LibraryFilter copyWith({
    String? termo,
    Set<GrupoMuscular>? grupos,
    Set<PadraoMovimento>? padroes,
    Set<Equipamento>? equipamentos,
  }) {
    return LibraryFilter(
      termo: termo ?? this.termo,
      grupos: grupos ?? this.grupos,
      padroes: padroes ?? this.padroes,
      equipamentos: equipamentos ?? this.equipamentos,
    );
  }
}

class LibraryFilterController extends StateNotifier<LibraryFilter> {
  LibraryFilterController() : super(const LibraryFilter());

  void setTermo(String value) => state = state.copyWith(termo: value);

  void toggleGrupo(GrupoMuscular g) {
    final next = {...state.grupos};
    if (!next.add(g)) {
      next.remove(g);
    }
    state = state.copyWith(grupos: next);
  }

  void togglePadrao(PadraoMovimento p) {
    final next = {...state.padroes};
    if (!next.add(p)) {
      next.remove(p);
    }
    state = state.copyWith(padroes: next);
  }

  void toggleEquipamento(Equipamento e) {
    final next = {...state.equipamentos};
    if (!next.add(e)) {
      next.remove(e);
    }
    state = state.copyWith(equipamentos: next);
  }

  void clear() => state = const LibraryFilter();
}

final libraryFilterProvider =
    StateNotifierProvider<LibraryFilterController, LibraryFilter>((ref) {
      return LibraryFilterController();
    });
