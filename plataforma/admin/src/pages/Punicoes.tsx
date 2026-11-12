import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { mensagemDeErro } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { cn, formatDateTime } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import {
  Avatar, Badge, Button, Card, Input, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR, Textarea,
} from "@/components/ui";
import { AlertCircle, CheckCircle2, Gavel, History, Pencil, Plus, Search, Trash2, UserX } from "lucide-react";

export type ItemPunicao = { id: string; nome: string; ativo: boolean };
export type StatusPunicao = "PENDENTE" | "CUMPRIDA" | "CONCLUIDA";
export type Punicao = {
  id: string;
  studentId: string;
  studentName: string;
  itens: { itemId: string; nome: string }[];
  observacao: string | null;
  status: StatusPunicao;
  aplicadaEm: string;
  aplicadaPorNome: string | null;
  cumpridaEm: string | null;
  cumpridaPorNome: string | null;
  concluidaEm: string | null;
};
export type AlunoLutas = {
  studentId: string;
  fullName: string;
  turmaLutas: "MASCULINO" | "FEMININO" | null;
  pendentes: number;
  cumpridas: number;
};
export type ConfigPunicoes = { porCiclo: number; diasParaConcluir: number };

type Aba = "alunos" | "catalogo";
const ABAS: Aba[] = ["alunos", "catalogo"];
const ROTULOS_ABA: Record<Aba, string> = { alunos: "Alunos", catalogo: "Catálogo" };

const SEARCH_DEBOUNCE_MS = 300;

const STATUS: Record<StatusPunicao, { texto: string; tom: string }> = {
  PENDENTE: { texto: "pendente", tom: "warning" },
  CUMPRIDA: { texto: "cumprida", tom: "success" },
  CONCLUIDA: { texto: "concluída", tom: "neutral" },
};

function plural(n: number, um: string, varios: string) {
  return `${n} ${n === 1 ? um : varios}`;
}

/** "10 flexões + 1 Coca-Cola". */
export function descricaoItens(p: Punicao) {
  return p.itens.map((i) => i.nome).join(" + ");
}

/** Chaves de cache que mudam quando uma punição é aplicada/cumprida/excluída. */
function useAtualizarPunicoes() {
  const qc = useQueryClient();
  return (studentId: string) => {
    qc.invalidateQueries({ queryKey: ["punicoes-alunos"] });
    qc.invalidateQueries({ queryKey: ["punicoes-abertas", studentId] });
    qc.invalidateQueries({ queryKey: ["punicoes-historico", studentId] });
  };
}

/**
 * Punições dos alunos de Lutas: o instrutor de lutas aplica uma ou mais
 * punições do catálogo, marca quando o aluno cumpre e, a cada ciclo de
 * cumpridas, o backend encerra as mais antigas. Admin gerencia tudo.
 */
export default function Punicoes() {
  const { hasRole } = useAuth();
  const veConfig = hasRole("admin", "gerente");
  const [params, setParams] = useSearchParams();
  const pedida = params.get("aba") as Aba | null;
  const aba: Aba = pedida && ABAS.includes(pedida) ? pedida : "alunos";

  const config = useQuery({
    queryKey: ["config-punicoes"],
    queryFn: () => api<ConfigPunicoes>(`/admin/configuracoes/punicoes`),
    enabled: veConfig,
  });
  const c = config.data;
  const regra =
    c && typeof c.porCiclo === "number"
      ? `A cada ${plural(c.porCiclo, "punição cumprida", "punições cumpridas")}, elas são encerradas. ` +
        `Uma cumprida que não fecha ciclo se encerra sozinha após ${plural(c.diasParaConcluir, "dia", "dias")}.`
      : "A cada ciclo de punições cumpridas elas são encerradas.";

  return (
    <div>
      <PageHeader title="Punições" subtitle={`Alunos de Lutas · ${regra}`} />

      <div role="tablist" className="mb-4 flex flex-wrap gap-2">
        {ABAS.map((a) => (
          <button
            key={a}
            role="tab"
            aria-selected={aba === a}
            onClick={() => setParams({ aba: a })}
            className={cn(
              "rounded-full px-3.5 py-1.5 text-sm font-semibold transition-colors",
              aba === a ? "bg-brand text-brand-fg shadow-1" : "bg-surface-alt text-content-soft hover:text-content"
            )}
          >
            {ROTULOS_ABA[a]}
          </button>
        ))}
      </div>

      {aba === "alunos" ? <AbaAlunos /> : <AbaCatalogo />}
    </div>
  );
}

// ======================= Alunos =======================

function AbaAlunos() {
  const [q, setQ] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [selecionado, setSelecionado] = useState<AlunoLutas | null>(null);

  useEffect(() => {
    const id = setTimeout(() => setDebouncedQ(q), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(id);
  }, [q]);

  const alunos = useQuery({
    queryKey: ["punicoes-alunos", debouncedQ],
    queryFn: () => api<AlunoLutas[]>(`/punicoes/alunos?q=${encodeURIComponent(debouncedQ)}`),
  });
  const lista = alunos.data ?? [];

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)]">
      <Card className="self-start overflow-hidden">
        <div className="border-b border-line p-4">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input className="pl-9" placeholder="Buscar aluno de Lutas" aria-label="Buscar aluno de Lutas"
              value={q} onChange={(e) => setQ(e.target.value)} />
          </div>
        </div>
        {alunos.isLoading ? (
          <TableSkeleton rows={5} />
        ) : lista.length === 0 ? (
          <div className="flex flex-col items-center gap-2 px-4 py-12 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
              <UserX className="h-6 w-6" />
            </div>
            <p className="text-sm text-content-soft">
              {debouncedQ ? `Nenhum aluno de Lutas encontrado para "${debouncedQ}".` : "Nenhum aluno de Lutas cadastrado."}
            </p>
          </div>
        ) : (
          <ul className="max-h-[65vh] divide-y divide-line overflow-y-auto">
            {lista.map((a) => (
              <li key={a.studentId}>
                <button
                  type="button"
                  aria-pressed={selecionado?.studentId === a.studentId}
                  onClick={() => setSelecionado(a)}
                  className={cn(
                    "flex w-full items-center gap-3 px-4 py-3 text-left transition-colors",
                    selecionado?.studentId === a.studentId ? "bg-brand-container" : "hover:bg-surface-alt/60"
                  )}
                >
                  <Avatar name={a.fullName} />
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="truncate font-medium text-content">{a.fullName}</span>
                      {a.turmaLutas && (
                        <Badge tone="lutas">{a.turmaLutas === "FEMININO" ? "Feminino" : "Masculino"}</Badge>
                      )}
                    </div>
                    <div className="text-xs text-content-soft">
                      {plural(a.pendentes, "pendente", "pendentes")} · {plural(a.cumpridas, "cumprida", "cumpridas")}
                    </div>
                  </div>
                </button>
              </li>
            ))}
          </ul>
        )}
      </Card>

      {selecionado ? (
        <DetalheAluno key={selecionado.studentId} aluno={selecionado} />
      ) : (
        <Card className="flex flex-col items-center justify-center gap-2 self-start px-4 py-16 text-center">
          <Gavel className="h-8 w-8 text-content-faint" />
          <p className="text-sm text-content-soft">Escolha um aluno para ver e aplicar punições.</p>
        </Card>
      )}
    </div>
  );
}

function DetalheAluno({ aluno }: { aluno: AlunoLutas }) {
  const qc = useQueryClient();
  const atualizar = useAtualizarPunicoes();
  const id = aluno.studentId;
  const [aplicar, setAplicar] = useState(false);
  const [verHistorico, setVerHistorico] = useState(false);
  const [excluir, setExcluir] = useState<Punicao | null>(null);

  const abertas = useQuery({
    queryKey: ["punicoes-abertas", id],
    queryFn: () => api<Punicao[]>(`/punicoes/alunos/${id}`),
  });
  const historico = useQuery({
    queryKey: ["punicoes-historico", id],
    queryFn: () => api<Punicao[]>(`/punicoes/alunos/${id}/historico`),
    enabled: verHistorico,
  });

  const cumprir = useMutation({
    mutationFn: (p: Punicao) => api<Punicao[]>(`/punicoes/${p.id}/cumprir`, { method: "POST" }),
    onSuccess: (lista, p) => {
      const antes = qc.getQueryData<Punicao[]>(["punicoes-abertas", id]) ?? [];
      const novas = Array.isArray(lista) ? lista : [];
      const encerradas = antes.filter((x) => !novas.some((y) => y.id === x.id)).length;
      qc.setQueryData(["punicoes-abertas", id], novas);
      qc.invalidateQueries({ queryKey: ["punicoes-alunos"] });
      qc.invalidateQueries({ queryKey: ["punicoes-historico", id] });
      if (encerradas > 0) {
        toast("success", `Ciclo concluído: ${plural(encerradas, "punição encerrada", "punições encerradas")}.`);
      } else {
        toast("success", `Punição "${descricaoItens(p)}" marcada como cumprida.`);
      }
    },
    onError: (e) => toast("error", mensagemDeErro(e, "Não foi possível marcar a punição como cumprida.")),
  });

  const remover = useMutation({
    mutationFn: (p: Punicao) => api(`/punicoes/${p.id}`, { method: "DELETE" }),
    onSuccess: (_d, p) => {
      setExcluir(null);
      atualizar(id);
      toast("success", `Punição "${descricaoItens(p)}" excluída.`);
    },
    onError: (e) => {
      setExcluir(null);
      toast("error", mensagemDeErro(e, "Não foi possível excluir a punição."));
    },
  });

  const lista = abertas.data ?? [];

  return (
    <Card className="self-start overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line p-4">
        <div className="flex min-w-0 items-center gap-3">
          <Avatar name={aluno.fullName} />
          <div className="min-w-0">
            <div className="truncate font-semibold text-content">{aluno.fullName}</div>
            <div className="text-xs text-content-soft">Punições em aberto</div>
          </div>
        </div>
        <Button onClick={() => setAplicar(true)}><Plus className="h-4 w-4" /> Aplicar punição</Button>
      </div>

      {abertas.isLoading ? (
        <TableSkeleton rows={3} />
      ) : lista.length === 0 ? (
        <p className="px-4 py-10 text-center text-sm text-content-soft">Nenhuma punição em aberto.</p>
      ) : (
        <ul className="divide-y divide-line">
          {lista.map((p) => (
            <li key={p.id} className="flex flex-wrap items-start justify-between gap-3 p-4">
              <LinhaPunicao p={p} />
              {p.status === "PENDENTE" && (
                <div className="flex shrink-0 items-center gap-1">
                  <Button size="sm" variant="outline" loading={cumprir.isPending && cumprir.variables?.id === p.id}
                    onClick={() => cumprir.mutate(p)}>
                    <CheckCircle2 className="h-4 w-4" /> Marcar como cumprida
                  </Button>
                  <Button size="sm" variant="ghost" aria-label={`Excluir punição ${descricaoItens(p)}`} title="Excluir (aplicada por engano)"
                    onClick={() => setExcluir(p)}>
                    <Trash2 className="h-4 w-4 text-danger" />
                  </Button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <div className="border-t border-line p-4">
        <Button variant="ghost" size="sm" onClick={() => setVerHistorico((v) => !v)} aria-expanded={verHistorico}>
          <History className="h-4 w-4" /> {verHistorico ? "Esconder histórico" : "Ver histórico"}
        </Button>
        {verHistorico && (
          <div className="mt-3">
            {historico.isLoading ? (
              <TableSkeleton rows={3} />
            ) : (historico.data ?? []).length === 0 ? (
              <p className="py-4 text-center text-sm text-content-soft">Nenhuma punição no histórico.</p>
            ) : (
              <ul aria-label="Histórico de punições" className="divide-y divide-line rounded-md border border-line">
                {(historico.data ?? []).map((p) => (
                  <li key={p.id} className="p-3"><LinhaPunicao p={p} /></li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>

      <AplicarPunicao open={aplicar} onClose={() => setAplicar(false)} aluno={aluno} />

      <ConfirmDialog
        open={!!excluir}
        onClose={() => setExcluir(null)}
        onConfirm={() => excluir && remover.mutate(excluir)}
        loading={remover.isPending}
        title="Excluir punição"
        message={<>Excluir a punição <strong>{excluir ? descricaoItens(excluir) : ""}</strong> de {aluno.fullName}? Use só se ela foi aplicada por engano.</>}
      />
    </Card>
  );
}

function LinhaPunicao({ p }: { p: Punicao }) {
  const st = STATUS[p.status] ?? STATUS.PENDENTE;
  return (
    <div className="min-w-0 flex-1">
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-medium text-content">{descricaoItens(p)}</span>
        <Badge tone={st.tom}>{st.texto}</Badge>
      </div>
      {p.observacao && <p className="mt-0.5 text-sm text-content-soft">{p.observacao}</p>}
      <div className="mt-1 space-y-0.5 text-xs text-content-faint">
        <div>Aplicada em {formatDateTime(p.aplicadaEm)}{p.aplicadaPorNome ? ` por ${p.aplicadaPorNome}` : ""}</div>
        {p.cumpridaEm && (
          <div>Cumprida em {formatDateTime(p.cumpridaEm)}{p.cumpridaPorNome ? ` (${p.cumpridaPorNome})` : ""}</div>
        )}
        {p.concluidaEm && <div>Encerrada em {formatDateTime(p.concluidaEm)}</div>}
      </div>
    </div>
  );
}

function AplicarPunicao({ open, onClose, aluno }: { open: boolean; onClose: () => void; aluno: AlunoLutas }) {
  const atualizar = useAtualizarPunicoes();
  const [marcados, setMarcados] = useState<string[]>([]);
  const [observacao, setObservacao] = useState("");
  const [erro, setErro] = useState<string | null>(null);

  const itens = useQuery({
    queryKey: ["punicoes-itens", "ativos"],
    queryFn: () => api<ItemPunicao[]>(`/punicoes/itens`),
    enabled: open,
  });
  const ativos = (itens.data ?? []).filter((i) => i.ativo !== false);

  useEffect(() => {
    if (open) { setMarcados([]); setObservacao(""); setErro(null); }
  }, [open]);

  const salvar = useMutation({
    mutationFn: (body: { studentId: string; itemIds: string[]; observacao?: string }) =>
      api<Punicao>(`/punicoes/aplicar`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      atualizar(aluno.studentId);
      onClose();
      toast("success", `Punição aplicada a ${aluno.fullName}.`);
    },
    onError: (e) => setErro(mensagemDeErro(e, "Não foi possível aplicar a punição.")),
  });

  function alternar(itemId: string) {
    setMarcados((m) => (m.includes(itemId) ? m.filter((x) => x !== itemId) : [...m, itemId]));
  }

  function confirmar() {
    if (marcados.length === 0) { setErro("Escolha pelo menos uma punição."); return; }
    setErro(null);
    // Mantém a ordem do catálogo (é a ordem em que os itens aparecem juntos: "A + B").
    const itemIds = ativos.map((i) => i.id).filter((x) => marcados.includes(x));
    const obs = observacao.trim();
    salvar.mutate({ studentId: aluno.studentId, itemIds, ...(obs ? { observacao: obs } : {}) });
  }

  return (
    <Modal open={open} onClose={onClose} title={`Aplicar punição — ${aluno.fullName}`}
      footer={<>
        <Button variant="outline" onClick={onClose}>Cancelar</Button>
        <Button loading={salvar.isPending} onClick={confirmar}>Aplicar</Button>
      </>}>
      <div className="space-y-4">
        {erro && (
          <div className="flex items-start gap-2 rounded bg-danger/10 px-3 py-2 text-sm text-danger">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" /><span>{erro}</span>
          </div>
        )}
        <div>
          <p className="mb-2 text-sm font-medium text-content-soft">Punições (marque uma ou mais)</p>
          {itens.isLoading ? (
            <TableSkeleton rows={3} />
          ) : ativos.length === 0 ? (
            <p className="text-sm text-content-soft">Nenhuma punição ativa no catálogo. Cadastre na aba Catálogo.</p>
          ) : (
            <div className="space-y-1.5">
              {ativos.map((i) => (
                <label key={i.id} className="flex cursor-pointer items-center gap-2.5 rounded-md border border-line px-3 py-2 text-sm text-content hover:bg-surface-alt/60">
                  <input type="checkbox" className="h-4 w-4 cursor-pointer rounded border-line-input accent-brand" checked={marcados.includes(i.id)} onChange={() => alternar(i.id)} />
                  {i.nome}
                </label>
              ))}
            </div>
          )}
        </div>
        <div>
          <Label htmlFor="punicao-obs">Observação (opcional)</Label>
          <Textarea id="punicao-obs" value={observacao} maxLength={500} onChange={(e) => setObservacao(e.target.value)} />
        </div>
      </div>
    </Modal>
  );
}

// ======================= Catálogo =======================

function AbaCatalogo() {
  const qc = useQueryClient();
  const [form, setForm] = useState<{ item: ItemPunicao | null; nome: string } | null>(null);
  const [erro, setErro] = useState<string | null>(null);

  const itens = useQuery({
    queryKey: ["punicoes-itens", "todos"],
    queryFn: () => api<ItemPunicao[]>(`/punicoes/itens?todos=true`),
  });

  const salvar = useMutation({
    mutationFn: ({ item, nome, ativo }: { item: ItemPunicao | null; nome: string; ativo: boolean }) =>
      item
        ? api<ItemPunicao>(`/punicoes/itens/${item.id}`, { method: "PUT", body: JSON.stringify({ nome, ativo }) })
        : api<ItemPunicao>(`/punicoes/itens`, { method: "POST", body: JSON.stringify({ nome }) }),
    onSuccess: (_r, v) => {
      qc.invalidateQueries({ queryKey: ["punicoes-itens"] });
      if (form) setForm(null);
      if (!v.item) toast("success", `Punição "${v.nome}" criada.`);
      else if (v.ativo !== v.item.ativo) toast("success", `Punição "${v.nome}" ${v.ativo ? "ativada" : "desativada"}.`);
      else toast("success", "Punição salva.");
    },
    onError: (e, v) => {
      const msg = mensagemDeErro(e, "Não foi possível salvar a punição.");
      if (form && v.item?.id === form.item?.id) setErro(msg);
      else toast("error", msg);
    },
  });

  function abrir(item: ItemPunicao | null) {
    setErro(null);
    setForm({ item, nome: item?.nome ?? "" });
  }

  function confirmar() {
    if (!form) return;
    const nome = form.nome.trim();
    if (!nome) { setErro("Informe o nome da punição."); return; }
    setErro(null);
    salvar.mutate({ item: form.item, nome, ativo: form.item?.ativo ?? true });
  }

  const lista = itens.data ?? [];

  return (
    <>
      <div className="mb-3 flex items-center justify-between gap-3">
        <p className="text-sm text-content-soft">Catálogo compartilhado por todos os instrutores de lutas. Itens desativados não aparecem para aplicar.</p>
        <Button onClick={() => abrir(null)}><Plus className="h-4 w-4" /> Novo item</Button>
      </div>
      <Card className="overflow-hidden">
        {itens.isLoading ? (
          <TableSkeleton rows={4} />
        ) : lista.length === 0 ? (
          <p className="px-4 py-12 text-center text-sm text-content-soft">Nenhuma punição cadastrada. Crie a primeira em "Novo item".</p>
        ) : (
          <Table>
            <THead><TR><TH>Punição</TH><TH>Situação</TH><TH></TH></TR></THead>
            <TBody>
              {lista.map((i) => (
                <TR key={i.id}>
                  <TD className={cn("font-medium", !i.ativo && "text-content-soft")}>{i.nome}</TD>
                  <TD><Badge tone={i.ativo ? "success" : "neutral"}>{i.ativo ? "ativa" : "inativa"}</Badge></TD>
                  <TD className="text-right">
                    <div className="flex justify-end gap-1">
                      <Button variant="ghost" size="sm" aria-label={`Editar ${i.nome}`} onClick={() => abrir(i)}>
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button variant="outline" size="sm" aria-label={`${i.ativo ? "Desativar" : "Ativar"} ${i.nome}`}
                        loading={salvar.isPending && salvar.variables?.item?.id === i.id && !form}
                        onClick={() => salvar.mutate({ item: i, nome: i.nome, ativo: !i.ativo })}>
                        {i.ativo ? "Desativar" : "Ativar"}
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      <Modal open={!!form} onClose={() => setForm(null)} title={form?.item ? "Editar punição" : "Nova punição"}
        footer={<>
          <Button variant="outline" onClick={() => setForm(null)}>Cancelar</Button>
          <Button loading={salvar.isPending} onClick={confirmar}>Salvar</Button>
        </>}>
        <div className="space-y-4">
          {erro && (
            <div className="flex items-start gap-2 rounded bg-danger/10 px-3 py-2 text-sm text-danger">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" /><span>{erro}</span>
            </div>
          )}
          <div>
            <Label htmlFor="item-nome">Nome</Label>
            <Input id="item-nome" placeholder="Ex.: 10 flexões" maxLength={120} value={form?.nome ?? ""}
              onChange={(e) => form && setForm({ ...form, nome: e.target.value })}
              onKeyDown={(e) => { if (e.key === "Enter") confirmar(); }} />
          </div>
        </div>
      </Modal>
    </>
  );
}
