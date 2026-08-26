import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Hub da Academia (aluno): agenda, ficha, avisos e perfil. SPEC §10.4.
///
/// Grade de acesso rápido (cards verde-limão + selo dourado) — referência
/// visual de app institucional trazida pelo usuário.
class AcademiaHomeScreen extends StatefulWidget {
  const AcademiaHomeScreen({super.key});

  @override
  State<AcademiaHomeScreen> createState() => _AcademiaHomeScreenState();
}

class _AcademiaHomeScreenState extends State<AcademiaHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _items = [
    ('/academia/agenda', Icons.calendar_month_outlined, 'Minha Agenda'),
    ('/academia/treino', Icons.assignment_outlined, 'Meu Treino'),
    ('/academia/avisos', Icons.campaign_outlined, 'Avisos'),
    ('/academia/perfil', Icons.person_outline, 'Meu Perfil'),
  ];

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    // Entrada sutil (design-system.md §8): fade + leve subida, sem
    // bounce/elastic, escalonada por card pra guiar o olho pela grade.
    _entrance = AnimationController(vsync: this, duration: AppTheme.motionSlow)
      ..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academia')),
      body: GridView.count(
        padding: const EdgeInsets.all(AppTheme.space16),
        crossAxisCount: 2,
        mainAxisSpacing: AppTheme.space16,
        crossAxisSpacing: AppTheme.space16,
        childAspectRatio: 1.05,
        children: [
          for (final (index, item) in _items.indexed)
            _QuickTile(
              route: item.$1,
              icon: item.$2,
              label: item.$3,
              index: index,
              entrance: _entrance,
            ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.route,
    required this.icon,
    required this.label,
    required this.index,
    required this.entrance,
  });

  final String route;
  final IconData icon;
  final String label;
  final int index;
  final Animation<double> entrance;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Escalonamento: cada card começa sua janela de animação um pouco
    // depois do anterior, todos terminando dentro da mesma duração total.
    final start = (widget.index * 0.12).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: widget.entrance,
      curve: Interval(start, end, curve: AppTheme.easingStandard),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 12),
          child: child,
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppTheme.motionFast,
        curve: AppTheme.easingStandard,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Card(
            color: AppTheme.limeAccent,
            elevation: _hovered || _pressed ? 2 : 1,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(widget.route),
              onHighlightChanged: (v) => setState(() => _pressed = v),
              focusColor: AppTheme.onLimeAccent.withValues(alpha: 0.12),
              hoverColor: AppTheme.onLimeAccent.withValues(alpha: 0.08),
              splashColor: AppTheme.onLimeAccent.withValues(alpha: 0.12),
              highlightColor: AppTheme.onLimeAccent.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.secondary,
                      foregroundColor: scheme.onSecondary,
                      child: Icon(widget.icon, size: 18),
                    ),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.onLimeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
