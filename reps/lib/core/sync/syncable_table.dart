/// Descritor de uma tabela sincronizável (Stage-07 3.1). Registrar um destes
/// em `SyncEngine._syncables` é tudo que uma tabela nova precisa para entrar no
/// push/pull — sem editar a orquestração nem os mappers espalhados.
///
/// [T] é o tipo da Row do Drift (ex.: `RoutineRow`).
class SyncableTable<T> {
  const SyncableTable({
    required this.name,
    required this.ownerColumn,
    required this.dirty,
    required this.markClean,
    required this.idOf,
    required this.toJson,
    required this.applyPulled,
  });

  /// Nome da tabela no Supabase/Drift.
  final String name;

  /// Coluna de dono usada para filtrar o PULL (`user_id`/`owner_user_id`).
  /// **Sempre** filtrada (RLS deixa o treinador ler dados de aluno, mas eles
  /// não podem entrar no Drift local — ver stage-04-coaching, seção 5).
  final String ownerColumn;

  /// Linhas pendentes de push (dirty = true).
  final Future<List<T>> Function() dirty;

  /// Marca limpas (em lote) as linhas que subiram.
  final Future<void> Function(List<String> ids) markClean;

  /// Id (PK) da linha — usado para o markClean.
  final String Function(T) idOf;

  /// Serializa a linha para JSON do Supabase. Retorna `null` quando a linha
  /// não deve subir (fica só local) — ex.: exercício global não seedado.
  final Map<String, dynamic>? Function(T) toJson;

  /// Aplica uma linha puxada do servidor no Drift (upsert, markDirty: false).
  final Future<void> Function(Map<String, dynamic> json) applyPulled;
}
