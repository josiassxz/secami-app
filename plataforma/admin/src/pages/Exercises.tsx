import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Badge, Button, Card, Input, Label, Select, Skeleton, Textarea } from "@/components/ui";
import { Dumbbell, Plus, Search, Video } from "lucide-react";

const GRUPOS = ["Peito", "Costas", "Ombros", "Bíceps", "Tríceps", "Abdômen", "Quadríceps", "Posterior", "Glúteos", "Panturrilha", "Cardio", "Funcional"];
const empty = { name: "", muscleGroup: "", equipment: "", description: "", videoUrl: "" };

export default function Exercises() {
  const qc = useQueryClient();
  const [q, setQ] = useState("");
  const [grupo, setGrupo] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<any>(empty);

  const { data, isLoading } = useQuery({
    queryKey: ["exercises", q, grupo],
    queryFn: () => api(`/exercises?q=${encodeURIComponent(q)}&grupo=${encodeURIComponent(grupo)}`),
  });
  const save = useMutation({
    mutationFn: (body: any) => api(`/exercises`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["exercises"] }); setOpen(false); setForm(empty); },
  });

  return (
    <div>
      <PageHeader title="Exercícios" subtitle={data ? `${data.length} no catálogo` : undefined}
        actions={<Button onClick={() => { setForm(empty); setOpen(true); }}><Plus className="h-4 w-4" /> Novo</Button>} />

      <div className="mb-5 flex flex-wrap items-center gap-3">
        <div className="relative w-full max-w-xs">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
          <Input className="pl-9" placeholder="Buscar exercício" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
        <Select className="w-full max-w-[200px]" value={grupo} onChange={(e) => setGrupo(e.target.value)}>
          <option value="">Todos os grupos</option>
          {GRUPOS.map((g) => <option key={g} value={g}>{g}</option>)}
        </Select>
      </div>

      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Card key={i} className="space-y-3 p-4">
              <div className="flex items-start justify-between gap-2">
                <Skeleton className="h-5 w-2/3" />
                <Skeleton className="h-5 w-16 rounded-full" />
              </div>
              <Skeleton className="h-3 w-1/3" />
              <Skeleton className="h-3 w-full" />
              <Skeleton className="h-3 w-4/5" />
            </Card>
          ))}
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {(data || []).map((e: any) => (
            <Card key={e.id} className="flex flex-col gap-2 p-4">
              <div className="flex items-start justify-between gap-2">
                <h3 className="font-semibold leading-snug text-content">{e.name}</h3>
                {e.muscleGroup && <Badge tone="info">{e.muscleGroup}</Badge>}
              </div>
              {(e.equipment || e.videoUrl) && (
                <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-content-soft">
                  {e.equipment && (
                    <span className="inline-flex items-center gap-1">
                      <Dumbbell className="h-3.5 w-3.5 shrink-0" /> {e.equipment}
                    </span>
                  )}
                  {e.videoUrl && (
                    <span className="inline-flex items-center gap-1 font-medium text-brand">
                      <Video className="h-3.5 w-3.5 shrink-0" /> Vídeo
                    </span>
                  )}
                </div>
              )}
              {e.description && (
                <p className="line-clamp-3 text-sm leading-relaxed text-content-soft">{e.description}</p>
              )}
            </Card>
          ))}
          {(data || []).length === 0 && (
            <div className="col-span-full flex flex-col items-center gap-2 py-14 text-center text-content-soft">
              <Dumbbell className="h-8 w-8 text-content-faint" />
              <p>Nenhum exercício encontrado.</p>
            </div>
          )}
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title="Novo exercício"
        footer={<>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>Salvar</Button>
        </>}>
        <div className="space-y-3">
          <div><Label>Nome</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Grupo muscular</Label>
              <Select value={form.muscleGroup} onChange={(e) => setForm({ ...form, muscleGroup: e.target.value })}>
                <option value="">—</option>
                {GRUPOS.map((g) => <option key={g} value={g}>{g}</option>)}
              </Select>
            </div>
            <div><Label>Equipamento</Label><Input value={form.equipment} onChange={(e) => setForm({ ...form, equipment: e.target.value })} /></div>
          </div>
          <div><Label>Descrição</Label><Textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
          <div><Label>Vídeo (URL)</Label><Input value={form.videoUrl} onChange={(e) => setForm({ ...form, videoUrl: e.target.value })} /></div>
        </div>
      </Modal>
    </div>
  );
}
