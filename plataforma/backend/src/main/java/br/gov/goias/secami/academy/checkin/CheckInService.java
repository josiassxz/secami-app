package br.gov.goias.secami.academy.checkin;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.config.SecamiProperties;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Presença: check-in/out manual e marcação de falta. SPEC §9.5. */
@Service
public class CheckInService {

    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");

    private final CheckInRepository checkins;
    private final AppointmentRepository appointments;
    private final StudentRepository students;
    private final ZoneId zone;

    public CheckInService(CheckInRepository checkins, AppointmentRepository appointments,
                          StudentRepository students, SecamiProperties props) {
        this.checkins = checkins;
        this.appointments = appointments;
        this.students = students;
        this.zone = ZoneId.of(props.getTimezone());
    }

    @Transactional(readOnly = true)
    public List<CheckIn> byDate(LocalDate date) {
        return checkins.findByDate(date);
    }

    /** Junta agendamentos do dia (com status, inclui "faltou") + check-in
     *  autodeclarado (se houve) + confirmação real de entrada/saída pela
     *  catraca — visão completa pra recepção/admin, não só quem já fez
     *  check-in. Visitas sem agendamento (check-in espontâneo) também
     *  aparecem, ao final. */
    @Transactional(readOnly = true)
    public List<CheckInDtos.ResumoDia> resumoDoDia(LocalDate date) {
        List<Appointment> agendamentos = appointments.findByDateAndDeletedAtIsNull(date);
        List<CheckIn> checkinsDoDia = checkins.findByDate(date);

        Map<UUID, CheckIn> porAgendamento = new HashMap<>();
        List<CheckIn> semAgendamento = new ArrayList<>();
        for (CheckIn c : checkinsDoDia) {
            if (c.getAppointmentId() != null) {
                porAgendamento.put(c.getAppointmentId(), c);
            } else {
                semAgendamento.add(c);
            }
        }

        List<CheckInDtos.ResumoDia> linhas = new ArrayList<>();
        for (Appointment a : agendamentos) {
            if (Appointment.CANCELADO.equals(a.getStatus())) continue;
            linhas.add(CheckInDtos.ResumoDia.deAgendamento(a, porAgendamento.get(a.getId())));
        }
        for (CheckIn c : semAgendamento) {
            linhas.add(CheckInDtos.ResumoDia.deVisitaEspontanea(c));
        }
        return linhas;
    }

    @Transactional
    public CheckIn checkIn(UUID studentId, LocalDate date, String notes, UUID actor) {
        LocalDate dia = date != null ? date : LocalDate.now(zone);
        Student student = students.findByIdAndDeletedAtIsNull(studentId)
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));

        if (checkins.countByStudentIdAndDate(studentId, dia) > 0) {
            throw new BusinessException("Aluno já possui check-in nesta data.");
        }

        CheckIn c = new CheckIn();
        c.setStudent(student);
        c.setDate(dia);
        c.setCheckInTime(LocalTime.now(zone).format(HHMM));
        c.setNotes(notes);
        c.setCreatedBy(actor);

        // Vincula ao agendamento ativo do dia, se houver, e confirma o agendamento.
        List<Appointment> ativos = appointments.findAtivosDoDia(studentId, dia);
        if (!ativos.isEmpty()) {
            Appointment appt = ativos.get(0);
            c.setAppointmentId(appt.getId());
            if (Appointment.AGENDADO.equals(appt.getStatus())) {
                appt.setStatus(Appointment.CONFIRMADO);
                appointments.save(appt);
            }
        }
        return checkins.save(c);
    }

    @Transactional
    public CheckIn checkOut(UUID checkInId) {
        CheckIn c = require(checkInId);
        c.setCheckOutTime(LocalTime.now(zone).format(HHMM));
        return checkins.save(c);
    }

    @Transactional
    public void undo(UUID checkInId) {
        checkins.deleteById(checkInId);
    }

    @Transactional
    public void marcarFalta(UUID appointmentId) {
        Appointment a = appointments.findById(appointmentId)
                .orElseThrow(() -> new NotFoundException("Agendamento não encontrado."));
        a.setStatus(Appointment.FALTOU);
        appointments.save(a);
    }

    @Transactional
    public void desfazerFalta(UUID appointmentId) {
        Appointment a = appointments.findById(appointmentId)
                .orElseThrow(() -> new NotFoundException("Agendamento não encontrado."));
        a.setStatus(Appointment.AGENDADO);
        appointments.save(a);
    }

    private CheckIn require(UUID id) {
        return checkins.findByIdWithStudent(id)
                .orElseThrow(() -> new NotFoundException("Check-in não encontrado."));
    }
}
