import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { Plus, Trash2 } from "lucide-react";

export default function BlockedDates() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ date: "", slotStart: "", reason: "" });
  const [confirmTarget, setConfirmTarget] = useState<any>(null);

  const { data, isLoading } = useQuery({ queryKey: ["blocked-dates"], queryFn: () => api(`/blocked-dates`) });
  const save = useMutation({
    mutationFn: (body: any) => api(`/blocked-dates`, { method: "POST", body: JSON.stringify({ ...body, slotStart: body.slotStart || null }) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["blocked-dates"] }); setOpen(false); setForm({ date: "", slotStart: "", reason: "" }); },
  });
  const del = useMutation({
    mutationFn: (id: string) => api(`/blocked-dates/${id}`, { method: "DELETE" }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["blocked-dates"] }); setConfirmTarget(null); },
  });

  return (
    <div>
      <PageHeader title="Datas Bloqueadas" subtitle="Feriados e bloqueios pontuais"
        actions={<Button onClick={() => setOpen(true)}><Plus className="h-4 w-4" /> Bloquear data</Button>} />
      <Card className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={5} />
        ) : (
          <Table>
            <THead><TR><TH>Data</TH><TH>Horário</TH><TH>Motivo</TH><TH></TH></TR></THead>
            <TBody>
              {(data || []).map((b: any) => (
                <TR key={b.id}>
                  <TD className="font-medium">{formatDate(b.date)}</TD>
                  <TD>{b.slotStart ? <span className="tabular-nums">{b.slotStart}</span> : <Badge tone="neutral">dia inteiro</Badge>}</TD>
                  <TD className="text-content-soft">{b.reason || "—"}</TD>
                  <TD className="text-right">
                    <Button variant="ghost" size="sm" aria-label={`Remover bloqueio de ${formatDate(b.date)}`} onClick={() => setConfirmTarget(b)}>
                      <Trash2 className="h-4 w-4 text-danger" />
                    </Button>
                  </TD>
                </TR>
              ))}
              {(data || []).length === 0 && <TR><TD colSpan={4} className="py-10 text-center text-content-soft">Nenhuma data bloqueada.</TD></TR>}
            </TBody>
          </Table>
        )}
      </Card>
      <Modal open={open} onClose={() => setOpen(false)} title="Bloquear data"
        footer={<>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>Salvar</Button>
        </>}>
        <div className="space-y-3">
          <div><Label>Data</Label><Input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></div>
          <div><Label>Horário (vazio = dia inteiro)</Label><Input placeholder="ex.: 07:00" value={form.slotStart} onChange={(e) => setForm({ ...form, slotStart: e.target.value })} /></div>
          <div><Label>Motivo</Label><Input value={form.reason} onChange={(e) => setForm({ ...form, reason: e.target.value })} /></div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!confirmTarget}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => del.mutate(confirmTarget.id)}
        loading={del.isPending}
        title="Remover bloqueio"
        message={confirmTarget && <>Tem certeza que deseja remover o bloqueio de <strong>{formatDate(confirmTarget.date)}</strong>?</>}
      />
    </div>
  );
}
