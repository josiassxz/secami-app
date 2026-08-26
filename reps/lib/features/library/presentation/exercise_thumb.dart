import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/entities/exercise.dart';

/// Thumbnail do exercicio.
///
/// Quando o GIF existe (asset com bytes), exibe. Senao, mostra um bloco
/// editorial com o glyph de grupo muscular - assertivo, sem aparência de
/// "placeholder vazio". Combina com a estetica brutalist do tema.
///
/// [expandable]: toque abre o GIF ampliado num dialog (pinch pra zoom, toque
/// fecha). Opt-in porque em listas o toque do tile ja tem acao propria.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({
    required this.exercise,
    this.size = 64,
    this.expandable = false,
    super.key,
  });

  final Exercise exercise;
  final double size;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists(exercise.assetPath),
      builder: (context, snap) {
        final exists = snap.data == true;
        if (!exists) return _fallback(context);
        final img = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            exercise.assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          ),
        );
        if (!expandable) return img;
        return GestureDetector(onTap: () => _showExpanded(context), child: img);
      },
    );
  }

  /// Dialog com o GIF ampliado. Pop sempre com o context do proprio dialog
  /// (ctx do builder) — pop com context de fora, dentro de ShellRoute do
  /// go_router, derruba a rota errada e da tela preta.
  void _showExpanded(BuildContext context) {
    final nome = exercise.nome;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              exercise.assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.broken_image_outlined,
                                size: 64,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = _colorFor(exercise.grupoPrimario);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Stack(
        children: [
          // Faixa lateral colorida (visual editorial — accent agudo)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: tint),
          ),
          // Glyph mono central
          Center(
            child: Text(
              _glyph(exercise.grupoPrimario),
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Paleta categorica suave (1 tom por grupo muscular) — tons medios e
  // dessaturados para casar com a identidade Casa Militar (SPEC §7: nada de
  // tons fortes/saturados), mantendo distincao visual entre os 10 grupos.
  static Color _colorFor(GrupoMuscular g) {
    switch (g) {
      case GrupoMuscular.peito:
        return const Color(0xFFC17B63);
      case GrupoMuscular.costas:
        return const Color(0xFF5C87AC);
      case GrupoMuscular.ombros:
        return const Color(0xFFC79A52);
      case GrupoMuscular.biceps:
        return const Color(0xFF9A7EB0);
      case GrupoMuscular.triceps:
        return const Color(0xFF7C8FC4);
      case GrupoMuscular.quadriceps:
        return const Color(0xFF5FA37D);
      case GrupoMuscular.posterior:
        return const Color(0xFF4F9C93);
      case GrupoMuscular.gluteos:
        return const Color(0xFFC1728F);
      case GrupoMuscular.panturrilha:
        return const Color(0xFF5FA8B5);
      case GrupoMuscular.core:
        return const Color(0xFFB79A56);
    }
  }

  /// Glyph curto pra cada grupo (max 2 chars).
  static String _glyph(GrupoMuscular g) {
    switch (g) {
      case GrupoMuscular.peito:
        return 'PT';
      case GrupoMuscular.costas:
        return 'CS';
      case GrupoMuscular.ombros:
        return 'OM';
      case GrupoMuscular.biceps:
        return 'BI';
      case GrupoMuscular.triceps:
        return 'TR';
      case GrupoMuscular.quadriceps:
        return 'QD';
      case GrupoMuscular.posterior:
        return 'PS';
      case GrupoMuscular.gluteos:
        return 'GL';
      case GrupoMuscular.panturrilha:
        return 'PN';
      case GrupoMuscular.core:
        return 'CR';
    }
  }
}

final _assetExistenceCache = <String, bool>{};

Future<bool> _assetExists(String path) async {
  final cached = _assetExistenceCache[path];
  if (cached != null) return cached;
  try {
    final data = await rootBundle.load(path);
    final exists = data.lengthInBytes > 0;
    _assetExistenceCache[path] = exists;
    return exists;
  } on Exception {
    _assetExistenceCache[path] = false;
    return false;
  } on Error {
    _assetExistenceCache[path] = false;
    return false;
  }
}

Future<void> warmupAssetCache(Iterable<String> paths) async {
  for (final p in paths) {
    if (!_assetExistenceCache.containsKey(p)) {
      unawaited(_assetExists(p));
    }
  }
}
