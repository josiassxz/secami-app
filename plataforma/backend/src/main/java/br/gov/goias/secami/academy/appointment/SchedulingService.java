package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.appointment.AppointmentDtos.AvailableSlot;
import br.gov.goias.secami.academy.appointment.AppointmentDtos.ScheduleSlot;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.accelero.AcceleroSyncService;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.config.SecamiProperties;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Motor de agendamento — todas as regras da SPEC §9.4 no servidor.
 * Janela de 48h, máx. 2 ativos, 1/dia, capacidade de civis, atestado (Civil).
 */
@Service
public class SchedulingService {

    private static final int MAX_ATIVOS = 2;
    private static final int JANELA_HORAS = 48;

    private final AppointmentRepository appointments;
    private final SlotConfigRepository slots;
    private final BlockedDateRepository blockedDates;
    private final StudentRepository students;
    private final AcceleroSyncService acceleroSync;
    private final ZoneId zone;

    public SchedulingService(AppointmentRepository appointments, SlotConfigRepository slots,
                             BlockedDateRepository blockedDates, StudentRepository students,
                             AcceleroSyncService acceleroSync, SecamiProperties props) {
        this.appointments = appointments;
        this.slots = slots;
        this.blockedDates = blockedDates;
        this.students = students;
        this.acceleroSync = acceleroSync;
        this.zone = ZoneId.of(props.getTimezone());
    }

    private boolean isCivil(Student s) {
        return s.getStudentType() == null || "Civil".equalsIgnoreCase(s.getStudentType());
    }

    private ZonedDateTime slotDateTime(LocalDate date, String slotStart) {
        return ZonedDateTime.of(date, LocalTime.parse(slotStart), zone);
    }

    // ---- Slots disponíveis para o aluno ----

    @Transactional(readOnly = true)
    public List<AvailableSlot> availableSlots(UUID userId, LocalDate date) {
        Student student = students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        ZonedDateTime now = ZonedDateTime.now(zone);
        List<BlockedDate> blocks = blockedDates.findByDate(date);
        boolean diaBloqueado = blocks.stream()
                .anyMatch(b -> b.getSlotStart() == null || b.getSlotStart().isBlank());
        boolean civil = isCivil(student);

        List<AvailableSlot> result = new ArrayList<>();
        for (SlotConfig s : slots.findAllByOrderBySlotStartAsc()) {
            ZonedDateTime sdt = slotDateTime(date, s.getSlotStart());
            long civilCount = appointments.countCivisNoSlot(date, s.getSlotStart());
            String reason = null;
            if (!sdt.isAfter(now)) reason = "Horário já passou";
            else if (sdt.isAfter(now.plusHours(JANELA_HORAS))) reason = "Fora da janela de 48h";
            else if (s.isBlocked()) reason = s.getBlockReason() != null ? s.getBlockReason() : "Horário bloqueado";
            else if (civil && s.isCivilRestricted()) reason = "Restrito a militares";
            else if (diaBloqueado) reason = "Data bloqueada";
            else if (blocks.stream().anyMatch(b -> s.getSlotStart().equals(b.getSlotStart())))
                reason = "Horário bloqueado nesta data";
            else if (civil && civilCount >= s.getMaxCapacity()) reason = "Horário cheio para civis";

            result.add(new AvailableSlot(s.getSlotStart(), s.getSlotEnd(), s.getMaxCapacity(),
                    civilCount, reason == null, reason));
        }
        return result;
    }

    // ---- Agendamento pelo aluno ----

    @Transactional
    public Appointment bookAsStudent(UUID userId, LocalDate date, String slotStart) {
        Student student = students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        return doBook(student, date, slotStart, false, null, userId);
    }

    // ---- Force-book pela recepção/gestão ----

    @Transactional
    public Appointment forceBook(UUID studentId, LocalDate date, String slotStart, String notes, UUID actor) {
        Student student = students.findByIdAndDeletedAtIsNull(studentId)
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
        return doBook(student, date, slotStart, true, notes, actor);
    }

    private Appointment doBook(Student student, LocalDate date, String slotStart,
                               boolean staff, String notes, UUID actor) {
        // Instrutor não é aluno: não ocupa vaga de horário (vale pro próprio
        // e pro encaixe feito pela recepção).
        if (student.isInstrutor()) {
            throw new BusinessException("O perfil de instrutor não faz agendamento de horário.");
        }
        ZonedDateTime now = ZonedDateTime.now(zone);
        LocalDate hoje = now.toLocalDate();
        boolean civil = isCivil(student);

        SlotConfig slot = slots.findBySlotStart(slotStart)
                .orElseThrow(() -> new BusinessException("Horário indisponível."));

        // Gate comum a aluno e staff: atestado (Civil). Não exige foto aqui —
        // o reconhecimento facial na catraca é feito com a foto que já existe
        // no Accelero (pessoa vinculada por CPF), não com uma cópia própria
        // deste sistema; exigir isso bloquearia todo mundo, já que nem o
        // cadastro público nem a migração do legado preenchem esse campo.
        if (civil && !student.atestadoValido(hoje)) {
            throw new BusinessException("Atestado médico ausente ou vencido (validade de 1 ano).");
        }

        if (!staff) {
            ZonedDateTime sdt = slotDateTime(date, slotStart);
            if (!sdt.isAfter(now)) {
                throw new BusinessException("Não é possível agendar em horário passado.");
            }
            if (sdt.isAfter(now.plusHours(JANELA_HORAS))) {
                throw new BusinessException("Só é possível agendar com até 48h de antecedência.");
            }
            if (slot.isBlocked()) {
                throw new BusinessException(slot.getBlockReason() != null ? slot.getBlockReason() : "Horário bloqueado.");
            }
            if (civil && slot.isCivilRestricted()) {
                throw new BusinessException("Horário restrito a militares.");
            }
            List<BlockedDate> blocks = blockedDates.findByDate(date);
            boolean bloqueado = blocks.stream().anyMatch(b ->
                    b.getSlotStart() == null || b.getSlotStart().isBlank() || slotStart.equals(b.getSlotStart()));
            if (bloqueado) {
                throw new BusinessException("Data ou horário bloqueado.");
            }
            if (appointments.countAtivosFuturos(student.getId(), hoje) >= MAX_ATIVOS) {
                throw new BusinessException("Você já possui 2 agendamentos ativos.");
            }
            if (appointments.countAtivosNoDia(student.getId(), date) >= 1) {
                throw new BusinessException("Você já possui um agendamento neste dia.");
            }
            if (civil && appointments.countCivisNoSlot(date, slotStart) >= slot.getMaxCapacity()) {
                throw new BusinessException("Horário cheio para civis.");
            }
        }

        // Sem duplicado exato (aplicado a aluno e staff).
        if (appointments.countAtivosNoSlot(student.getId(), date, slotStart) >= 1) {
            throw new ConflictException("Já existe agendamento neste horário.");
        }

        Appointment a = new Appointment();
        a.setStudent(student);
        a.setDate(date);
        a.setSlotStart(slotStart);
        a.setSlotEnd(slot.getSlotEnd());
        a.setStatus(Appointment.AGENDADO);
        a.setForced(staff);
        a.setNotes(notes);
        a.setCreatedBy(actor);
        a = appointments.save(a);
        // Libera a entrada na catraca pra este horário específico (Civil —
        // Militar já tem entrada vitalícia desde a aprovação). Best-effort,
        // nunca impede o agendamento.
        acceleroSync.aoAgendar(a);
        return a;
    }

    @Transactional
    public void cancel(UUID appointmentId, UUID requesterUserId, boolean staff) {
        Appointment a = appointments.findById(appointmentId)
                .orElseThrow(() -> new NotFoundException("Agendamento não encontrado."));
        if (!staff) {
            UUID ownerUser = a.getStudent().getUserId();
            if (ownerUser == null || !ownerUser.equals(requesterUserId)) {
                throw new BusinessException("Você só pode cancelar os seus agendamentos.");
            }
        }
        a.setStatus(Appointment.CANCELADO);
        appointments.save(a);
        // Revoga a entrada liberada dinamicamente pra este horário, se houver.
        acceleroSync.aoCancelar(a);
    }

    @Transactional(readOnly = true)
    public List<Appointment> myAppointments(UUID userId) {
        Student student = students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        return appointments.findByStudent(student.getId());
    }

    @Transactional(readOnly = true)
    public List<Appointment> byRange(LocalDate from, LocalDate to) {
        return appointments.findByDateRange(from, to);
    }

    /** Histórico de agendamentos do aluno num período (para modal de detalhes). */
    @Transactional(readOnly = true)
    public List<Appointment> getStudentHistory(UUID studentId, LocalDate from, LocalDate to) {
        if (!students.existsById(studentId)) {
            throw new NotFoundException("Aluno não encontrado.");
        }
        return appointments.findByStudentIdAndDateBetween(studentId, from, to);
    }

    // ---- Relatórios: listagem filtrada/paginada + resumo agregado ----

    @Transactional(readOnly = true)
    public org.springframework.data.domain.Page<Appointment> byRangeFiltered(
            LocalDate from, LocalDate to, String status, String q,
            org.springframework.data.domain.Pageable pageable) {
        String s = (status == null || status.isBlank()) ? null : status.trim();
        String term = (q == null || q.isBlank()) ? null : q.trim();
        return appointments.findByDateRangeFiltered(from, to, s, term, pageable);
    }

    @Transactional(readOnly = true)
    public AppointmentDtos.SummaryResponse summarize(LocalDate from, LocalDate to, String status, String q) {
        String s = (status == null || status.isBlank()) ? null : status.trim();
        String term = (q == null || q.isBlank()) ? null : q.trim();
        List<Object[]> rows = appointments.summarizeByRange(from, to, s, term);
        long agendado = 0, confirmado = 0, faltou = 0, cancelado = 0;
        double somaPermanencia = 0;
        long countPermanencia = 0;
        long confirmadosCatraca = 0;
        for (Object[] r : rows) {
            String st = (String) r[0];
            long cnt = ((Number) r[1]).longValue();
            switch (st) {
                case Appointment.AGENDADO -> agendado = cnt;
                case Appointment.CONFIRMADO -> confirmado = cnt;
                case Appointment.FALTOU -> faltou = cnt;
                case Appointment.CANCELADO -> cancelado = cnt;
            }
            if (r[2] != null) {
                somaPermanencia += ((Number) r[2]).doubleValue() * cnt;
                countPermanencia += cnt;
            }
            if (r[3] != null) {
                confirmadosCatraca += ((Number) r[3]).longValue();
            }
        }
        long totalNaoCancelado = agendado + confirmado + faltou;
        double taxaFalta = totalNaoCancelado > 0 ? (double) faltou / totalNaoCancelado : 0.0;
        Double permanenciaMedia = countPermanencia > 0 ? somaPermanencia / countPermanencia : null;
        return new AppointmentDtos.SummaryResponse(
                agendado, confirmado, faltou, cancelado,
                permanenciaMedia, taxaFalta, confirmadosCatraca);
    }

    // ---- Grade (visão staff) ----

    @Transactional(readOnly = true)
    public List<ScheduleSlot> schedule(LocalDate date) {
        List<Appointment> dayAppts = appointments.findByDateAndDeletedAtIsNull(date).stream()
                .filter(a -> !Appointment.CANCELADO.equals(a.getStatus()))
                .toList();
        List<ScheduleSlot> result = new ArrayList<>();
        for (SlotConfig s : slots.findAllByOrderBySlotStartAsc()) {
            List<Appointment> inSlot = dayAppts.stream()
                    .filter(a -> s.getSlotStart().equals(a.getSlotStart()))
                    .toList();
            long civil = inSlot.stream().filter(a -> isCivil(a.getStudent())).count();
            long militar = inSlot.size() - civil;
            result.add(new ScheduleSlot(
                    s.getSlotStart(), s.getSlotEnd(), s.getMaxCapacity(),
                    s.isBlocked(), s.isCivilRestricted(), civil, militar,
                    inSlot.stream().map(AppointmentDtos.Response::from).toList()));
        }
        return result;
    }
}
