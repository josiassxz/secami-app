package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.appointment.AppointmentDtos.AvailableSlot;
import br.gov.goias.secami.academy.appointment.AppointmentDtos.ScheduleSlot;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.config.SecamiProperties;
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
 * Janela de 48h, máx. 2 ativos, 1/dia, capacidade de civis, foto e atestado.
 */
@Service
public class SchedulingService {

    private static final int MAX_ATIVOS = 2;
    private static final int JANELA_HORAS = 48;

    private final AppointmentRepository appointments;
    private final SlotConfigRepository slots;
    private final BlockedDateRepository blockedDates;
    private final StudentRepository students;
    private final ZoneId zone;

    public SchedulingService(AppointmentRepository appointments, SlotConfigRepository slots,
                             BlockedDateRepository blockedDates, StudentRepository students,
                             SecamiProperties props) {
        this.appointments = appointments;
        this.slots = slots;
        this.blockedDates = blockedDates;
        this.students = students;
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
        ZonedDateTime now = ZonedDateTime.now(zone);
        LocalDate hoje = now.toLocalDate();
        boolean civil = isCivil(student);

        SlotConfig slot = slots.findBySlotStart(slotStart)
                .orElseThrow(() -> new BusinessException("Horário indisponível."));

        // Gates comuns a aluno e staff: foto + atestado (Civil).
        if (student.getPhotoId() == null) {
            throw new BusinessException("Foto obrigatória para reconhecimento facial da catraca.");
        }
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
        return appointments.save(a);
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
