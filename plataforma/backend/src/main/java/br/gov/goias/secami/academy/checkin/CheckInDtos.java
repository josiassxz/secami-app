package br.gov.goias.secami.academy.checkin;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
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
}
