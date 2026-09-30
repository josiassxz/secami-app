package br.gov.goias.secami.academy.checkin;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import jakarta.validation.constraints.NotNull;

import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public final class CheckInDtos {

    private CheckInDtos() {}

    public record Response(
            UUID id, UUID studentId, String studentName, UUID appointmentId,
            LocalDate date, String checkInTime, String checkOutTime, String notes) {
        public static Response from(CheckIn c) {
            return new Response(c.getId(), c.getStudent().getId(), c.getStudent().getFullName(),
                    c.getAppointmentId(), c.getDate(), c.getCheckInTime(), c.getCheckOutTime(), c.getNotes());
        }
    }

    public record CheckInRequest(
            @NotNull(message = "Informe o aluno.") UUID studentId,
            LocalDate date,          // default hoje
            String notes
    ) {}

    /** Uma linha do resumo do dia (tela de check-in): junta o agendamento
     *  (com status — inclui "faltou"), o check-in autodeclarado (se houve) e
     *  a confirmação real de entrada/saída pela catraca. Alunos que fizeram
     *  check-in sem agendamento (visita espontânea) também aparecem, sem
     *  dados de agendamento. */
    public record ResumoDia(
            UUID studentId, String studentName, String studentType,
            UUID appointmentId, String slotStart, String slotEnd, String status,
            UUID checkInId, String checkInTime, String checkOutTime,
            OffsetDateTime entradaConfirmadaEm, OffsetDateTime saidaConfirmadaEm,
            Long permanenciaMinutos) {

        public static ResumoDia deAgendamento(Appointment a, CheckIn c) {
            Student s = a.getStudent();
            OffsetDateTime entrada = a.getEntradaConfirmadaEm();
            OffsetDateTime saida = a.getSaidaConfirmadaEm();
            return new ResumoDia(s.getId(), s.getFullName(), s.getStudentType(),
                    a.getId(), a.getSlotStart(), a.getSlotEnd(), a.getStatus(),
                    c != null ? c.getId() : null,
                    c != null ? c.getCheckInTime() : null,
                    c != null ? c.getCheckOutTime() : null,
                    entrada, saida, permanencia(entrada, saida));
        }

        public static ResumoDia deVisitaEspontanea(CheckIn c) {
            Student s = c.getStudent();
            return new ResumoDia(s.getId(), s.getFullName(), s.getStudentType(),
                    null, null, null, null,
                    c.getId(), c.getCheckInTime(), c.getCheckOutTime(),
                    null, null, null);
        }

        /** Null se ainda não confirmado, ou se vier invertido — a catraca real
         *  ocasionalmente grava entrada/saída a poucos segundos uma da outra e
         *  fora de ordem (visto em produção); melhor não mostrar do que
         *  mostrar uma permanência negativa. */
        private static Long permanencia(OffsetDateTime entrada, OffsetDateTime saida) {
            if (entrada == null || saida == null) return null;
            Duration duracao = Duration.between(entrada, saida);
            // isNegative(), não toMinutes() < 0: uma diferença de poucos
            // segundos trunca pra 0 em minutos inteiros e passaria pelo
            // ">= 0" mesmo com saída antes da entrada.
            return duracao.isNegative() ? null : duracao.toMinutes();
        }
    }
}
