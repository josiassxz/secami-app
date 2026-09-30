import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Avatar, Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { Plus, Pencil, Trash2 } from "lucide-react";

export default function Departments() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [edit, setEdit] = useState<any>(null);
  const [form, setForm] = useState({ name: "", sigla: "", andar: "" });
  const [confirmTarget, setConfirmTarget] = useState<any>(null);

  const { data, isLoading } = useQuery({ queryKey: ["departments"], queryFn: () => api(`/departments`) });

  const save = useMutation({
    mutationFn: (body: any) =>
      edit
        ? api(`/departments/${edit.id}`, { method: "PUT", body: JSON.stringify(body) })
        : api(`/departments`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["departments"] }); setOpen(false); },
  });
  const del = useMutation({
    mutationFn: (id: string) => api(`/departments/${id}`, { method: "DELETE" }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["departments"] }); setConfirmTarget(null); },
  });

  function openNew() { setEdit(null); setForm({ name: "", sigla: "", andar: "" }); setOpen(true); }
  function openEdit(d: any) { setEdit(d); setForm({ name: d.name, sigla: d.sigla || "", andar: d.andar || "" }); setOpen(true); }

  return (
    <div>
      <PageHeader title="Secretarias" subtitle="Órgãos da Governadoria"
        actions={<Button onClick={openNew}><Plus className="h-4 w-4" /> Nova secretaria</Button>} />
      <Card className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={6} />
        ) : (
          <Table>
            <THead><TR><TH>Nome</TH><TH>Sigla</TH><TH>Andar</TH><TH></TH></TR></THead>
            <TBody>
              {(data || []).map((d: any) => (
                <TR key={d.id}>
                  <TD>
                    <div className="flex items-center gap-3">
                      <Avatar name={d.name} />
                      <span className="font-medium">{d.name}</span>
                    </div>
                  </TD>
                  <TD>{d.sigla ? <Badge tone="neutral">{d.sigla}</Badge> : <span className="text-content-faint">—</span>}</TD>
                  <TD className="text-content-soft">{d.andar || "—"}</TD>
                  <TD className="text-right">
                    <div className="flex justify-end gap-1">
                      <Button variant="ghost" size="sm" aria-label={`Editar ${d.name}`} onClick={() => openEdit(d)}>
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" aria-label={`Excluir ${d.name}`} onClick={() => setConfirmTarget(d)}>
                        <Trash2 className="h-4 w-4 text-danger" />
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))}
              {(data || []).length === 0 && (
                <TR><TD colSpan={4} className="py-10 text-center text-content-soft">Nenhuma secretaria cadastrada.</TD></TR>
              )}
            </TBody>
          </Table>
        )}
      </Card>
      <Modal open={open} onClose={() => setOpen(false)} title={edit ? "Editar secretaria" : "Nova secretaria"}
        footer={<>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>Salvar</Button>
        </>}>
        <div className="space-y-3">
          <div><Label>Nome</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
          <div className="grid grid-cols-2 gap-3">
            <div><Label>Sigla</Label><Input value={form.sigla} onChange={(e) => setForm({ ...form, sigla: e.target.value })} /></div>
            <div><Label>Andar</Label><Input value={form.andar} onChange={(e) => setForm({ ...form, andar: e.target.value })} /></div>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!confirmTarget}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => del.mutate(confirmTarget.id)}
        loading={del.isPending}
        title="Excluir secretaria"
        message={<>Tem certeza que deseja excluir <strong>{confirmTarget?.name}</strong>? Essa ação não pode ser desfeita.</>}
      />
    </div>
  );
}
