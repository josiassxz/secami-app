import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { AlertCircle, Pencil, Plus } from "lucide-react";

const empty = { slotStart: "", slotEnd: "", maxCapacity: 40, civilRestricted: false, blocked: false, blockReason: "" };

export default function SlotConfig() {
  const qc = useQueryClient();
  const [edit, setEdit] = useState<any>(null);
  const [open, setOpen] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const { data, isLoading } = useQuery({ queryKey: ["slots"], queryFn: () => api(`/slot-configs`) });

  const save = useMutation({
    mutationFn: (body: any) =>
      edit
        ? api(`/slot-configs/${edit.id}`, { method: "PUT", body: JSON.stringify(body) })
        : api(`/slot-configs`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["slots"] }); setOpen(false); setEdit(null); },
    onError: (e) => setErr(mensagemDeErro(e, "Não foi possível salvar o horário.")),
  });

  const [form, setForm] = useState<any>(empty);

  function openNew() { setEdit(null); setErr(null); setForm(empty); setOpen(true); }
  function openEdit(s: any) { setEdit(s); setErr(null); setForm({ ...s, blockReason: s.blockReason || "" }); setOpen(true); }

  return (
    <div>
      <PageHeader
        title="Configuração de Horários"
        subtitle={data ? `${data.length} janela${data.length === 1 ? "" : "s"} configurada${data.length === 1 ? "" : "s"}` : "Janelas de agendamento, capacidade e restrições"}
        actions={<Button onClick={openNew}><Plus className="h-4 w-4" /> Novo horário</Button>}
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
                      onClick={() => openEdit(s)}
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

      <Modal open={open} onClose={() => setOpen(false)} title={edit ? `Editar horário ${edit.slotStart}–${edit.slotEnd}` : "Novo horário"}
        footer={<>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => { setErr(null); save.mutate(form); }}>Salvar</Button>
        </>}>
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Início</Label>
              <Input type="time" value={form.slotStart} onChange={(e) => setForm({ ...form, slotStart: e.target.value })} />
            </div>
            <div>
              <Label>Fim</Label>
              <Input type="time" value={form.slotEnd} onChange={(e) => setForm({ ...form, slotEnd: e.target.value })} />
            </div>
          </div>
          <div>
            <Label>Capacidade máxima (civis)</Label>
            <Input type="number" value={form.maxCapacity}
              onChange={(e) => setForm({ ...form, maxCapacity: parseInt(e.target.value || "0") })} />
          </div>
          <div className="space-y-2">
            <label className="flex cursor-pointer items-center gap-2.5 rounded-md border border-line px-3 py-2.5 text-sm text-content transition-colors duration-fast ease-standard hover:bg-surface-alt">
              <input type="checkbox" className="h-4 w-4 cursor-pointer rounded border-line-input accent-brand" checked={form.civilRestricted}
                onChange={(e) => setForm({ ...form, civilRestricted: e.target.checked })} />
              Restrito a militares
            </label>
            <label className="flex cursor-pointer items-center gap-2.5 rounded-md border border-line px-3 py-2.5 text-sm text-content transition-colors duration-fast ease-standard hover:bg-surface-alt">
              <input type="checkbox" className="h-4 w-4 cursor-pointer rounded border-line-input accent-brand" checked={form.blocked}
                onChange={(e) => setForm({ ...form, blocked: e.target.checked })} />
              Bloqueado
            </label>
          </div>
          {form.blocked && (
            <div className="rounded-md border border-line bg-surface-alt/40 p-3">
              <Label>Motivo do bloqueio</Label>
              <Input value={form.blockReason} onChange={(e) => setForm({ ...form, blockReason: e.target.value })} />
            </div>
          )}

          {err && (
            <div className="flex items-start gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{err}</span>
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
}
