package br.gov.goias.secami.jobs;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.checkin.CheckInRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Base comum aos testes dos jobs agendados ({@link AbsenceService},
 * {@link ReminderService}) — cria {@code Student}/{@code Appointment}/
 * {@code CheckIn} diretamente via repositório (esses jobs não têm endpoint de
 * escrita próprio, agem em cima de dados já existentes).
 */
public abstract class JobsTestSupport extends AbstractIntegrationTest {

    protected static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");

    @Autowired protected StudentRepository studentRepository;
    @Autowired protected AppointmentRepository appointmentRepository;
    @Autowired protected CheckInRepository checkInRepository;

    protected Student createStudent(String label, String email) {
        Student s = new Student();
        s.setFullName("Aluno Job " + label + " " + UUID.randomUUID());
        s.setStudentType("Civil");
        s.setEmail(email);
        s.setActive(true);
        return studentRepository.save(s);
    }

    protected Appointment createAppointment(Student student, LocalDate date, LocalTime slotStart, String status) {
        return createAppointment(student, date, slotStart, status, false);
    }

    protected Appointment createAppointment(Student student, LocalDate date, LocalTime slotStart, String status,
                                            boolean lembreteEnviado) {
        Appointment a = new Appointment();
        a.setStudent(student);
        a.setDate(date);
        a.setSlotStart(slotStart.format(HHMM));
        a.setSlotEnd(slotStart.plusHours(1).format(HHMM));
        a.setStatus(status);
        a.setLembreteEnviado(lembreteEnviado);
        return appointmentRepository.save(a);
    }

    protected CheckIn createCheckIn(Student student, LocalDate date, LocalTime time) {
        CheckIn c = new CheckIn();
        c.setStudent(student);
        c.setDate(date);
        c.setCheckInTime(time.format(HHMM));
        return checkInRepository.save(c);
    }
}
