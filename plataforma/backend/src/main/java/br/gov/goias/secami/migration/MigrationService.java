package br.gov.goias.secami.migration;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.checkin.CheckInRepository;
import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.frequencia.Frequencia;
import br.gov.goias.secami.academy.frequencia.FrequenciaRepository;
import br.gov.goias.secami.academy.notice.Notice;
import br.gov.goias.secami.academy.notice.NoticeRepository;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.training.exercise.Exercise;
import br.gov.goias.secami.training.exercise.ExerciseRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.Reader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Importador idempotente dos CSVs do legado (base44) para o Postgres. SPEC §13.
 * Idempotência por legacy_id (o id base44). Aluno de-duplicado por CPF.
 * Fotos/mídia NÃO migradas aqui (job separado — decisão "re-baixar antes do cutover").
 */
@Service
public class MigrationService {

    private static final Logger log = LoggerFactory.getLogger(MigrationService.class);
    private static final DateTimeFormatter DH = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final DepartmentRepository departments;
    private final SlotConfigRepository slots;
    private final BlockedDateRepository blockedDates;
    private final ExerciseRepository exercises;
    private final StudentRepository students;
    private final NoticeRepository notices;
    private final AppointmentRepository appointments;
    private final CheckInRepository checkins;
    private final FrequenciaRepository frequencias;
    private final ObjectMapper mapper;
    private final ZoneId zone;

    public MigrationService(DepartmentRepository departments, SlotConfigRepository slots,
                            BlockedDateRepository blockedDates, ExerciseRepository exercises,
                            StudentRepository students, NoticeRepository notices,
                            AppointmentRepository appointments, CheckInRepository checkins,
                            FrequenciaRepository frequencias, ObjectMapper mapper,
                            SecamiProperties props) {
        this.departments = departments;
        this.slots = slots;
        this.blockedDates = blockedDates;
        this.exercises = exercises;
        this.students = students;
        this.notices = notices;
        this.appointments = appointments;
        this.checkins = checkins;
        this.frequencias = frequencias;
        this.mapper = mapper;
        this.zone = ZoneId.of(props.getTimezone());
    }

    /**
     * Sem @Transactional: cada linha é salva na sua própria transação (via repositório),
     * então uma violação isolada (ex.: duplicata do legado) não derruba a carga inteira.
     */
    public List<ImportResult> run(Path baseDir) {
        List<ImportResult> results = new ArrayList<>();
        results.add(importDepartments(baseDir.resolve("Department_export.csv")));
        results.add(importSlots(baseDir.resolve("SlotConfig_export.csv")));
        results.add(importBlockedDates(baseDir.resolve("BlockedDate_export.csv")));
        results.add(importExercises(baseDir.resolve("Exercise_export.csv")));
        results.add(importStudents(baseDir.resolve("Student_export.csv")));
        results.add(importNotices(baseDir.resolve("Notice_export.csv")));
        results.add(importAppointments(baseDir.resolve("Appointment_export.csv")));
        results.add(importCheckIns(baseDir.resolve("CheckIn_export.csv")));
        results.add(importFrequencia(baseDir.resolve("Frequencia_export.csv")));
        return results;
    }

    // ---- Importadores ----

    private ImportResult importDepartments(Path file) {
        return process("Department", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && departments.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Department d = new Department();
            d.setName(str(rec, "name"));
            d.setSigla(str(rec, "sigla"));
            d.setAndar(str(rec, "andar"));
            d.setActive(boolVal(rec, "active", true));
            d.setLegacyId(legacy);
            departments.save(d);
            r.inserted++;
        });
    }

    private ImportResult importSlots(Path file) {
        return process("SlotConfig", file, (rec, r) -> {
            String start = str(rec, "slot_start");
            if (start != null && slots.findBySlotStart(start).isPresent()) { r.skipped++; return; }
            SlotConfig s = new SlotConfig();
            s.setSlotStart(start);
            s.setSlotEnd(str(rec, "slot_end"));
            s.setMaxCapacity(intVal(rec, "max_capacity", 40));
            s.setCivilRestricted(boolVal(rec, "civil_restricted", false));
            s.setBlocked(boolVal(rec, "blocked", false));
            s.setBlockReason(str(rec, "block_reason"));
            s.setLegacyId(str(rec, "id"));
            slots.save(s);
            r.inserted++;
        });
    }

    private ImportResult importBlockedDates(Path file) {
        return process("BlockedDate", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && blockedDates.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            BlockedDate b = new BlockedDate();
            b.setDate(dateVal(str(rec, "date")));
            b.setSlotStart(str(rec, "slot_start"));
            b.setReason(str(rec, "reason"));
            b.setLegacyId(legacy);
            if (b.getDate() == null) { r.errors++; return; }
            blockedDates.save(b);
            r.inserted++;
        });
    }

    private ImportResult importExercises(Path file) {
        return process("Exercise", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && exercises.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Exercise e = new Exercise();
            e.setName(str(rec, "name"));
            e.setMuscleGroup(str(rec, "muscle_group"));
            e.setDescription(str(rec, "description"));
            e.setEquipment(str(rec, "equipment"));
            e.setVideoUrl(str(rec, "video_url"));
            e.setEscopo("global");
            e.setLegacyId(legacy);
            // photo_url: mídia migrada em job separado (SPEC §13.5).
            if (e.getName() == null) { r.errors++; return; }
            exercises.save(e);
            r.inserted++;
        });
    }

    private ImportResult importStudents(Path file) {
        Map<String, Department> byName = new HashMap<>();
        departments.findAll().forEach(d -> byName.put(norm(d.getName()), d));
        return process("Student", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && students.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            String cpf = Cpf.normalize(str(rec, "cpf"));
            if (cpf != null && students.findByCpf(cpf).isPresent()) { r.skipped++; return; } // de-dup por CPF
            Student s = new Student();
            s.setFullName(titleCase(str(rec, "full_name")));
            s.setCpf(cpf);
            s.setMatricula(str(rec, "matricula"));
            s.setStudentType(orDefault(str(rec, "student_type"), "Civil"));
            s.setPhone(str(rec, "phone"));
            s.setEmail(str(rec, "email"));
            s.setBirthDate(dateVal(str(rec, "birth_date")));
            s.setWeightKg(decimalVal(str(rec, "weight")));
            s.setHeightCm(decimalVal(str(rec, "height")));
            s.setGoal(str(rec, "goal"));
            s.setAtestadoNumero(str(rec, "atestado_numero"));
            s.setAtestadoData(dateVal(str(rec, "atestado_data")));
            s.setActive(boolVal(rec, "active", true));
            s.setLegacyId(legacy);
            String depName = str(rec, "department");
            if (depName != null) s.setDepartment(byName.get(norm(depName)));
            if (s.getFullName() == null) { r.errors++; return; }
            students.save(s);
            r.inserted++;
        });
    }

    private ImportResult importNotices(Path file) {
        return process("Notice", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && notices.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Notice n = new Notice();
            n.setTitle(orDefault(str(rec, "title"), "(sem título)"));
            n.setContent(orDefault(str(rec, "content"), ""));
            n.setType(orDefault(str(rec, "type"), "info"));
            n.setActive(boolVal(rec, "active", true));
            n.setTargetRoles(parseRoles(str(rec, "target_roles")));
            n.setLegacyId(legacy);
            notices.save(n);
            r.inserted++;
        });
    }

    private ImportResult importAppointments(Path file) {
        Map<String, Student> byLegacy = studentsByLegacy();
        Set<String> ativosVistos = new HashSet<>();   // de-dup do índice único (student,date,slot ativo)
        return process("Appointment", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && appointments.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Student st = byLegacy.get(str(rec, "student_id"));
            if (st == null) { r.errors++; return; }   // órfão: aluno não migrado
            LocalDate date = dateVal(str(rec, "date"));
            String slot = str(rec, "slot_start");
            if (date == null) { r.errors++; return; }
            String status = orDefault(str(rec, "status"), "agendado");
            if (!"cancelado".equals(status)) {
                String key = st.getId() + "|" + date + "|" + slot;
                if (!ativosVistos.add(key)) { r.skipped++; return; }   // duplicata ativa do legado
            }
            Appointment a = new Appointment();
            a.setStudent(st);
            a.setDate(date);
            a.setSlotStart(slot);
            a.setSlotEnd(orDefault(str(rec, "slot_end"), ""));
            a.setStatus(status);
            a.setForced(boolVal(rec, "forced", false));
            a.setNotes(str(rec, "notes"));
            a.setLegacyId(legacy);
            appointments.save(a);
            r.inserted++;
        });
    }

    private ImportResult importCheckIns(Path file) {
        Map<String, Student> byLegacy = studentsByLegacy();
        return process("CheckIn", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && checkins.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Student st = byLegacy.get(str(rec, "student_id"));
            if (st == null) { r.errors++; return; }
            LocalDate date = dateVal(str(rec, "date"));
            if (date == null) { r.errors++; return; }
            CheckIn c = new CheckIn();
            c.setStudent(st);
            c.setDate(date);
            c.setCheckInTime(orDefault(str(rec, "check_in_time"), "00:00"));
            c.setCheckOutTime(str(rec, "check_out_time"));
            c.setNotes(str(rec, "notes"));
            c.setLegacyId(legacy);
            checkins.save(c);
            r.inserted++;
        });
    }

    private ImportResult importFrequencia(Path file) {
        Map<String, Student> byLegacy = studentsByLegacy();
        return process("Frequencia", file, (rec, r) -> {
            String legacy = str(rec, "id");
            if (legacy != null && frequencias.findByLegacyId(legacy).isPresent()) { r.skipped++; return; }
            Student st = byLegacy.get(str(rec, "student_id"));
            if (st == null) { r.errors++; return; }
            OffsetDateTime dh = dateTimeVal(str(rec, "data_hora"));
            if (dh == null) { r.errors++; return; }
            Frequencia f = new Frequencia();
            f.setStudent(st);
            f.setDataHora(dh);
            f.setTipo(orDefault(str(rec, "tipo"), "entrada"));
            f.setOrigem("catraca");
            f.setLegacyId(legacy);
            frequencias.save(f);
            r.inserted++;
        });
    }

    // ---- Infra ----

    private Map<String, Student> studentsByLegacy() {
        Map<String, Student> map = new HashMap<>();
        students.findAll().forEach(s -> { if (s.getLegacyId() != null) map.put(s.getLegacyId(), s); });
        return map;
    }

    @FunctionalInterface
    private interface RowHandler {
        void handle(CSVRecord rec, ImportResult r) throws Exception;
    }

    private ImportResult process(String entity, Path file, RowHandler handler) {
        ImportResult r = new ImportResult(entity);
        if (!Files.exists(file)) {
            r.notes.add("Arquivo não encontrado: " + file.getFileName());
            return r;
        }
        CSVFormat fmt = CSVFormat.DEFAULT.builder()
                .setHeader().setSkipHeaderRecord(true).setIgnoreEmptyLines(true).build();
        try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8);
             CSVParser parser = CSVParser.parse(reader, fmt)) {
            for (CSVRecord rec : parser) {
                r.read++;
                if (hasCol(rec, "is_sample") && boolVal(rec, "is_sample", false)) { r.skipped++; continue; }
                try {
                    handler.handle(rec, r);
                } catch (Exception ex) {
                    r.errors++;
                    if (r.notes.size() < 5) r.notes.add("linha " + r.read + ": " + ex.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Falha ao ler {}", file, e);
            r.notes.add("Erro de leitura: " + e.getMessage());
        }
        log.info("Migração {} — lidos={} inseridos={} pulados={} erros={}",
                entity, r.read, r.inserted, r.skipped, r.errors);
        return r;
    }

    // ---- Parsers ----

    private static boolean hasCol(CSVRecord rec, String col) {
        return rec.isMapped(col);
    }

    private static String str(CSVRecord rec, String col) {
        if (!rec.isMapped(col)) return null;
        String v = rec.get(col);
        return (v == null || v.trim().isEmpty()) ? null : v.trim();
    }

    private static boolean boolVal(CSVRecord rec, String col, boolean def) {
        String v = str(rec, col);
        return v == null ? def : v.equalsIgnoreCase("true");
    }

    private static int intVal(CSVRecord rec, String col, int def) {
        String v = str(rec, col);
        try { return v == null ? def : Integer.parseInt(v.trim()); }
        catch (NumberFormatException e) { return def; }
    }

    private static LocalDate dateVal(String v) {
        if (v == null) return null;
        try { return LocalDate.parse(v.substring(0, Math.min(10, v.length()))); }
        catch (Exception e) { return null; }
    }

    private OffsetDateTime dateTimeVal(String v) {
        if (v == null) return null;
        try {
            LocalDateTime ldt = LocalDateTime.parse(v.trim(), DH);
            return ldt.atZone(zone).toOffsetDateTime();
        } catch (Exception e) {
            LocalDate d = dateVal(v);
            return d == null ? null : d.atStartOfDay(zone).toOffsetDateTime();
        }
    }

    private static BigDecimal decimalVal(String v) {
        if (v == null) return null;
        try { return new BigDecimal(v.replace(",", ".").trim()); }
        catch (Exception e) { return null; }
    }

    private List<String> parseRoles(String json) {
        if (json == null) return new ArrayList<>(List.of("aluno"));
        try { return new ArrayList<>(Arrays.asList(mapper.readValue(json, String[].class))); }
        catch (Exception e) { return new ArrayList<>(List.of("aluno")); }
    }

    private static String orDefault(String v, String def) {
        return v == null ? def : v;
    }

    private static String norm(String s) {
        return s == null ? "" : s.trim().toLowerCase();
    }

    /** Title-case simples (mesma ideia do normalizeStudentNames do legado). */
    private static String titleCase(String s) {
        if (s == null) return null;
        String[] parts = s.trim().toLowerCase().split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (p.isEmpty()) continue;
            sb.append(Character.toUpperCase(p.charAt(0))).append(p.substring(1)).append(' ');
        }
        return sb.toString().trim();
    }

    /** Resultado por entidade. */
    public static class ImportResult {
        public final String entity;
        public int read, inserted, skipped, errors;
        public final List<String> notes = new ArrayList<>();

        public ImportResult(String entity) { this.entity = entity; }
    }
}
