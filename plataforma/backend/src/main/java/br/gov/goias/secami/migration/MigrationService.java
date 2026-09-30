package br.gov.goias.secami.migration;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.checkin.CheckInRepository;
import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.frequencia.Frequencia;
import br.gov.goias.secami.academy.frequencia.FrequenciaRepository;
import br.gov.goias.secami.academy.media.Media;
import br.gov.goias.secami.academy.media.MediaRepository;
import br.gov.goias.secami.academy.media.MediaStorageService;
import br.gov.goias.secami.academy.notice.Notice;
import br.gov.goias.secami.academy.notice.NoticeRepository;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.EmailInstitucional;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.identity.AppUserRepository;
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
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
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
    private final MediaStorageService media;
    private final MediaRepository mediaRepository;
    private final AppUserRepository users;
    private final ObjectMapper mapper;
    private final ZoneId zone;
    private final HttpClient http;

    public MigrationService(DepartmentRepository departments, SlotConfigRepository slots,
                            BlockedDateRepository blockedDates, ExerciseRepository exercises,
                            StudentRepository students, NoticeRepository notices,
                            AppointmentRepository appointments, CheckInRepository checkins,
                            FrequenciaRepository frequencias, MediaStorageService media,
                            MediaRepository mediaRepository, AppUserRepository users,
                            ObjectMapper mapper, SecamiProperties props) {
        this.departments = departments;
        this.slots = slots;
        this.blockedDates = blockedDates;
        this.exercises = exercises;
        this.students = students;
        this.notices = notices;
        this.appointments = appointments;
        this.checkins = checkins;
        this.frequencias = frequencias;
        this.media = media;
        this.mediaRepository = mediaRepository;
        this.users = users;
        this.mapper = mapper;
        this.zone = ZoneId.of(props.getTimezone());
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(15))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
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
            Student s = novoAluno(rec, byName);
            if (s.getFullName() == null) { r.errors++; return; }
            students.save(s);
            r.inserted++;
        });
    }

    private Student novoAluno(CSVRecord rec, Map<String, Department> byName) {
        Student s = new Student();
        s.setFullName(titleCase(str(rec, "full_name")));
        s.setCpf(Cpf.normalize(str(rec, "cpf")));
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
        s.setLegacyId(str(rec, "id"));
        String depName = str(rec, "department");
        if (depName != null) s.setDepartment(byName.get(norm(depName)));
        return s;
    }

    // ---- Atualização incremental dos alunos (nova exportação do legado) ----

    private static final int LIMITE_ITENS = 500;

    /**
     * Atualiza os ALUNOS a partir de uma exportação mais nova do legado, que
     * continua em uso em paralelo: insere quem é novo e, pra quem já existe,
     * aplica só o que mudou NO LEGADO desde a exportação anterior
     * ({@code baselineDir}) — comparando as duas exportações campo a campo.
     * Assim o que foi corrigido aqui na plataforma depois da carga (ex.:
     * e-mail institucional vindo do AD/Accelero) não é sobrescrito por um
     * valor antigo do legado que simplesmente não mudou.
     *
     * <p>Casamento: por legacy_id; se não achar, por CPF (o legado tem gente
     * cadastrada duas vezes — o recadastro costuma trazer atestado mais novo).
     * Registro casado só por CPF, ou sem linha na exportação anterior, apenas
     * COMPLEMENTA: preenche campo vazio e adota atestado mais recente, nunca
     * troca um valor existente. Cadastro pendente/recusado ou excluído aqui
     * não é tocado; e-mail institucional nunca é trocado por um pessoal;
     * atestado só avança de data. E-mail de login (app_user) não muda.
     *
     * <p>Só alunos — agendamentos, check-ins etc. do legado ficam de fora.
     *
     * @param baselineDir pasta da exportação anterior (pode ser null: aí só
     *                    insere os novos e complementa os existentes)
     * @param simular     true = só relata o que faria, sem gravar nada
     */
    public AtualizacaoAlunos atualizarAlunos(Path dir, Path baselineDir, boolean simular) {
        AtualizacaoAlunos r = new AtualizacaoAlunos(simular);
        Path file = dir.resolve("Student_export.csv");
        if (!Files.exists(file)) {
            r.notas.add("Arquivo não encontrado: " + file.getFileName());
            return r;
        }
        Map<String, Map<String, String>> baseline = lerAlunosPorId(baselineDir, r);
        Map<String, Department> byName = new HashMap<>();
        departments.findAll().forEach(d -> byName.put(norm(d.getName()), d));

        CSVFormat fmt = CSVFormat.DEFAULT.builder()
                .setHeader().setSkipHeaderRecord(true).setIgnoreEmptyLines(true).build();
        try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8);
             CSVParser parser = CSVParser.parse(reader, fmt)) {
            for (CSVRecord rec : parser) {
                r.lidos++;
                if (hasCol(rec, "is_sample") && boolVal(rec, "is_sample", false)) { r.ignorados++; continue; }
                try {
                    atualizarAluno(rec, baseline, byName, simular, r);
                } catch (Exception ex) {
                    r.erros++;
                    if (r.notas.size() < 20) r.notas.add("linha " + r.lidos + ": " + ex.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Falha ao ler {}", file, e);
            r.notas.add("Erro de leitura: " + e.getMessage());
        }
        log.info("Atualização de alunos{} — lidos={} inseridos={} atualizados={} complementados={} "
                        + "semMudanca={} ignorados={} erros={}", simular ? " (SIMULAÇÃO)" : "",
                r.lidos, r.inseridos, r.atualizados, r.complementados, r.semMudanca, r.ignorados, r.erros);
        return r;
    }

    private void atualizarAluno(CSVRecord rec, Map<String, Map<String, String>> baseline,
                                Map<String, Department> byName, boolean simular, AtualizacaoAlunos r) {
        String legacy = str(rec, "id");
        String cpf = Cpf.normalize(str(rec, "cpf"));
        Student s = legacy == null ? null : students.findByLegacyId(legacy).orElse(null);
        boolean porLegacyId = s != null;
        if (s == null && cpf != null) s = students.findByCpf(cpf).orElse(null);

        if (s == null) {
            Student novo = novoAluno(rec, byName);
            if (novo.getFullName() == null) { r.erros++; return; }
            String fotoUrl = str(rec, "photo_url");
            if (!simular) {
                students.save(novo);
                if (fotoUrl != null) {
                    trocarFoto(novo, fotoUrl);
                    if (novo.getPhotoId() != null) students.save(novo);
                }
            }
            r.inseridos++;
            r.registrar("novo", novo.getFullName(), fotoUrl != null ? List.of("foto") : List.of());
            return;
        }
        if (s.getDeletedAt() != null || !Student.STATUS_APROVADO.equals(s.getStatusCadastro())) {
            r.ignorados++; // excluído ou ainda em análise/recusado na plataforma
            return;
        }

        Map<String, String> base = porLegacyId ? baseline.get(legacy) : null;
        List<Mudanca> mudancas = base != null
                ? mudancasDoLegado(s, rec, base, byName)
                : complementos(s, rec, byName);
        if (mudancas.isEmpty()) { r.semMudanca++; return; }

        if (!simular) {
            mudancas.forEach(m -> m.aplicar().run());
            students.save(s);
        }
        if (base != null) r.atualizados++; else r.complementados++;
        r.registrar(base != null ? "atualizado" : "complementado", s.getFullName(),
                mudancas.stream().map(Mudanca::campo).toList());
    }

    /** Um campo a alterar no aluno — só é aplicado fora do modo simulação. */
    private record Mudanca(String campo, Runnable aplicar) {}

    /** Campos que mudaram no legado desde a exportação anterior E diferem do valor atual. */
    private List<Mudanca> mudancasDoLegado(Student s, CSVRecord rec, Map<String, String> base,
                                            Map<String, Department> byName) {
        List<Mudanca> m = new ArrayList<>();
        if (mudou(rec, base, "full_name")) {
            String nome = titleCase(str(rec, "full_name"));
            if (nome != null && !nome.equals(s.getFullName())) {
                m.add(new Mudanca("nome", () -> {
                    s.setFullName(nome);
                    atualizarNomeDoLogin(s, nome);
                }));
            }
        }
        if (mudou(rec, base, "phone")) texto(m, "telefone", str(rec, "phone"), s.getPhone(), s::setPhone);
        if (mudou(rec, base, "matricula")) texto(m, "matrícula", str(rec, "matricula"), s.getMatricula(), s::setMatricula);
        if (mudou(rec, base, "goal")) texto(m, "objetivo", str(rec, "goal"), s.getGoal(), s::setGoal);
        if (mudou(rec, base, "atestado_numero")) {
            texto(m, "número do atestado", str(rec, "atestado_numero"), s.getAtestadoNumero(), s::setAtestadoNumero);
        }
        if (mudou(rec, base, "birth_date")) {
            LocalDate v = dateVal(str(rec, "birth_date"));
            if (v != null && !v.equals(s.getBirthDate())) m.add(new Mudanca("nascimento", () -> s.setBirthDate(v)));
        }
        if (mudou(rec, base, "weight")) {
            decimal(m, "peso", decimalVal(str(rec, "weight")), s.getWeightKg(), s::setWeightKg);
        }
        if (mudou(rec, base, "height")) {
            decimal(m, "altura", decimalVal(str(rec, "height")), s.getHeightCm(), s::setHeightCm);
        }
        if (mudou(rec, base, "atestado_data")) atestadoMaisRecente(m, s, rec);
        if (mudou(rec, base, "student_type")) {
            String tipo = str(rec, "student_type");
            // Instrutor é decisão tomada aqui na plataforma — o legado não rebaixa.
            if (tipo != null && Set.of(Student.TIPO_CIVIL, Student.TIPO_MILITAR).contains(tipo)
                    && !s.isInstrutor() && !tipo.equals(s.getStudentType())) {
                m.add(new Mudanca("categoria", () -> s.setStudentType(tipo)));
            }
        }
        if (mudou(rec, base, "department")) {
            Department d = byName.get(norm(str(rec, "department")));
            if (d != null && (s.getDepartment() == null || !d.getId().equals(s.getDepartment().getId()))) {
                m.add(new Mudanca("secretaria", () -> s.setDepartment(d)));
            }
        }
        if (mudou(rec, base, "email")) {
            String email = str(rec, "email");
            if (email != null) {
                String novo = email.toLowerCase();
                boolean rebaixaria = EmailInstitucional.ehDoGoverno(s.getEmail())
                        && !EmailInstitucional.ehDoGoverno(novo);
                if (!rebaixaria && !novo.equalsIgnoreCase(s.getEmail())) {
                    m.add(new Mudanca("e-mail", () -> s.setEmail(novo)));
                }
            }
        }
        if (mudou(rec, base, "active") && !Student.SITUACAO_BLOQUEADO.equals(s.getSituacao())) {
            boolean ativo = boolVal(rec, "active", true);
            if (ativo != s.isActive()) {
                m.add(new Mudanca("situação", () -> s.setSituacao(
                        ativo ? Student.SITUACAO_ATIVO : Student.SITUACAO_INATIVO)));
            }
        }
        if (mudou(rec, base, "photo_url")) {
            String url = str(rec, "photo_url");
            // Rodar de novo com a mesma exportação não baixa a mesma foto outra vez.
            if (url != null && !fotoVeioDe(s, url)) m.add(new Mudanca("foto", () -> trocarFoto(s, url)));
        }
        return m;
    }

    /** A foto atual do aluno já foi baixada desta mesma URL do legado? */
    private boolean fotoVeioDe(Student s, String url) {
        return s.getPhotoId() != null && mediaRepository.findById(s.getPhotoId())
                .map(m -> url.equals(m.getOrigemUrl())).orElse(false);
    }

    /** Sem linha na exportação anterior (ou casado só por CPF): só preenche o
     *  que está vazio e adota atestado mais recente — nunca troca valor existente. */
    private List<Mudanca> complementos(Student s, CSVRecord rec, Map<String, Department> byName) {
        List<Mudanca> m = new ArrayList<>();
        if (vazio(s.getPhone())) texto(m, "telefone", str(rec, "phone"), null, s::setPhone);
        if (vazio(s.getMatricula())) texto(m, "matrícula", str(rec, "matricula"), null, s::setMatricula);
        if (vazio(s.getGoal())) texto(m, "objetivo", str(rec, "goal"), null, s::setGoal);
        if (vazio(s.getAtestadoNumero())) {
            texto(m, "número do atestado", str(rec, "atestado_numero"), null, s::setAtestadoNumero);
        }
        if (s.getBirthDate() == null) {
            LocalDate v = dateVal(str(rec, "birth_date"));
            if (v != null) m.add(new Mudanca("nascimento", () -> s.setBirthDate(v)));
        }
        if (s.getWeightKg() == null) decimal(m, "peso", decimalVal(str(rec, "weight")), null, s::setWeightKg);
        if (s.getHeightCm() == null) decimal(m, "altura", decimalVal(str(rec, "height")), null, s::setHeightCm);
        atestadoMaisRecente(m, s, rec);
        if (s.getDepartment() == null) {
            Department d = byName.get(norm(str(rec, "department")));
            if (d != null) m.add(new Mudanca("secretaria", () -> s.setDepartment(d)));
        }
        if (s.getPhotoId() == null) {
            String url = str(rec, "photo_url");
            if (url != null) m.add(new Mudanca("foto", () -> trocarFoto(s, url)));
        }
        return m;
    }

    private void atestadoMaisRecente(List<Mudanca> m, Student s, CSVRecord rec) {
        LocalDate v = dateVal(str(rec, "atestado_data"));
        if (v != null && (s.getAtestadoData() == null || v.isAfter(s.getAtestadoData()))) {
            m.add(new Mudanca("atestado", () -> s.setAtestadoData(v)));
        }
    }

    private static void texto(List<Mudanca> m, String campo, String novo, String atual,
                              java.util.function.Consumer<String> setter) {
        // Valor vazio no legado nunca apaga um dado que já existe aqui.
        if (novo != null && !novo.equals(atual)) m.add(new Mudanca(campo, () -> setter.accept(novo)));
    }

    private static void decimal(List<Mudanca> m, String campo, BigDecimal novo, BigDecimal atual,
                                java.util.function.Consumer<BigDecimal> setter) {
        if (novo != null && (atual == null || novo.compareTo(atual) != 0)) {
            m.add(new Mudanca(campo, () -> setter.accept(novo)));
        }
    }

    private static boolean vazio(String s) {
        return s == null || s.isBlank();
    }

    private static boolean mudou(CSVRecord rec, Map<String, String> base, String col) {
        return !Objects.equals(str(rec, col), base.get(col));
    }

    private void atualizarNomeDoLogin(Student s, String nome) {
        if (s.getUserId() == null) return;
        users.findById(s.getUserId()).ifPresent(u -> {
            u.setNome(nome);
            users.save(u);
        });
    }

    /** Baixa a foto nova do legado e troca a do aluno; falha de download não
     *  derruba a atualização dos outros campos (só fica sem a foto nova). */
    private void trocarFoto(Student s, String url) {
        try {
            Media m = baixarFoto(url);
            if (m != null) s.setPhotoId(m.getId());
        } catch (Exception e) {
            log.warn("Não foi possível baixar a foto nova do aluno {}: {}", s.getId(), e.getMessage());
        }
    }

    private Media baixarFoto(String url) throws Exception {
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(30)).GET().build();
        HttpResponse<byte[]> resp = http.send(req, HttpResponse.BodyHandlers.ofByteArray());
        if (resp.statusCode() != 200 || resp.body().length == 0) {
            throw new IllegalStateException("HTTP " + resp.statusCode() + " ao baixar " + url);
        }
        String contentType = resp.headers().firstValue("content-type").orElse("image/jpeg");
        String filename = url.substring(url.lastIndexOf('/') + 1);
        Media m = media.saveBytes(resp.body(), contentType, filename, Media.TIPO_FOTO_ALUNO);
        m.setOrigemUrl(url); // de onde veio — é o que evita baixar de novo (ver fotoVeioDe)
        return mediaRepository.save(m);
    }

    /** Exportação anterior indexada pelo id do legado (valores já no formato de {@link #str}). */
    private Map<String, Map<String, String>> lerAlunosPorId(Path baselineDir, AtualizacaoAlunos r) {
        Map<String, Map<String, String>> porId = new HashMap<>();
        if (baselineDir == null) return porId;
        Path file = baselineDir.resolve("Student_export.csv");
        if (!Files.exists(file)) {
            r.notas.add("Exportação anterior não encontrada (" + file + ") — só insere novos e complementa.");
            return porId;
        }
        CSVFormat fmt = CSVFormat.DEFAULT.builder()
                .setHeader().setSkipHeaderRecord(true).setIgnoreEmptyLines(true).build();
        try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8);
             CSVParser parser = CSVParser.parse(reader, fmt)) {
            List<String> colunas = parser.getHeaderNames();
            for (CSVRecord rec : parser) {
                String id = str(rec, "id");
                if (id == null) continue;
                Map<String, String> linha = new HashMap<>();
                for (String c : colunas) linha.put(c, str(rec, c));
                porId.put(id, linha);
            }
        } catch (Exception e) {
            log.error("Falha ao ler a exportação anterior {}", file, e);
            r.notas.add("Erro ao ler a exportação anterior: " + e.getMessage());
        }
        return porId;
    }

    /** Resultado da atualização incremental de alunos. */
    public static class AtualizacaoAlunos {
        public final boolean simulacao;
        public int lidos, inseridos, atualizados, complementados, semMudanca, ignorados, erros;
        /** Um item por aluno inserido/alterado (até {@value #LIMITE_ITENS}). */
        public final List<ItemAtualizado> itens = new ArrayList<>();
        public final List<String> notas = new ArrayList<>();

        public AtualizacaoAlunos(boolean simulacao) { this.simulacao = simulacao; }

        void registrar(String acao, String aluno, List<String> campos) {
            if (itens.size() < LIMITE_ITENS) itens.add(new ItemAtualizado(acao, aluno, campos));
        }
    }

    public record ItemAtualizado(String acao, String aluno, List<String> campos) {}

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

    /**
     * Baixa as fotos do legado (campo photo_url do Student_export.csv, ainda
     * hospedadas em base44.app) e vincula a cada Student pelo legacy_id.
     * Roda separado de {@link #run} de propósito (job à parte, como já
     * previsto) — idempotente: pula quem já tem photoId ou não tem photo_url.
     */
    public ImportResult importarFotos(Path file) {
        return process("FotoAluno", file, (rec, r) -> {
            String legacy = str(rec, "id");
            String url = str(rec, "photo_url");
            if (legacy == null || url == null) { r.skipped++; return; }
            Student s = students.findByLegacyId(legacy).orElse(null);
            if (s == null) { r.errors++; return; }
            if (s.getPhotoId() != null) { r.skipped++; return; }

            Media m;
            try {
                m = baixarFoto(url);
            } catch (Exception e) {
                r.errors++;
                if (r.notes.size() < 5) r.notes.add("linha " + r.read + ": falha ao baixar " + url + " — " + e.getMessage());
                return;
            }
            s.setPhotoId(m.getId());
            students.save(s);
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
