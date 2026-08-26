import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { Pencil } from "lucide-react";

export default function SlotConfig() {
  const qc = useQueryClient();
  const [edit, setEdit] = useState<any>(null);
  const { data, isLoading } = useQuery({ queryKey: ["slots"], queryFn: () => api(`/slot-configs`) });

  const save = useMutation({
    mutationFn: (body: any) => api(`/slot-configs/${body.id}`, { method: "PUT", body: JSON.stringify(body) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["slots"] }); setEdit(null); },
  });

  return (
    <div>
      <PageHeader
        title="Configuração de Horários"
        subtitle={data ? `${data.length} janela${data.length === 1 ? "" : "s"} de 1h configurada${data.length === 1 ? "" : "s"}` : "Janelas de 1h, capacidade e restrições"}
      />
      <Card className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={6} />
        ) : (
          <Table>
            <THead><TR><TH>Horário</TH><TH>Capacidade (civis)</TH><TH>Restrições</TH><TH></TH></TR></THead>
            <TBody>
              {(data || []).map((s: any) => (
                <TR key={s.id}>
                  <TD className="font-semibold tabular-nums">{s.slotStart}–{s.slotEnd}</TD>
                  <TD className="tabular-nums">{s.maxCapacity}</TD>
                  <TD>
                    <div className="flex flex-wrap gap-1">
                      {s.blocked && <Badge tone="faltou">bloqueado</Badge>}
                      {s.civilRestricted && <Badge tone="warning">só militares</Badge>}
                      {!s.blocked && !s.civilRestricted && <span className="text-content-faint">—</span>}
                    </div>
                  </TD>
                  <TD className="text-right">
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={`Editar horário ${s.slotStart}–${s.slotEnd}`}
                      onClick={() => setEdit({ ...s })}
                    >
                      <Pencil className="h-4 w-4" />
                    </Button>
                  </TD>
                </TR>
              ))}
              {(data || []).length === 0 && (
                <TR><TD colSpan={4} className="py-10 text-center text-content-soft">Nenhum horário configurado.</TD></TR>
              )}
            </TBody>
          </Table>
        )}
      </Card>

      <Modal open={!!edit} onClose={() => setEdit(null)} title={edit ? `Horário ${edit.slotStart}–${edit.slotEnd}` : ""}
        footer={edit && <>
          <Button variant="outline" onClick={() => setEdit(null)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => save.mutate(edit)}>Salvar</Button>
        </>}>
        {edit && (
          <div className="space-y-3">
            <div>
              <Label>Capacidade máxima (civis)</Label>
              <Input type="number" value={edit.maxCapacity}
                onChange={(e) => setEdit({ ...edit, maxCapacity: parseInt(e.target.value || "0") })} />
            </div>
            <div className="space-y-2">
              <label className="flex cursor-pointer items-center gap-2.5 rounded-md border border-line px-3 py-2.5 text-sm text-content transition-colors duration-fast ease-standard hover:bg-surface-alt">
                <input type="checkbox" className="h-4 w-4 cursor-pointer rounded border-line-input accent-brand" checked={edit.civilRestricted}
                  onChange={(e) => setEdit({ ...edit, civilRestricted: e.target.checked })} />
                Restrito a militares
              </label>
              <label className="flex cursor-pointer items-center gap-2.5 rounded-md border border-line px-3 py-2.5 text-sm text-content transition-colors duration-fast ease-standard hover:bg-surface-alt">
                <input type="checkbox" className="h-4 w-4 cursor-pointer rounded border-line-input accent-brand" checked={edit.blocked}
                  onChange={(e) => setEdit({ ...edit, blocked: e.target.checked })} />
                Bloqueado
              </label>
            </div>
            {edit.blocked && (
              <div className="rounded-md border border-line bg-surface-alt/40 p-3">
                <Label>Motivo do bloqueio</Label>
                <Input value={edit.blockReason || ""} onChange={(e) => setEdit({ ...edit, blockReason: e.target.value })} />
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
