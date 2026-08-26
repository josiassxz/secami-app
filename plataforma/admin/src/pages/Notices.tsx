import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Badge, Button, Card, Input, Label, Select, Skeleton, Textarea } from "@/components/ui";
import { Plus, Trash2 } from "lucide-react";

const ROLES = ["aluno", "professor", "recepcao", "gerente", "admin"];
const empty = { title: "", content: "", type: "info", targetRoles: ["aluno"], active: true };

export default function Notices() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<any>(empty);

  const { data, isLoading } = useQuery({ queryKey: ["notices-all"], queryFn: () => api(`/notices`) });
  const save = useMutation({
    mutationFn: (body: any) => api(`/notices`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["notices-all"] }); setOpen(false); setForm(empty); },
  });
  const del = useMutation({
    mutationFn: (id: string) => api(`/notices/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["notices-all"] }),
  });

  function toggleRole(r: string) {
    setForm((f: any) => ({
      ...f,
      targetRoles: f.targetRoles.includes(r) ? f.targetRoles.filter((x: string) => x !== r) : [...f.targetRoles, r],
    }));
  }

  return (
    <div>
      <PageHeader title="Avisos" subtitle="Informativos por papel"
        actions={<Button onClick={() => { setForm(empty); setOpen(true); }}><Plus className="h-4 w-4" /> Novo aviso</Button>} />
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Card key={i} className="p-4">
              <Skeleton className="mb-2 h-5 w-1/3" />
              <Skeleton className="mb-1.5 h-4 w-full" />
              <Skeleton className="h-4 w-2/3" />
            </Card>
          ))}
        </div>
      ) : (
        <div className="space-y-3">
          {(data || []).map((n: any) => (
            <Card key={n.id} className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="mb-1 flex flex-wrap items-center gap-2">
                    <Badge tone={n.type}>{n.type}</Badge>
                    {!n.active && <Badge tone="cancelado">inativo</Badge>}
                    <span className="font-semibold text-content">{n.title}</span>
                  </div>
                  <p className="whitespace-pre-line text-sm leading-relaxed text-content-soft">{n.content}</p>
                  <p className="mt-2 text-xs text-content-faint">Para: {(n.targetRoles || []).join(", ")}</p>
                </div>
                <Button variant="ghost" size="sm" aria-label={`Excluir aviso ${n.title}`} onClick={() => del.mutate(n.id)}>
                  <Trash2 className="h-4 w-4 text-danger" />
                </Button>
              </div>
            </Card>
          ))}
          {(data || []).length === 0 && <p className="py-10 text-center text-content-soft">Nenhum aviso.</p>}
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title="Novo aviso"
        footer={<>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>Publicar</Button>
        </>}>
        <div className="space-y-3">
          <div><Label>Título</Label><Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></div>
          <div><Label>Conteúdo</Label><Textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} /></div>
          <div>
            <Label>Tipo</Label>
            <Select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
              <option value="info">Informação</option>
              <option value="warning">Alerta</option>
              <option value="success">Sucesso</option>
            </Select>
          </div>
          <div>
            <Label>Destinatários</Label>
            <div className="flex flex-wrap gap-2">
              {ROLES.map((r) => (
                <button
                  key={r}
                  type="button"
                  aria-pressed={form.targetRoles.includes(r)}
                  onClick={() => toggleRole(r)}
                  className={cn(
                    "rounded-full px-3 py-1.5 text-xs font-semibold capitalize transition-all duration-fast ease-standard active:scale-[.97] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/50 focus-visible:ring-offset-2 focus-visible:ring-offset-surface",
                    form.targetRoles.includes(r)
                      ? "bg-brand text-brand-fg shadow-1 hover:bg-brand-hover"
                      : "bg-surface-alt text-content-soft hover:bg-line/50 hover:text-content"
                  )}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>
        </div>
      </Modal>
    </div>
  );
}
