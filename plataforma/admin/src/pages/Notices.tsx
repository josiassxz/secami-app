import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import { cn, formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Badge, Button, Card, Input, Label, Select, Skeleton, Textarea } from "@/components/ui";
import { CalendarRange, Pencil, Plus, Trash2 } from "lucide-react";
import { rotuloPapel } from "@/lib/papeis";
import { situacaoDoAviso, type Aviso } from "@/lib/avisos";

const ROLES = ["aluno", "professor", "recepcao", "gerente", "admin"];
const TIPOS: Record<string, string> = { info: "Informação", warning: "Alerta", success: "Sucesso" };


type Form = {
  title: string;
  content: string;
  type: string;
  targetRoles: string[];
  active: boolean;
  exibirDe: string;
  exibirAte: string;
};

const vazio: Form = { title: "", content: "", type: "info", targetRoles: ["aluno"], active: true, exibirDe: "", exibirAte: "" };

function textoDoPeriodo(n: Aviso): string {
  if (n.exibirDe && n.exibirAte) return `de ${formatDate(n.exibirDe)} a ${formatDate(n.exibirAte)}`;
  if (n.exibirDe) return `a partir de ${formatDate(n.exibirDe)}`;
  if (n.exibirAte) return `até ${formatDate(n.exibirAte)}`;
  return "sem período definido (enquanto estiver ativo)";
}

export default function Notices() {
  const qc = useQueryClient();
  const [editando, setEditando] = useState<Aviso | null>(null);
  const [aberto, setAberto] = useState(false);
  const [form, setForm] = useState<Form>(vazio);
  const [erro, setErro] = useState<string | null>(null);
  const [confirmTarget, setConfirmTarget] = useState<Aviso | null>(null);

  const { data, isLoading } = useQuery({ queryKey: ["notices-all"], queryFn: () => api<Aviso[]>(`/notices`) });
  const save = useMutation({
    mutationFn: (body: object) =>
      editando
        ? api(`/notices/${editando.id}`, { method: "PUT", body: JSON.stringify(body) })
        : api(`/notices`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["notices-all"] });
      fechar();
    },
    onError: (e) => setErro(mensagemDeErro(e, "Não foi possível salvar o aviso.")),
  });
  const del = useMutation({
    mutationFn: (id: string) => api(`/notices/${id}`, { method: "DELETE" }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["notices-all"] }); setConfirmTarget(null); },
  });

  function abrirNovo() {
    setEditando(null);
    setForm(vazio);
    setErro(null);
    setAberto(true);
  }

  function abrirEdicao(n: Aviso) {
    setEditando(n);
    setForm({
      title: n.title,
      content: n.content,
      type: n.type,
      targetRoles: [...(n.targetRoles ?? [])],
      active: n.active,
      exibirDe: n.exibirDe ?? "",
      exibirAte: n.exibirAte ?? "",
    });
    setErro(null);
    setAberto(true);
  }

  function fechar() {
    if (save.isPending) return;
    setAberto(false);
    setEditando(null);
  }

  function toggleRole(r: string) {
    setForm((f) => ({
      ...f,
      targetRoles: f.targetRoles.includes(r) ? f.targetRoles.filter((x) => x !== r) : [...f.targetRoles, r],
    }));
  }

  function publicar() {
    if (!form.title.trim() || !form.content.trim()) {
      setErro("Informe o título e o conteúdo do aviso.");
      return;
    }
    if (form.exibirDe && form.exibirAte && form.exibirAte < form.exibirDe) {
      setErro("A data final da exibição deve ser igual ou posterior à data inicial.");
      return;
    }
    setErro(null);
    save.mutate({
      title: form.title.trim(),
      content: form.content.trim(),
      type: form.type,
      active: form.active,
      targetRoles: form.targetRoles,
      exibirDe: form.exibirDe || null,
      exibirAte: form.exibirAte || null,
    });
  }

  return (
    <div>
      <PageHeader title="Avisos" subtitle="Aparecem como janela ao entrar no aplicativo, no período definido"
        actions={<Button onClick={abrirNovo}><Plus className="h-4 w-4" /> Novo aviso</Button>} />
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
          {(data || []).map((n) => {
            const situacao = situacaoDoAviso(n);
            return (
              <Card key={n.id} className="p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="mb-1 flex flex-wrap items-center gap-2">
                      <Badge tone={n.type}>{TIPOS[n.type] ?? n.type}</Badge>
                      <Badge tone={situacao.tom}>{situacao.rotulo}</Badge>
                      <span className="font-semibold text-content">{n.title}</span>
                    </div>
                    <p className="whitespace-pre-line text-sm leading-relaxed text-content-soft">{n.content}</p>
                    <p className="mt-2 flex items-center gap-1.5 text-xs text-content-faint">
                      <CalendarRange className="h-3.5 w-3.5" /> Exibição {textoDoPeriodo(n)}
                    </p>
                    <p className="mt-1 text-xs text-content-faint">
                      Para: {(n.targetRoles || []).length ? (n.targetRoles || []).map(rotuloPapel).join(", ") : "todos os perfis"}
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center">
                    <Button variant="ghost" size="sm" aria-label={`Editar aviso ${n.title}`} onClick={() => abrirEdicao(n)}>
                      <Pencil className="h-4 w-4" />
                    </Button>
                    <Button variant="ghost" size="sm" aria-label={`Excluir aviso ${n.title}`} onClick={() => setConfirmTarget(n)}>
                      <Trash2 className="h-4 w-4 text-danger" />
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
          {(data || []).length === 0 && <p className="py-10 text-center text-content-soft">Nenhum aviso.</p>}
        </div>
      )}

      <Modal open={aberto} onClose={fechar} title={editando ? "Editar aviso" : "Novo aviso"}
        footer={<>
          {erro && <span className="mr-auto self-center text-sm text-danger">{erro}</span>}
          <Button variant="outline" onClick={fechar} disabled={save.isPending}>Cancelar</Button>
          <Button loading={save.isPending} onClick={publicar}>{editando ? "Salvar" : "Publicar"}</Button>
        </>}>
        <div className="space-y-3">
          <div><Label htmlFor="aviso-titulo">Título</Label><Input id="aviso-titulo" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></div>
          <div><Label htmlFor="aviso-conteudo">Conteúdo</Label><Textarea id="aviso-conteudo" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} /></div>
          <div>
            <Label htmlFor="aviso-tipo">Tipo</Label>
            <Select id="aviso-tipo" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
              <option value="info">Informação</option>
              <option value="warning">Alerta</option>
              <option value="success">Sucesso</option>
            </Select>
          </div>
          <div>
            <Label>Período de exibição</Label>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <span className="mb-0.5 block text-[11px] font-medium text-content-soft">De</span>
                <Input aria-label="Exibir de" type="date" value={form.exibirDe} onChange={(e) => setForm({ ...form, exibirDe: e.target.value })} />
              </div>
              <div>
                <span className="mb-0.5 block text-[11px] font-medium text-content-soft">Até</span>
                <Input aria-label="Exibir até" type="date" value={form.exibirAte} onChange={(e) => setForm({ ...form, exibirAte: e.target.value })} />
              </div>
            </div>
            <p className="mt-1 text-xs text-content-soft">
              Datas incluídas. Em branco = sem limite. No período, o aviso abre como janela sempre que o usuário
              entra no aplicativo, até ele marcar "Não mostrar novamente".
            </p>
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
                  {rotuloPapel(r)}
                </button>
              ))}
            </div>
            {form.targetRoles.length === 0 && (
              <p className="mt-1 text-xs text-content-soft">Nenhum selecionado = todos os perfis.</p>
            )}
          </div>
          <label className="flex items-center gap-2 text-sm text-content">
            <input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />
            Aviso ativo
          </label>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!confirmTarget}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => confirmTarget && del.mutate(confirmTarget.id)}
        loading={del.isPending}
        title="Excluir aviso"
        message={<>Tem certeza que deseja excluir o aviso <strong>{confirmTarget?.title}</strong>? Essa ação não pode ser desfeita.</>}
      />
    </div>
  );
}
