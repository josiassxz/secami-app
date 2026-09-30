package br.gov.goias.secami.academy.slot;

import br.gov.goias.secami.academy.slot.SlotDtos.*;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/** Config de horários (slots) e datas bloqueadas. Escrita admin/gerente. SPEC §11.1. */
@RestController
public class SlotController {

    private final SlotConfigRepository slots;
    private final BlockedDateRepository blocked;

    public SlotController(SlotConfigRepository slots, BlockedDateRepository blocked) {
        this.slots = slots;
        this.blocked = blocked;
    }

    // ---- Slot config ----

    @GetMapping("/slot-configs")
    public List<SlotConfigResponse> listSlots() {
        return slots.findAllByOrderBySlotStartAsc().stream().map(SlotConfigResponse::from).toList();
    }

    @PostMapping("/slot-configs")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public SlotConfigResponse upsertSlot(@Valid @RequestBody SlotConfigUpsert req) {
        validarJanela(req);
        SlotConfig s = slots.findBySlotStart(req.slotStart()).orElseGet(SlotConfig::new);
        s.setSlotStart(req.slotStart());
        s.setSlotEnd(req.slotEnd());
        if (req.maxCapacity() != null) s.setMaxCapacity(req.maxCapacity());
        if (req.civilRestricted() != null) s.setCivilRestricted(req.civilRestricted());
        if (req.blocked() != null) s.setBlocked(req.blocked());
        s.setBlockReason(req.blockReason());
        return SlotConfigResponse.from(slots.save(s));
    }

    @PutMapping("/slot-configs/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public SlotConfigResponse updateSlot(@PathVariable UUID id, @Valid @RequestBody SlotConfigUpsert req) {
        validarJanela(req);
        SlotConfig s = slots.findById(id)
                .orElseThrow(() -> new NotFoundException("Horário não encontrado."));
        if (!req.slotStart().equals(s.getSlotStart()) && slots.findBySlotStart(req.slotStart()).isPresent()) {
            throw new ConflictException("Já existe um horário configurado para " + req.slotStart() + ".");
        }
        s.setSlotStart(req.slotStart());
        s.setSlotEnd(req.slotEnd());
        if (req.maxCapacity() != null) s.setMaxCapacity(req.maxCapacity());
        if (req.civilRestricted() != null) s.setCivilRestricted(req.civilRestricted());
        if (req.blocked() != null) s.setBlocked(req.blocked());
        s.setBlockReason(req.blockReason());
        return SlotConfigResponse.from(slots.save(s));
    }

    private static void validarJanela(SlotConfigUpsert req) {
        if (!LocalTime.parse(req.slotEnd()).isAfter(LocalTime.parse(req.slotStart()))) {
            throw new BusinessException("O horário final precisa ser depois do horário inicial.");
        }
    }

    // ---- Blocked dates ----

    @GetMapping("/blocked-dates")
    public List<BlockedDateResponse> listBlocked() {
        return blocked.findByDateGreaterThanEqualOrderByDateAsc(LocalDate.now())
                .stream().map(BlockedDateResponse::from).toList();
    }

    @PostMapping("/blocked-dates")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public BlockedDateResponse createBlocked(@Valid @RequestBody BlockedDateCreate req) {
        BlockedDate b = new BlockedDate();
        b.setDate(req.date());
        b.setSlotStart(req.slotStart());
        b.setReason(req.reason());
        return BlockedDateResponse.from(blocked.save(b));
    }

    @DeleteMapping("/blocked-dates/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public void deleteBlocked(@PathVariable UUID id) {
        blocked.deleteById(id);
    }
}
