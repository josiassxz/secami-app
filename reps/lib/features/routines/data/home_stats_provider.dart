import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../domain/usecases/volume_aggregator.dart';
import '../../auth/data/auth_providers.dart';

class HomeStats {
  const HomeStats({
    required this.treinsEstaSemana,
    required this.streakDias,
    required this.volumeEstaSemana,
    required this.volumeSemanaAnterior,
  });

  final int treinsEstaSemana;
  final int streakDias;
  final double volumeEstaSemana;
  final double volumeSemanaAnterior;

  double? get diffPct {
    if (volumeSemanaAnterior == 0) return null;
    return ((volumeEstaSemana - volumeSemanaAnterior) / volumeSemanaAnterior) *
        100;
  }
}

final homeStatsProvider = FutureProvider.autoDispose<HomeStats>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final mondayPrev = monday.subtract(const Duration(days: 7));

  final sessions = await db.sessionDao.watchByUser(userId).first;
  final sessionById = {for (final s in sessions) s.id: s};

  // --- Volume esta semana vs anterior ---
  // Batch unico de set_logs (sem N+1) + agregador de volume compartilhado.
  final logs = await db.setLogDao.ofSessions(
    sessions.map((s) => s.id).toList(),
  );
  // Janela [monday, today+1d) reproduz o filtro por dia truncado
  // (d >= monday && d <= today) do codigo anterior.
  final volAtual = volumeExecutado(
    logs: logs,
    sessionById: sessionById,
    from: monday,
    to: today.add(const Duration(days: 1)),
  );
  final volAnterior = volumeExecutado(
    logs: logs,
    sessionById: sessionById,
    from: mondayPrev,
    to: monday,
  );

  var treinsEstaSemana = 0;
  for (final s in sessions) {
    final d = DateTime(s.iniciadoEm.year, s.iniciadoEm.month, s.iniciadoEm.day);
    if (!d.isBefore(monday) && !d.isAfter(today)) treinsEstaSemana++;
  }

  // --- Streak: dias consecutivos ate hoje com pelo menos 1 sessao ---
  final diasComTreino = sessions
      .map(
        (s) =>
            DateTime(s.iniciadoEm.year, s.iniciadoEm.month, s.iniciadoEm.day),
      )
      .toSet();

  var streak = 0;
  var check = today;
  while (diasComTreino.contains(check)) {
    streak++;
    check = check.subtract(const Duration(days: 1));
  }
  // Se nao treinou hoje mas treinou ontem, conta a partir de ontem
  if (streak == 0) {
    check = today.subtract(const Duration(days: 1));
    while (diasComTreino.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
  }

  return HomeStats(
    treinsEstaSemana: treinsEstaSemana,
    streakDias: streak,
    volumeEstaSemana: volAtual,
    volumeSemanaAnterior: volAnterior,
  );
});
