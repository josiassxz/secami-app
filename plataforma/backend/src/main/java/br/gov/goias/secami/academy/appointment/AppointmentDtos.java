package br.gov.goias.secami.academy.appointment;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class AppointmentDtos {

    private AppointmentDtos() {}

    public record Response(
            UUID id, UUID studentId, String studentName, String studentType,
            LocalDate date, String slotStart, String slotEnd,
            String status, boolean forced, String notes,
            OffsetDateTime entradaConfirmadaEm, OffsetDateTime saidaConfirmadaEm,
            Long permanenciaMinutos) {
        public static Response from(Appointment a) {
            var s = a.getStudent();
            OffsetDateTime entrada = a.getEntradaConfirmadaEm();
            OffsetDateTime saida = a.getSaidaConfirmadaEm();
            return new Response(a.getId(), s.getId(), s.getFullName(), s.getStudentType(),
                    a.getDate(), a.getSlotStart(), a.getSlotEnd(),
                    a.getStatus(), a.isForced(), a.getNotes(),
                    entrada, saida, permanenciaMinutos(entrada, saida));
        }

        /** Null se entrada/saída ainda não foram confirmadas, ou se vierem
         *  invertidas — a catraca real ocasionalmente grava os dois eventos a
         *  poucos segundos um do outro e fora de ordem (visto em produção);
         *  melhor não mostrar do que mostrar uma permanência negativa. */
        private static Long permanenciaMinutos(OffsetDateTime entrada, OffsetDateTime saida) {
            if (entrada == null || saida == null) return null;
            Duration duracao = Duration.between(entrada, saida);
            // isNegative(), não toMinutes() < 0: uma diferença de poucos
            // segundos trunca pra 0 em minutos inteiros e passaria pelo
            // ">= 0" mesmo com saída antes da entrada.
            return duracao.isNegative() ? null : duracao.toMinutes();
        }
    }

    /** Slot ofertado para o aluno agendar. */
    public record AvailableSlot(
            String slotStart, String slotEnd, int maxCapacity,
            long civilCount, boolean available, String reason) {}

    /** Uma célula da grade (por slot, numa data). */
    public record ScheduleSlot(
            String slotStart, String slotEnd, int maxCapacity,
            boolean blocked, boolean civilRestricted,
            long civilCount, long militarCount, List<Response> appointments) {}

    public record StudentBookRequest(
            @NotNull(message = "Informe a data.") LocalDate date,
            @NotBlank(message = "Informe o horário.") String slotStart
    ) {}

    public record StaffBookRequest(
            @NotNull(message = "Informe o aluno.") UUID studentId,
            @NotNull(message = "Informe a data.") LocalDate date,
            @NotBlank(message = "Informe o horário.") String slotStart,
            String notes
    ) {}

    /** KPIs agregados para os cards de resumo da aba Relatórios. */
    public record SummaryResponse(
            long agendado, long confirmado, long faltou, long cancelado,
            Double permanenciaMediaMinutos, double taxaFalta,
            long confirmadosCatraca) {}
}
