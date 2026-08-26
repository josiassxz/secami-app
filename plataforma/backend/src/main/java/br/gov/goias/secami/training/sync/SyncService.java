package br.gov.goias.secami.training.sync;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Sync offline-first do app (SPEC §10.3 / E9): rotinas, sessões, séries e
 * cardio do usuário. Espelha 1:1 o contrato já usado pelo cliente Flutter
 * (mesmos nomes de coluna/JSON do antigo transport Supabase) — só troca o
 * transporte, a lógica de push/pull/last-write-wins continua no cliente
 * (Drift + sync_engine.dart).
 *
 * Cada tabela-filha (routine_exercise, set_log) não tem coluna de dono direta;
 * a posse é resolvida via o pai (routine/workout_session) e verificada antes
 * do upsert — uma linha cujo pai não pertence ao usuário autenticado derruba
 * a transação inteira (o cliente já tem fallback de retry linha-a-linha).
 */
@Service
public class SyncService {

    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public SyncService(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    // ============== PULL ==============
    // since==null => sem filtro de cursor (primeiro pull); com Timestamp
    // explícito no cast evita o "could not determine data type of parameter"
    // que o Postgres acusa para null cru comparado via `? is null`.

    public List<Map<String, Object>> pullRoutines(UUID userId, OffsetDateTime since) {
        String sql = "select id, user_id, nome, tipo, dias_da_semana, ordem, ativo, origem, "
                + "atribuido_por, criado_em, updated_at, deleted_at, device_id from routine "
                + "where user_id = ?" + cursorClause(since, "updated_at") + " order by updated_at asc";
        var rows = since == null
                ? jdbc.queryForList(sql, userId)
                : jdbc.queryForList(sql, userId, ts(since));
        return normalize(rows, Set.of("dias_da_semana"));
    }

    public List<Map<String, Object>> pullRoutineExercises(UUID userId, OffsetDateTime since) {
        String sql = "select re.id, re.routine_id, re.exercise_id, re.ordem, re.series_planejadas, "
                + "re.notas, re.grupo_id, re.grupo_tipo, re.rounds, re.criado_em, "
                + "re.updated_at, re.deleted_at, re.device_id from routine_exercise re "
                + "join routine r on r.id = re.routine_id where r.user_id = ?"
                + cursorClause(since, "re.updated_at") + " order by re.updated_at asc";
        var rows = since == null
                ? jdbc.queryForList(sql, userId)
                : jdbc.queryForList(sql, userId, ts(since));
        return normalize(rows, Set.of("series_planejadas"));
    }

    public List<Map<String, Object>> pullSessions(UUID userId, OffsetDateTime since) {
        String sql = "select id, user_id, routine_id, iniciado_em, finalizado_em, "
                + "duracao_total_segundos, notas, sentimento, updated_at, deleted_at, device_id "
                + "from workout_session where user_id = ?"
                + cursorClause(since, "updated_at") + " order by updated_at asc";
        var rows = since == null
                ? jdbc.queryForList(sql, userId)
                : jdbc.queryForList(sql, userId, ts(since));
        return normalize(rows, Set.of());
    }

    public List<Map<String, Object>> pullSetLogs(UUID userId, OffsetDateTime since) {
        String sql = "select sl.id, sl.session_id, sl.exercise_id, sl.ordem_no_treino, sl.numero_serie, "
                + "sl.reps_realizadas, sl.carga_kg, sl.duracao_segundos, sl.rpe, sl.tipo_serie, "
                + "sl.executada, sl.motivo_pulo, sl.substituido_de_exercise_id, sl.criado_em, "
                + "sl.updated_at, sl.deleted_at, sl.device_id from set_log sl "
                + "join workout_session s on s.id = sl.session_id where s.user_id = ?"
                + cursorClause(since, "sl.updated_at") + " order by sl.updated_at asc";
        var rows = since == null
                ? jdbc.queryForList(sql, userId)
                : jdbc.queryForList(sql, userId, ts(since));
        return normalize(rows, Set.of());
    }

    public List<Map<String, Object>> pullCardio(UUID userId, OffsetDateTime since) {
        String sql = "select id, user_id, modalidade, duracao_minutos, distancia_km, intensidade, "
                + "fc_media, fc_max, calorias, external_source, external_id, synced_at, "
                + "executado_em, updated_at, deleted_at, device_id from cardio_session "
                + "where user_id = ?" + cursorClause(since, "updated_at") + " order by updated_at asc";
        var rows = since == null
                ? jdbc.queryForList(sql, userId)
                : jdbc.queryForList(sql, userId, ts(since));
        return normalize(rows, Set.of());
    }

    private String cursorClause(OffsetDateTime since, String column) {
        return since == null ? "" : " and " + column + " > ?";
    }

    /**
     * Pós-processa linhas do JdbcTemplate para JSON seguro: colunas jsonb
     * (vêm como {@link org.postgresql.util.PGobject} ou String) viram
     * objeto/array nativo, e timestamps viram ISO-8601 (o driver devolve
     * {@link Timestamp}, que o Jackson serializaria como epoch numérico).
     */
    private List<Map<String, Object>> normalize(List<Map<String, Object>> rows, Set<String> jsonbCols) {
        List<Map<String, Object>> out = new java.util.ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            Map<String, Object> copy = new LinkedHashMap<>();
            for (var e : row.entrySet()) {
                Object v = e.getValue();
                if (jsonbCols.contains(e.getKey())) {
                    copy.put(e.getKey(), parseJsonbValue(v));
                } else if (v instanceof Timestamp t) {
                    copy.put(e.getKey(), t.toInstant().toString());
                } else {
                    copy.put(e.getKey(), v);
                }
            }
            out.add(copy);
        }
        return out;
    }

    private Object parseJsonbValue(Object v) {
        if (v == null) return List.of();
        // v é String ou PGobject (driver em runtime-scope; toString() devolve
        // o mesmo texto JSON em ambos os casos — evita depender do tipo em compile-time).
        try {
            return mapper.readValue(v.toString(), Object.class);
        } catch (Exception e) {
            return List.of();
        }
    }

    // ============== PUSH ==============

    @Transactional
    public void pushRoutines(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID rowUser = uuid(r.get("user_id"));
            if (!userId.equals(rowUser)) {
                throw new BusinessException("Registro de rotina não pertence ao usuário autenticado.");
            }
            jdbc.update("""
                    insert into routine (id, user_id, nome, tipo, dias_da_semana, ordem, ativo,
                        origem, atribuido_por, criado_em, updated_at, deleted_at, device_id)
                    values (?, ?, ?, ?, ?::jsonb, ?, ?, ?, ?, ?, ?, ?, ?)
                    on conflict (id) do update set
                        nome = excluded.nome, tipo = excluded.tipo,
                        dias_da_semana = excluded.dias_da_semana, ordem = excluded.ordem,
                        ativo = excluded.ativo, origem = excluded.origem,
                        atribuido_por = excluded.atribuido_por, criado_em = excluded.criado_em,
                        updated_at = excluded.updated_at, deleted_at = excluded.deleted_at,
                        device_id = excluded.device_id
                    """,
                    uuid(r.get("id")), rowUser, str(r.get("nome")), str(r.get("tipo")),
                    json(r.get("dias_da_semana")), intVal(r.get("ordem")), boolVal(r.get("ativo")),
                    str(r.get("origem")), uuid(r.get("atribuido_por")), ts(r.get("criado_em")),
                    tsRequired(r.get("updated_at")), ts(r.get("deleted_at")), str(r.get("device_id")));
        }
    }

    @Transactional
    public void pushRoutineExercises(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID routineId = uuid(r.get("routine_id"));
            assertOwnsRoutine(userId, routineId);
            jdbc.update("""
                    insert into routine_exercise (id, routine_id, exercise_id, ordem, series_planejadas,
                        notas, grupo_id, grupo_tipo, rounds, criado_em, updated_at, deleted_at, device_id)
                    values (?, ?, ?, ?, ?::jsonb, ?, ?, ?, ?, ?, ?, ?, ?)
                    on conflict (id) do update set
                        exercise_id = excluded.exercise_id, ordem = excluded.ordem,
                        series_planejadas = excluded.series_planejadas, notas = excluded.notas,
                        grupo_id = excluded.grupo_id, grupo_tipo = excluded.grupo_tipo,
                        rounds = excluded.rounds, criado_em = excluded.criado_em,
                        updated_at = excluded.updated_at, deleted_at = excluded.deleted_at,
                        device_id = excluded.device_id
                    """,
                    uuid(r.get("id")), routineId, str(r.get("exercise_id")), intVal(r.get("ordem")),
                    json(r.get("series_planejadas")), str(r.get("notas")), str(r.get("grupo_id")),
                    str(r.get("grupo_tipo")), intOrNull(r.get("rounds")), ts(r.get("criado_em")),
                    tsRequired(r.get("updated_at")), ts(r.get("deleted_at")), str(r.get("device_id")));
        }
    }

    @Transactional
    public void pushSessions(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID rowUser = uuid(r.get("user_id"));
            if (!userId.equals(rowUser)) {
                throw new BusinessException("Sessão não pertence ao usuário autenticado.");
            }
            UUID routineId = uuid(r.get("routine_id"));
            if (routineId != null) {
                assertOwnsRoutine(userId, routineId);
            }
            jdbc.update("""
                    insert into workout_session (id, user_id, routine_id, iniciado_em, finalizado_em,
                        duracao_total_segundos, notas, sentimento, updated_at, deleted_at, device_id)
                    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    on conflict (id) do update set
                        routine_id = excluded.routine_id, iniciado_em = excluded.iniciado_em,
                        finalizado_em = excluded.finalizado_em,
                        duracao_total_segundos = excluded.duracao_total_segundos,
                        notas = excluded.notas, sentimento = excluded.sentimento,
                        updated_at = excluded.updated_at, deleted_at = excluded.deleted_at,
                        device_id = excluded.device_id
                    """,
                    uuid(r.get("id")), rowUser, routineId, tsRequired(r.get("iniciado_em")),
                    ts(r.get("finalizado_em")), intOrNull(r.get("duracao_total_segundos")),
                    str(r.get("notas")), intOrNull(r.get("sentimento")), tsRequired(r.get("updated_at")),
                    ts(r.get("deleted_at")), str(r.get("device_id")));
        }
    }

    @Transactional
    public void pushSetLogs(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID sessionId = uuid(r.get("session_id"));
            assertOwnsSession(userId, sessionId);
            jdbc.update("""
                    insert into set_log (id, session_id, exercise_id, ordem_no_treino, numero_serie,
                        reps_realizadas, carga_kg, duracao_segundos, rpe, tipo_serie, executada,
                        motivo_pulo, substituido_de_exercise_id, criado_em, updated_at, deleted_at, device_id)
                    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    on conflict (id) do update set
                        exercise_id = excluded.exercise_id, ordem_no_treino = excluded.ordem_no_treino,
                        numero_serie = excluded.numero_serie, reps_realizadas = excluded.reps_realizadas,
                        carga_kg = excluded.carga_kg, duracao_segundos = excluded.duracao_segundos,
                        rpe = excluded.rpe, tipo_serie = excluded.tipo_serie,
                        executada = excluded.executada, motivo_pulo = excluded.motivo_pulo,
                        substituido_de_exercise_id = excluded.substituido_de_exercise_id,
                        criado_em = excluded.criado_em, updated_at = excluded.updated_at,
                        deleted_at = excluded.deleted_at, device_id = excluded.device_id
                    """,
                    uuid(r.get("id")), sessionId, str(r.get("exercise_id")),
                    intRequired(r.get("ordem_no_treino")), intRequired(r.get("numero_serie")),
                    intOrNull(r.get("reps_realizadas")), doubleOrNull(r.get("carga_kg")),
                    intOrNull(r.get("duracao_segundos")), intOrNull(r.get("rpe")),
                    str(r.get("tipo_serie")), boolVal(r.get("executada")), str(r.get("motivo_pulo")),
                    str(r.get("substituido_de_exercise_id")), ts(r.get("criado_em")),
                    tsRequired(r.get("updated_at")), ts(r.get("deleted_at")), str(r.get("device_id")));
        }
    }

    @Transactional
    public void pushCardio(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID rowUser = uuid(r.get("user_id"));
            if (!userId.equals(rowUser)) {
                throw new BusinessException("Registro de cardio não pertence ao usuário autenticado.");
            }
            jdbc.update("""
                    insert into cardio_session (id, user_id, modalidade, duracao_minutos, distancia_km,
                        intensidade, fc_media, fc_max, calorias, external_source, external_id,
                        synced_at, executado_em, updated_at, deleted_at, device_id)
                    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    on conflict (id) do update set
                        modalidade = excluded.modalidade, duracao_minutos = excluded.duracao_minutos,
                        distancia_km = excluded.distancia_km, intensidade = excluded.intensidade,
                        fc_media = excluded.fc_media, fc_max = excluded.fc_max,
                        calorias = excluded.calorias, external_source = excluded.external_source,
                        external_id = excluded.external_id, synced_at = excluded.synced_at,
                        executado_em = excluded.executado_em, updated_at = excluded.updated_at,
                        deleted_at = excluded.deleted_at, device_id = excluded.device_id
                    """,
                    uuid(r.get("id")), rowUser, str(r.get("modalidade")), intRequired(r.get("duracao_minutos")),
                    doubleOrNull(r.get("distancia_km")), intOrNull(r.get("intensidade")),
                    intOrNull(r.get("fc_media")), intOrNull(r.get("fc_max")), intOrNull(r.get("calorias")),
                    str(r.get("external_source")), str(r.get("external_id")), ts(r.get("synced_at")),
                    tsRequired(r.get("executado_em")), tsRequired(r.get("updated_at")),
                    ts(r.get("deleted_at")), str(r.get("device_id")));
        }
    }

    /**
     * Push-only (sem pull): auditoria do recomendador. Append-only — usa
     * DO NOTHING em vez de update, já que o registro nunca muda depois de
     * criado. SPEC: recomendador é feature deferida nesta passada, mas o
     * push precisa existir para não derrubar o ciclo de sync quando o
     * usuário já tiver gerado alguma recomendação localmente.
     */
    @Transactional
    public void pushRecommenderRuns(UUID userId, List<Map<String, Object>> rows) {
        for (Map<String, Object> r : rows) {
            UUID rowUser = uuid(r.get("user_id"));
            if (!userId.equals(rowUser)) {
                throw new BusinessException("Registro do recomendador não pertence ao usuário autenticado.");
            }
            jdbc.update("""
                    insert into recommender_run (id, user_id, versao_regras, perfil_json,
                        triagem_json, treino_json, divisao, bloqueado, criado_em)
                    values (?, ?, ?, ?::jsonb, ?::jsonb, ?::jsonb, ?, ?, ?)
                    on conflict (id) do nothing
                    """,
                    uuid(r.get("id")), rowUser, str(r.get("versao_regras")),
                    json(r.get("perfil_json")),
                    r.get("triagem_json") == null ? null : json(r.get("triagem_json")),
                    json(r.get("treino_json")), str(r.get("divisao")),
                    boolVal(r.get("bloqueado")), ts(r.get("criado_em")));
        }
    }

    // ============== Ownership ==============

    private void assertOwnsRoutine(UUID userId, UUID routineId) {
        Integer count = jdbc.queryForObject(
                "select count(*) from routine where id = ? and user_id = ?",
                Integer.class, routineId, userId);
        if (count == null || count == 0) {
            throw new BusinessException("Rotina não encontrada ou não pertence ao usuário.");
        }
    }

    private void assertOwnsSession(UUID userId, UUID sessionId) {
        Integer count = jdbc.queryForObject(
                "select count(*) from workout_session where id = ? and user_id = ?",
                Integer.class, sessionId, userId);
        if (count == null || count == 0) {
            throw new BusinessException("Sessão não encontrada ou não pertence ao usuário.");
        }
    }

    // ============== Conversores ==============

    private UUID uuid(Object v) {
        return v == null ? null : UUID.fromString(v.toString());
    }

    private String str(Object v) {
        return v == null ? null : v.toString();
    }

    private Integer intVal(Object v) {
        return v == null ? 0 : ((Number) v).intValue();
    }

    private int intRequired(Object v) {
        if (v == null) throw new BusinessException("Campo obrigatório ausente.");
        return ((Number) v).intValue();
    }

    private Integer intOrNull(Object v) {
        return v == null ? null : ((Number) v).intValue();
    }

    private Double doubleOrNull(Object v) {
        return v == null ? null : ((Number) v).doubleValue();
    }

    private boolean boolVal(Object v) {
        return v != null && (Boolean) v;
    }

    private Timestamp ts(Object v) {
        if (v == null) return null;
        return Timestamp.from(OffsetDateTime.parse(v.toString()).toInstant());
    }

    private Timestamp ts(OffsetDateTime v) {
        return v == null ? null : Timestamp.from(v.toInstant());
    }

    private Timestamp tsRequired(Object v) {
        Timestamp t = ts(v);
        if (t == null) throw new BusinessException("Timestamp obrigatório ausente.");
        return t;
    }

    /** Serializa listas/objetos (dias_da_semana, series_planejadas) para jsonb. */
    private String json(Object v) {
        if (v == null) return "[]";
        if (v instanceof String s) return s; // já veio como string JSON
        try {
            return mapper.writeValueAsString(v);
        } catch (Exception e) {
            return "[]";
        }
    }
}
