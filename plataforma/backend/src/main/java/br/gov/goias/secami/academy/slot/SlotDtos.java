package br.gov.goias.secami.academy.slot;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.time.LocalDate;
import java.util.UUID;

public final class SlotDtos {

    private SlotDtos() {}

    public record SlotConfigResponse(
            UUID id, String slotStart, String slotEnd, int maxCapacity,
            boolean civilRestricted, boolean blocked, String blockReason) {
        public static SlotConfigResponse from(SlotConfig s) {
            return new SlotConfigResponse(s.getId(), s.getSlotStart(), s.getSlotEnd(),
                    s.getMaxCapacity(), s.isCivilRestricted(), s.isBlocked(), s.getBlockReason());
        }
    }

    private static final String HHMM = "^([01]\\d|2[0-3]):[0-5]\\d$";

    public record SlotConfigUpsert(
            @NotBlank @Pattern(regexp = HHMM, message = "Use o formato HH:mm.") String slotStart,
            @NotBlank @Pattern(regexp = HHMM, message = "Use o formato HH:mm.") String slotEnd,
            Integer maxCapacity,
            Boolean civilRestricted,
            Boolean blocked,
            String blockReason
    ) {}

    public record BlockedDateResponse(UUID id, LocalDate date, String slotStart, String reason) {
        public static BlockedDateResponse from(BlockedDate b) {
            return new BlockedDateResponse(b.getId(), b.getDate(), b.getSlotStart(), b.getReason());
        }
    }

    public record BlockedDateCreate(
            @NotNull(message = "Informe a data.") LocalDate date,
            String slotStart,        // null = dia inteiro
            String reason
    ) {}
}
