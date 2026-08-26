import '../../data/local/database.dart';

/// Volume executado = Σ (carga_kg × reps) dos set_logs com executada=true,
/// filtrado por janela [from, to) sobre iniciado_em da sessão dona.
///
/// Definição única de "volume executado por janela" — home, insights e
/// records devem usar ESTA função em vez de recopiar a fórmula.
///
/// Semântica da janela: [from, to) — inclui `from`, exclui `to`.
/// Logs sem sessão em [sessionById], não executados, ou com carga/reps null
/// não contribuem.
double volumeExecutado({
  required Iterable<SetLogRow> logs,
  required Map<String, WorkoutSessionRow> sessionById,
  required DateTime from,
  required DateTime to,
}) {
  var total = 0.0;
  for (final l in logs) {
    if (!l.executada) continue;
    final sess = sessionById[l.sessionId];
    if (sess == null) continue;
    final ini = sess.iniciadoEm;
    if (ini.isBefore(from)) continue; // ini < from → fora da janela
    if (!ini.isBefore(to)) continue; // ini >= to → fora da janela
    total += (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0);
  }
  return total;
}
