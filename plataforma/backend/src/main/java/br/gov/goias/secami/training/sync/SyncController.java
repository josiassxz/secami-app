package br.gov.goias.secami.training.sync;

import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Sync do app (rotinas/sessões/séries/cardio) — SPEC §10.3 / E9. Nomes de
 * tabela no path são os mesmos usados pelo cliente (plural, herdados do
 * transport Supabase anterior); cada handler delega ao método correto do
 * {@link SyncService}. Dono sempre resolvido do JWT — nunca do payload.
 */
@RestController
@RequestMapping("/sync")
public class SyncController {

    private final SyncService sync;
    private final CurrentUser currentUser;

    public SyncController(SyncService sync, CurrentUser currentUser) {
        this.sync = sync;
        this.currentUser = currentUser;
    }

    @GetMapping("/{table}")
    public List<Map<String, Object>> pull(
            @PathVariable String table,
            @RequestParam(required = false) String since) {
        UUID uid = currentUser.id();
        OffsetDateTime cursor = since == null || since.isBlank() ? null : OffsetDateTime.parse(since);
        return switch (table) {
            case "routines" -> sync.pullRoutines(uid, cursor);
            case "routine_exercises" -> sync.pullRoutineExercises(uid, cursor);
            case "workout_sessions" -> sync.pullSessions(uid, cursor);
            case "set_logs" -> sync.pullSetLogs(uid, cursor);
            case "cardio_sessions" -> sync.pullCardio(uid, cursor);
            default -> throw new BusinessException("Tabela de sync desconhecida: " + table);
        };
    }

    @PostMapping("/{table}")
    public void push(@PathVariable String table, @RequestBody List<Map<String, Object>> rows) {
        UUID uid = currentUser.id();
        switch (table) {
            case "routines" -> sync.pushRoutines(uid, rows);
            case "routine_exercises" -> sync.pushRoutineExercises(uid, rows);
            case "workout_sessions" -> sync.pushSessions(uid, rows);
            case "set_logs" -> sync.pushSetLogs(uid, rows);
            case "cardio_sessions" -> sync.pushCardio(uid, rows);
            case "recommender_runs" -> sync.pushRecommenderRuns(uid, rows);
            default -> throw new BusinessException("Tabela de sync desconhecida: " + table);
        }
    }
}
