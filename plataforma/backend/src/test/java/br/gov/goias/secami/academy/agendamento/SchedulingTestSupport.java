package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.checkin.CheckInRepository;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Infraestrutura compartilhada pelos testes de agendamento/check-in (SPEC §9.4/§9.5).
 *
 * <p>Estratégia: o estado PRÉVIO (alunos, slots, agendamentos já existentes) é semeado
 * diretamente via repositório — rápido e determinístico — enquanto a REGRA sob teste é
 * sempre exercitada pela pilha real (controller → security → service) via MockMvc, para
 * garantir que RBAC e serialização também são cobertos, não só o service isolado.
 *
 * <p>Datas usadas nos testes de janela de 48h são âncoras fixas (ontem/amanhã/daqui a 3
 * dias, sempre às 08:00) em vez de deltas de horas a partir de "agora" — isso evita que
 * os testes fiquem "flaky" perto da virada do dia, já que amanhã 08:00 está sempre entre
 * ~8h e ~32h no futuro (dentro da janela de 48h) e depois-de-amanhã+1 está sempre a mais
 * de 48h, não importa em que horário do dia a suíte rodar.
 */
abstract class SchedulingTestSupport extends AbstractIntegrationTest {

    protected static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");
    private static final AtomicInteger SEQ = new AtomicInteger();

    @Autowired protected StudentRepository studentRepository;
    @Autowired protected AppUserRepository appUserRepository;
    @Autowired protected SlotConfigRepository slotConfigRepository;
    @Autowired protected BlockedDateRepository blockedDateRepository;
    @Autowired protected AppointmentRepository appointmentRepository;
    @Autowired protected CheckInRepository checkInRepository;
    @Autowired protected JdbcTemplate jdbcTemplate;
    @Autowired protected SecamiProperties secamiProperties;
    @Autowired protected PasswordEncoder passwordEncoder;

    protected ZoneId zone() {
        return ZoneId.of(secamiProperties.getTimezone());
    }

    protected LocalDate hoje() {
        return LocalDate.now(zone());
    }

    // ---- Âncoras de data para os testes de janela de 48h ----

    protected LocalDate ontem() {
        return hoje().minusDays(1);
    }

    protected LocalDate amanha() {
        return hoje().plusDays(1);
    }

    /** Sempre > 48h no futuro, não importa a hora corrente. */
    protected LocalDate foraDaJanela() {
        return hoje().plusDays(3);
    }

    // ---- Fixtures: usuários / alunos ----

    protected UUID appUserId(String samAccountName) {
        return appUserRepository.findBySamAccountNameIgnoreCase(samAccountName).orElseThrow().getId();
    }

    /**
     * Cria um segundo usuário local com papel ALUNO (o {@code DevDataSeeder} só semeia
     * um único "aluno") — usado nos testes que precisam de "outro aluno" real, com
     * login próprio via {@link #loginAs}, para exercitar RBAC/ownership de verdade.
     */
    protected UUID newAlunoUser(String samAccountName) {
        AppUser u = new AppUser();
        u.setSamAccountName(samAccountName);
        u.setNome("Aluno Extra " + samAccountName);
        u.setEmail(samAccountName + "@dev.secami");
        u.setTipoIdentidade("local");
        u.setAtivo(true);
        u.setPasswordHash(passwordEncoder.encode(DEV_PASSWORD));
        u.getRoles().add(Roles.ALUNO);
        return appUserRepository.save(u).getId();
    }

    protected UUID newMediaId() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "insert into media (id, tipo, storage_key) values (?, 'foto_aluno', ?)",
                id, "test/" + id + ".jpg");
        return id;
    }

    protected Student newStudent(String tipo) {
        Student s = new Student();
        s.setFullName("Aluno Teste " + SEQ.incrementAndGet());
        s.setCpf(randomCpf());
        s.setStudentType(tipo);
        s.setActive(true);
        return studentRepository.save(s);
    }

    protected Student civil() {
        return newStudent("Civil");
    }

    protected Student militar() {
        return newStudent("Militar");
    }

    protected Student comFoto(Student s) {
        s.setPhotoId(newMediaId());
        return studentRepository.save(s);
    }

    protected Student comAtestado(Student s, LocalDate data) {
        s.setAtestadoData(data);
        s.setAtestadoNumero("AT-" + SEQ.incrementAndGet());
        return studentRepository.save(s);
    }

    protected Student vinculadoAoUsuario(Student s, UUID userId) {
        s.setUserId(userId);
        return studentRepository.save(s);
    }

    protected String randomCpf() {
        return String.format("%011d", 10_000_000_000L + SEQ.incrementAndGet());
    }

    // ---- Fixtures: slot_config / blocked_date ----

    protected SlotConfig slot(String slotStart, int maxCapacity, boolean civilRestricted, boolean blocked) {
        SlotConfig s = slotConfigRepository.findBySlotStart(slotStart).orElseGet(SlotConfig::new);
        s.setSlotStart(slotStart);
        s.setSlotEnd(plusOneHour(slotStart));
        s.setMaxCapacity(maxCapacity);
        s.setCivilRestricted(civilRestricted);
        s.setBlocked(blocked);
        s.setBlockReason(blocked ? "Manutenção" : null);
        return slotConfigRepository.save(s);
    }

    protected SlotConfig slotAberto(String slotStart) {
        return slot(slotStart, 40, false, false);
    }

    protected BlockedDate blockDay(LocalDate date) {
        BlockedDate b = new BlockedDate();
        b.setDate(date);
        b.setReason("Feriado de teste");
        return blockedDateRepository.save(b);
    }

    protected BlockedDate blockSlot(LocalDate date, String slotStart) {
        BlockedDate b = new BlockedDate();
        b.setDate(date);
        b.setSlotStart(slotStart);
        b.setReason("Manutenção de teste");
        return blockedDateRepository.save(b);
    }

    protected String plusOneHour(String hhmm) {
        return LocalTime.parse(hhmm).plusHours(1).format(HHMM);
    }

    // ---- Fixtures: agendamentos pré-existentes (bypassa as regras, estado prévio) ----

    protected Appointment seedAppointment(Student student, LocalDate date, String slotStart, String status) {
        Appointment a = new Appointment();
        a.setStudent(student);
        a.setDate(date);
        a.setSlotStart(slotStart);
        a.setSlotEnd(plusOneHour(slotStart));
        a.setStatus(status);
        a.setForced(false);
        return appointmentRepository.save(a);
    }

    protected void seedCivilFillers(LocalDate date, String slotStart, int count) {
        for (int i = 0; i < count; i++) {
            seedAppointment(civil(), date, slotStart, Appointment.AGENDADO);
        }
    }

    protected CheckIn seedCheckIn(Student student, LocalDate date, UUID appointmentId) {
        CheckIn c = new CheckIn();
        c.setStudent(student);
        c.setDate(date);
        c.setCheckInTime(ZonedDateTime.now(zone()).format(HHMM));
        c.setAppointmentId(appointmentId);
        return checkInRepository.save(c);
    }

    // ---- MockMvc helpers ----

    protected record BookReq(LocalDate date, String slotStart) {}

    protected record ForceBookReq(UUID studentId, LocalDate date, String slotStart, String notes) {}

    protected record CheckInReq(UUID studentId, LocalDate date, String notes) {}

    protected MockHttpServletRequestBuilder withJsonBody(
            MockHttpServletRequestBuilder builder, String token, Object body) throws Exception {
        return authed(builder, token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body));
    }

    protected ResultActions bookAsStudent(String token, LocalDate date, String slotStart) throws Exception {
        return mockMvc.perform(withJsonBody(post("/me/appointments"), token, new BookReq(date, slotStart)));
    }

    protected ResultActions forceBook(
            String token, UUID studentId, LocalDate date, String slotStart, String notes) throws Exception {
        return mockMvc.perform(withJsonBody(
                post("/appointments"), token, new ForceBookReq(studentId, date, slotStart, notes)));
    }

    protected ResultActions doCheckIn(String token, UUID studentId, LocalDate date, String notes) throws Exception {
        return mockMvc.perform(withJsonBody(post("/checkins"), token, new CheckInReq(studentId, date, notes)));
    }

    protected ResultActions doCheckOut(String token, UUID checkInId) throws Exception {
        return mockMvc.perform(authed(patch("/checkins/{id}/checkout", checkInId), token));
    }

    protected ResultActions undoCheckIn(String token, UUID checkInId) throws Exception {
        return mockMvc.perform(authed(delete("/checkins/{id}", checkInId), token));
    }

    protected ResultActions marcarFalta(String token, UUID appointmentId) throws Exception {
        return mockMvc.perform(authed(patch("/appointments/{id}/falta", appointmentId), token));
    }

    protected ResultActions desfazerFalta(String token, UUID appointmentId) throws Exception {
        return mockMvc.perform(authed(patch("/appointments/{id}/desfazer-falta", appointmentId), token));
    }

    protected ResultActions cancelAppointment(String token, UUID appointmentId) throws Exception {
        return mockMvc.perform(authed(delete("/appointments/{id}", appointmentId), token));
    }

    protected JsonNode readJson(ResultActions ra) throws Exception {
        return objectMapper.readTree(ra.andReturn().getResponse().getContentAsString());
    }
}
