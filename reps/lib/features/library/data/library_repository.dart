import 'dart:async';
import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/exercise.dart';
import '../domain/exercise_classifier.dart';
import 'exercises_seed.dart';

/// Repositorio da biblioteca de exercicios.
///
/// Fonte canonica: 100 exercicios definidos em [exercisesSeed].
/// Em runtime, tenta carregar `assets/exercises_extended.json` (gerado pelo
/// script `tool/fetch_extended_exercises.ps1`) para somar mais ~300 exercicios
/// vindos da ExerciseDB com nomes ja em pt-BR.
///
/// Tudo em memoria; o repositorio expoe APIs sincronas e usa `_extended`
/// uma vez que ele tenha sido carregado.
class LibraryRepository {
  LibraryRepository();

  static const _ns = 'seed';
  static const _extNs = 'extdb';

  // Estado de instancia (4.2): antes era `static`, persistindo entre testes e
  // entre execucoes. Agora cada instancia (uma por ProviderContainer) tem o seu.
  List<Exercise>? _extended;
  Future<void>? _loading;

  /// Indice memoizado slug->Exercise para findBySlug O(1). Construido uma vez
  /// (extended primeiro, seed por ultimo para vencer). Invalidado quando
  /// `_extended` muda (fim de `_loadExtended`). Custom NAO entra (comportamento
  /// preservado). Ver `all()` para a lista completa incluindo custom.
  Map<String, Exercise>? _bySlug;

  Map<String, Exercise> get _index {
    return _bySlug ??= {
      for (final e in (_extended ?? const <Exercise>[])) e.slug: e,
      for (final r in exercisesSeed) r.slug: _toExercise(r), // seed vence
    };
  }

  /// Dispara a carga (se ainda nao feita) e aguarda concluir.
  Future<void> ensureLoaded() async {
    _loading ??= _loadExtended();
    await _loading;
  }

  Future<void> _loadExtended() async {
    try {
      final raw = await rootBundle.loadString('assets/exercises_extended.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final canonicalSlugs = exercisesSeed.map((s) => s.slug).toSet();
      final parsed = <Exercise>[];
      for (final j in list) {
        final m = j as Map<String, dynamic>;
        final slug = m['slug'] as String? ?? '';
        if (slug.isEmpty || canonicalSlugs.contains(slug)) continue;
        final grupo =
            GrupoMuscular.fromString(m['grupo'] as String?) ??
            GrupoMuscular.core;
        final padrao =
            PadraoMovimento.fromString(m['padrao'] as String?) ??
            PadraoMovimento.isolador;
        final equip =
            Equipamento.fromString(m['equipamento'] as String?) ??
            Equipamento.peso_corporal;
        parsed.add(
          Exercise(
            id: '$_extNs:$slug',
            slug: slug,
            nome: (m['nome'] as String?) ?? slug,
            descricao: (m['descricao'] as String?) ?? '',
            grupoPrimario: grupo,
            gruposSecundarios: const [],
            padraoMovimento: padrao,
            equipamento: equip,
          ),
        );
      }
      _extended = parsed;
      if (kDebugMode) {
        // ignore: avoid_print
        print('[library] extended seed carregado: ${parsed.length} exercicios');
      }
    } on FlutterError {
      // Asset nao existe (script ainda nao foi rodado). Tudo bem.
      _extended = const [];
    } on Object catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[library] falha lendo exercises_extended.json: $e');
      }
      _extended = const [];
    } finally {
      // `_extended` mudou: invalida o indice para reconstruir com extended.
      _bySlug = null;
    }
  }

  List<Exercise> _custom = const [];

  void updateCustom(List<Exercise> list) {
    _custom = list;
  }

  List<Exercise> all() {
    final canonical = exercisesSeed.map(_toExercise).toList(growable: false);
    final ext = _extended ?? const <Exercise>[];
    return [...canonical, ...ext, ..._custom];
  }

  List<Exercise> search({
    String? termo,
    Set<GrupoMuscular> grupos = const {},
    Set<PadraoMovimento> padroes = const {},
    Set<Equipamento> equipamentos = const {},
  }) {
    final tokens = _tokenize(termo);
    return all()
        .where((e) {
          if (tokens.isNotEmpty) {
            final hay = _haystack(e);
            if (!tokens.every((t) => hay.contains(t))) return false;
          }
          if (grupos.isNotEmpty && !grupos.contains(e.grupoPrimario)) {
            return false;
          }
          if (padroes.isNotEmpty && !padroes.contains(e.padraoMovimento)) {
            return false;
          }
          if (equipamentos.isNotEmpty &&
              !equipamentos.contains(e.equipamento)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Tokens normalizados sem acentos. Multi-palavra = AND implicito.
  List<String> _tokenize(String? termo) {
    if (termo == null || termo.trim().isEmpty) return const [];
    return _fold(
      termo,
    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(growable: false);
  }

  /// Haystack inclui nome, descricao, grupo primario, grupos secundarios,
  /// equipamento e padrao de movimento — tudo normalizado sem acentos.
  String _haystack(Exercise e) {
    return _fold(
      [
        e.nome,
        e.descricao,
        e.slug,
        e.grupoPrimario.name,
        e.grupoPrimario.label,
        ...e.gruposSecundarios.map((g) => g.name),
        ...e.gruposSecundarios.map((g) => g.label),
        e.equipamento.name,
        e.equipamento.label,
        e.padraoMovimento.name,
        e.padraoMovimento.label,
      ].join(' '),
    );
  }

  /// Normaliza para lowercase e remove acentos (pacote `diacritic` — cobre
  /// todo o Latin-1, não só os acentos pt-BR que estavam hardcoded).
  String _fold(String s) => removeDiacritics(s.toLowerCase());

  Exercise? findBySlug(String slug) => _index[slug];

  Exercise _toExercise(SeedRow r) {
    return Exercise(
      id: '$_ns:${r.slug}',
      slug: r.slug,
      nome: r.nome,
      descricao: r.descricao,
      grupoPrimario: r.grupoPrimario,
      gruposSecundarios: r.gruposSecundarios,
      padraoMovimento: r.padrao,
      equipamento: r.equipamento,
      nivelTecnico: ExerciseClassifier.classificarNivel(
        slug: r.slug,
        padrao: r.padrao,
        equipamento: r.equipamento,
      ),
      // Apenas os 100 canonicos entram na recomendacao automatica (v1).
      recomendavel: true,
      medidaPorTempo: r.medidaPorTempo,
    );
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});
