package br.gov.goias.secami.academy.appointment;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class AppointmentDtos {

    private AppointmentDtos() {}

    public record Response(
            UUID id, UUID studentId, String studentName, String studentType,
            LocalDate date, String slotStart, String slotEnd,
            String status, boolean forced, String notes) {
        public static Response from(Appointment a) {
            var s = a.getStudent();
            return new Response(a.getId(), s.getId(), s.getFullName(), s.getStudentType(),
                    a.getDate(), a.getSlotStart(), a.getSlotEnd(),
                    a.getStatus(), a.isForced(), a.getNotes());
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
}
