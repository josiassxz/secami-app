import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { AlertCircle, DoorOpen, Pencil, Plus, Trash2 } from "lucide-react";

const empty = { slotStart: "", slotEnd: "", maxCapacity: 40, civilRestricted: false, blocked: false, blockReason: "" };

/** Quanto tempo a catraca fica liberada pro civil a partir do horário marcado. */
function JanelaCatraca() {
  const qc = useQueryClient();
  const atual = useQuery({
    queryKey: ["config-catraca"],
    queryFn: () => api<{ janelaHoras: number }>(`/admin/configuracoes/catraca`),
  });
  const [horas, setHoras] = useState<string | null>(null);
  const valor = horas ?? (atual.data ? String(atual.data.janelaHoras) : "");
  const salvar = useMutation({
    mutationFn: (janelaHoras: number) =>
      api<{ janelaHoras: number }>(`/admin/configuracoes/catraca`, { method: "PUT", body: JSON.stringify({ janelaHoras }) }),
    onSuccess: (r) => {
      qc.setQueryData(["config-catraca"], r);
      setHoras(null);
      toast("success", `Tempo de acesso na catraca: ${r.janelaHoras} hora${r.janelaHoras === 1 ? "" : "s"}.`);
    },
    onError: (e) => toast("error", mensagemDeErro(e, "Não foi possível salvar o tempo de acesso.")),
  });
  const n = Number(valor);
  const valido = Number.isInteger(n) && n >= 1 && n <= 12;
  const mudou = atual.data != null && valido && n !== atual.data.janelaHoras;

  return (
    <Card className="mb-6 p-4">
      <div className="flex flex-wrap items-end gap-4">
        <div className="flex min-w-0 flex-1 items-start gap-3">
          <DoorOpen className="mt-0.5 h-5 w-5 shrink-0 text-brand" />
          <div className="min-w-0">
            <p className="font-semibold text-content">Tempo de acesso na catraca (civis)</p>
            <p className="text-sm text-content-soft">
              A catraca libera 20 minutos antes do horário agendado e fica liberada por este tempo a partir do
              horário marcado. Vale para os próximos agendamentos. Militares, VIPs e instrutores têm acesso sempre.
            </p>
          </div>
        </div>
        <div className="flex items-end gap-2">
          <div>
            <Label htmlFor="janela-catraca">Horas</Label>
            <Input id="janela-catraca" type="number" min={1} max={12} className="w-24" value={valor}
              disabled={atual.isLoading} onChange={(e) => setHoras(e.target.value)} />
          </div>
          <Button loading={salvar.isPending} disabled={!mudou} onClick={() => salvar.mutate(n)}>Salvar</Button>
        </div>
      </div>
      {valor !== "" && !valido && <p className="mt-2 text-sm text-danger">Informe de 1 a 12 horas.</p>}
    </Card>
  );
}

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
  const [excluir, setExcluir] = useState<any>(null);

  // O backend recusa (409) se o horário ainda tiver agendamento ativo de hoje
  // em diante — a mensagem dele explica o que fazer.
  const remover = useMutation({
    mutationFn: (s: any) => api(`/slot-configs/${s.id}`, { method: "DELETE" }),
    onSuccess: (_d, s) => {
      qc.invalidateQueries({ queryKey: ["slots"] });
      setExcluir(null);
      toast("success", `Horário ${s.slotStart}–${s.slotEnd} excluído.`);
    },
    onError: (e) => {
      setExcluir(null);
      toast("error", mensagemDeErro(e, "Não foi possível excluir o horário."));
    },
  });

  function openNew() { setEdit(null); setErr(null); setForm(empty); setOpen(true); }
  function openEdit(s: any) { setEdit(s); setErr(null); setForm({ ...s, blockReason: s.blockReason || "" }); setOpen(true); }

  return (
    <div>
      <PageHeader
        title="Configuração de Horários"
        subtitle={data ? `${data.length} janela${data.length === 1 ? "" : "s"} configurada${data.length === 1 ? "" : "s"}` : "Janelas de agendamento, capacidade e restrições"}
        actions={<Button onClick={openNew}><Plus className="h-4 w-4" /> Novo horário</Button>}
      />
      <JanelaCatraca />
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
                    <div className="flex justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Editar horário ${s.slotStart}–${s.slotEnd}`}
                        onClick={() => openEdit(s)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Excluir horário ${s.slotStart}–${s.slotEnd}`}
                        onClick={() => setExcluir(s)}
                      >
                        <Trash2 className="h-4 w-4 text-danger" />
                      </Button>
                    </div>
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

      <ConfirmDialog
        open={!!excluir}
        onClose={() => setExcluir(null)}
        onConfirm={() => excluir && remover.mutate(excluir)}
        loading={remover.isPending}
        title={`Excluir o horário ${excluir?.slotStart ?? ""}–${excluir?.slotEnd ?? ""}?`}
        message="O horário deixa de aparecer para agendamento. Agendamentos que já aconteceram continuam no histórico e nos relatórios. Se ainda houver agendamentos ativos nele, a exclusão é recusada."
      />

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
