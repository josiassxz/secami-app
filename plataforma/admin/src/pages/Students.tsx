import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import { useAuth } from "@/lib/auth";
import { tomDoTipo } from "@/lib/papeis";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import {
  Avatar, Badge, Button, Card, Input, Label, Select,
  Table, TableSkeleton, TBody, TD, TH, THead, TR,
} from "@/components/ui";
import {
  AlertCircle, ChevronLeft, ChevronRight, Eye, Pencil,
  Plus, Search, Trash2, UserX,
} from "lucide-react";

type Student = {
  id: string; fullName: string; cpf: string; matricula?: string;
  studentType: string; departmentId?: string; departmentName?: string;
  phone?: string; email?: string; birthDate?: string;
  weightKg?: number; heightCm?: number; goal?: string;
  atestadoNumero?: string; atestadoData?: string;
  active: boolean; situacao: string;
  atestadoValido: boolean; diasParaVencimentoAtestado?: number | null;
};

const emptyForm = {
  fullName: "", cpf: "", matricula: "", studentType: "Civil",
  departmentId: "", phone: "", email: "", birthDate: "",
  weightKg: "", heightCm: "", goal: "",
  atestadoNumero: "", atestadoData: "", situacao: "ATIVO",
};

const PAGE_SIZE = 15;
const SEARCH_DEBOUNCE_MS = 300;

function validateStudentForm(f: typeof emptyForm): string | null {
  if (!f.fullName.trim()) return "Informe o nome completo.";
  if (!f.cpf.trim()) return "Informe o CPF.";
  return null;
}

function atestadoLabel(dias: number | null | undefined) {
  if (dias == null) return { text: "sem atestado", tone: "faltou" as const };
  if (dias <= 0) return { text: "vencido", tone: "faltou" as const };
  if (dias <= 30) return { text: `${dias} dias`, tone: "warning" as const };
  return { text: "válido", tone: "success" as const };
}

export default function Students() {
  const { hasRole } = useAuth();
  const qc = useQueryClient();
  const canEdit = hasRole("admin", "gerente");
  const isAdmin = hasRole("admin");

  const [q, setQ] = useState("");
  const [perfil, setPerfil] = useState(""); // "" = todos | "aluno" | "instrutor"
  const [debouncedQ, setDebouncedQ] = useState("");
  const [page, setPage] = useState(0);
  const [open, setOpen] = useState(false);
  const [edit, setEdit] = useState<Student | null>(null);
  const [form, setForm] = useState<typeof emptyForm>(emptyForm);
  const [err, setErr] = useState<string | null>(null);
  const [confirmTarget, setConfirmTarget] = useState<Student | null>(null);
  const [detailStudent, setDetailStudent] = useState<Student | null>(null);
  const [detailFrom, setDetailFrom] = useState("");
  const [detailTo, setDetailTo] = useState("");

  useEffect(() => {
    const id = setTimeout(() => setDebouncedQ(q), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(id);
  }, [q]);

  useEffect(() => {
    if (detailStudent) {
      const today = new Date().toISOString().slice(0, 10);
      const ago = new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10);
      setDetailFrom(ago);
      setDetailTo(today);
    }
  }, [detailStudent]);

  const { data, isLoading } = useQuery({
    queryKey: ["students", debouncedQ, perfil, page],
    queryFn: () =>
      api(`/students?q=${encodeURIComponent(debouncedQ)}&page=${page}&size=${PAGE_SIZE}${perfil ? `&perfil=${perfil}` : ""}`),
  });
  const departments = useQuery({ queryKey: ["departments"], queryFn: () => api(`/departments`) });
  const detailHistory = useQuery({
    queryKey: ["student-history", detailStudent?.id, detailFrom, detailTo],
    queryFn: () => api(`/students/${detailStudent!.id}/appointments?from=${detailFrom}&to=${detailTo}`),
    enabled: !!detailStudent && !!detailFrom && !!detailTo,
  });

  const save = useMutation({
    mutationFn: (body: any) =>
      edit
        ? api(`/students/${edit.id}`, { method: "PUT", body: JSON.stringify(body) })
        : api(`/students`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["students"] });
      setOpen(false); setForm(emptyForm); setEdit(null);
    },
    onError: (e) => setErr(mensagemDeErro(e, "Não foi possível salvar o aluno.")),
  });
  const del = useMutation({
    mutationFn: (id: string) => api(`/students/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["students"] });
      setConfirmTarget(null);
    },
    onError: (e) => setErr(mensagemDeErro(e, "Não foi possível excluir o aluno.")),
  });
  const changeSituacao = useMutation({
    mutationFn: ({ id, situacao }: { id: string; situacao: string }) =>
      api(`/students/${id}/situacao?situacao=${encodeURIComponent(situacao)}`, { method: "PATCH" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["students"] }),
  });

  const rows: Student[] = data?.content || [];
  const total: number = data?.totalElements ?? 0;
  const from = total === 0 ? 0 : page * PAGE_SIZE + 1;
  const to = Math.min((page + 1) * PAGE_SIZE, total);

  function openNew() { setEdit(null); setForm(emptyForm); setErr(null); setOpen(true); }

  async function openEdit(s: Student) {
    try {
      const full = await api(`/students/${s.id}`);
      setEdit(full);
      setForm({
        fullName: full.fullName ?? "", cpf: full.cpf ?? "",
        matricula: full.matricula ?? "", studentType: full.studentType ?? "Civil",
        departmentId: full.departmentId ?? "", phone: full.phone ?? "",
        email: full.email ?? "", birthDate: full.birthDate ?? "",
        weightKg: full.weightKg != null ? String(full.weightKg) : "",
        heightCm: full.heightCm != null ? String(full.heightCm) : "",
        goal: full.goal ?? "", atestadoNumero: full.atestadoNumero ?? "",
        atestadoData: full.atestadoData ?? "", situacao: full.situacao ?? "ATIVO",
      });
      setErr(null); setOpen(true);
    } catch (e) {
      setErr(mensagemDeErro(e, "Não foi possível carregar os dados do aluno."));
    }
  }

  function buildPayload() {
    return {
      ...form,
      weightKg: form.weightKg !== "" ? Number(form.weightKg) : null,
      heightCm: form.heightCm !== "" ? Number(form.heightCm) : null,
      departmentId: form.departmentId || null,
      birthDate: form.birthDate || null,
      atestadoData: form.atestadoData || null,
    };
  }

  return (
    <div>
      <PageHeader title="Alunos" subtitle={data ? `${total} cadastrados` : undefined}
        actions={canEdit && (<Button onClick={openNew}><Plus className="h-4 w-4" /> Novo aluno</Button>)} />
      <Card className="overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-line p-4 sm:flex-row sm:items-center">
          <div className="relative w-full max-w-sm">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input className="pl-9" placeholder="Buscar por nome ou CPF" value={q}
              onChange={(e) => { setQ(e.target.value); setPage(0); }} />
          </div>
          <Select aria-label="Filtrar por perfil" className="sm:w-44" value={perfil}
            onChange={(e) => { setPerfil(e.target.value); setPage(0); }}>
            <option value="">Todos os perfis</option>
            <option value="aluno">Alunos</option>
            <option value="instrutor">Instrutores</option>
          </Select>
        </div>
        {isLoading ? <TableSkeleton rows={8} /> : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-2 px-4 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
              <UserX className="h-6 w-6" />
            </div>
            <p className="font-medium text-content">{q ? "Nenhum aluno encontrado" : "Nenhum aluno cadastrado"}</p>
            <p className="max-w-xs text-sm text-content-soft">
              {q ? `Não encontramos resultados para "${q}".` : "Assim que alunos forem cadastrados, eles aparecem aqui."}
            </p>
          </div>
        ) : (
          <>
            <div className="hidden md:block">
              <Table>
                <THead><TR><TH>Nome</TH><TH>CPF</TH><TH>Tipo</TH><TH>Secretaria</TH><TH>Atestado</TH><TH>Situação</TH><TH></TH></TR></THead>
                <TBody>
                  {rows.map((s) => {
                    const at = atestadoLabel(s.diasParaVencimentoAtestado);
                    return (
                      <TR key={s.id}>
                        <TD><div className="flex items-center gap-3"><Avatar name={s.fullName} /><span className="font-medium">{s.fullName}</span></div></TD>
                        <TD className="tabular-nums text-content-soft">{s.cpf}</TD>
                        <TD><Badge tone={tomDoTipo(s.studentType)}>{s.studentType}</Badge></TD>
                        <TD className="text-content-soft">{s.departmentName || "—"}</TD>
                        <TD><Badge tone={at.tone}>{at.text}</Badge></TD>
                        <TD>
                          {canEdit ? (
                            <Select className="w-28" value={s.situacao} onChange={(e) => changeSituacao.mutate({ id: s.id, situacao: e.target.value })}>
                              <option value="ATIVO">Ativo</option><option value="INATIVO">Inativo</option><option value="BLOQUEADO">Bloqueado</option>
                            </Select>
                          ) : (
                            <Badge tone={s.situacao === "ATIVO" ? "confirmado" : s.situacao === "BLOQUEADO" ? "warning" : "cancelled"}>
                              {s.situacao === "ATIVO" ? "ativo" : s.situacao === "BLOQUEADO" ? "bloqueado" : "inativo"}
                            </Badge>
                          )}
                        </TD>
                        <TD className="text-right">
                          <div className="flex justify-end gap-1">
                            <Button variant="ghost" size="sm" aria-label={`Detalhes de ${s.fullName}`} onClick={() => setDetailStudent(s)}><Eye className="h-4 w-4" /></Button>
                            {canEdit && <Button variant="ghost" size="sm" aria-label={`Editar ${s.fullName}`} onClick={() => openEdit(s)}><Pencil className="h-4 w-4" /></Button>}
                            {isAdmin && <Button variant="ghost" size="sm" aria-label={`Excluir ${s.fullName}`} onClick={() => setConfirmTarget(s)}><Trash2 className="h-4 w-4 text-danger" /></Button>}
                          </div>
                        </TD>
                      </TR>
                    );
                  })}
                </TBody>
              </Table>
            </div>
            <div className="divide-y divide-line md:hidden">
              {rows.map((s) => {
                const at = atestadoLabel(s.diasParaVencimentoAtestado);
                return (
                  <div key={s.id} className="space-y-2.5 p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div className="flex min-w-0 items-center gap-3">
                        <Avatar name={s.fullName} />
                        <div className="min-w-0">
                          <div className="truncate font-medium text-content">{s.fullName}</div>
                          <div className="tabular-nums text-xs text-content-soft">{s.cpf}</div>
                        </div>
                      </div>
                      <Badge tone={tomDoTipo(s.studentType)}>{s.studentType}</Badge>
                    </div>
                    <div className="flex items-center justify-between gap-3 pl-11">
                      <span className="truncate text-xs text-content-soft">{s.departmentName || "Sem secretaria"}</span>
                      <div className="flex shrink-0 gap-1.5">
                        <Badge tone={at.tone}>{at.text}</Badge>
                        <Badge tone={s.situacao === "ATIVO" ? "confirmado" : s.situacao === "BLOQUEADO" ? "warning" : "cancelado"}>
                          {s.situacao === "ATIVO" ? "ativo" : s.situacao === "BLOQUEADO" ? "bloqueado" : "inativo"}
                        </Badge>
                      </div>
                    </div>
                    <div className="flex justify-end gap-2 pl-11">
                      <Button variant="outline" size="sm" onClick={() => setDetailStudent(s)}><Eye className="mr-1 h-3 w-3" /> Detalhes</Button>
                      {canEdit && <Button variant="outline" size="sm" onClick={() => openEdit(s)}><Pencil className="mr-1 h-3 w-3" /> Editar</Button>}
                      {isAdmin && <Button variant="outline" size="sm" className="text-danger" onClick={() => setConfirmTarget(s)}><Trash2 className="mr-1 h-3 w-3" /> Excluir</Button>}
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
        {data && data.totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-line px-4 py-3 text-sm text-content-soft">
            <span>{from}–{to} de {total}</span>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                <ChevronLeft className="h-4 w-4" /> Anterior
              </Button>
              <Button variant="outline" size="sm" disabled={page + 1 >= data.totalPages} onClick={() => setPage((p) => p + 1)}>
                Próxima <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </Card>

      {/* Create / Edit Modal */}
      <Modal open={open} onClose={() => setOpen(false)} title={edit ? "Editar aluno" : "Novo aluno"}
        footer={<><Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
          <Button loading={save.isPending} onClick={() => {
            const v = validateStudentForm(form); if (v) { setErr(v); return; }
            setErr(null); save.mutate(buildPayload());
          }}>Salvar</Button></>}>
        <div className="max-h-[70vh] space-y-5 overflow-y-auto">
          {err && (<div className="flex items-start gap-2 rounded bg-danger/10 px-3 py-2 text-sm text-danger"><AlertCircle className="mt-0.5 h-4 w-4 shrink-0" /><span>{err}</span></div>)}
          <div className="space-y-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">Dados pessoais</p>
            <div><Label htmlFor="sn">Nome completo</Label><Input id="sn" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} /></div>
            <div className="grid grid-cols-2 gap-4">
              <div><Label htmlFor="sc">CPF</Label><Input id="sc" value={form.cpf} onChange={(e) => setForm({ ...form, cpf: e.target.value })} /></div>
              <div><Label htmlFor="sm">Matrícula</Label><Input id="sm" value={form.matricula} onChange={(e) => setForm({ ...form, matricula: e.target.value })} /></div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div><Label htmlFor="st">Tipo</Label><Select id="st" value={form.studentType} onChange={(e) => setForm({ ...form, studentType: e.target.value })}><option value="Civil">Civil</option><option value="Militar">Militar</option><option value="Instrutor">Instrutor</option></Select>{form.studentType === "Instrutor" && (<p className="mt-1 text-xs text-content-soft">Instrutor prescreve as fichas de treino e não agenda horário.</p>)}</div>
              <div><Label htmlFor="sb">Data de nascimento</Label><Input id="sb" type="date" value={form.birthDate} onChange={(e) => setForm({ ...form, birthDate: e.target.value })} /></div>
            </div>
          </div>
          <div className="space-y-4 border-t border-line pt-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">Vínculo e contato</p>
            <div><Label htmlFor="sd">Secretaria</Label><Select id="sd" value={form.departmentId} onChange={(e) => setForm({ ...form, departmentId: e.target.value })}><option value="">— selecione —</option>{(departments.data || []).map((d: any) => (<option key={d.id} value={d.id}>{d.name}</option>))}</Select></div>
            <div className="grid grid-cols-2 gap-4">
              <div><Label htmlFor="sp">Telefone</Label><Input id="sp" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></div>
              <div><Label htmlFor="se">E-mail</Label><Input id="se" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></div>
            </div>
          </div>
          <div className="space-y-4 border-t border-line pt-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">Dados físicos</p>
            <div className="grid grid-cols-2 gap-4">
              <div><Label htmlFor="sw">Peso (kg)</Label><Input id="sw" type="number" step="0.1" value={form.weightKg} onChange={(e) => setForm({ ...form, weightKg: e.target.value })} /></div>
              <div><Label htmlFor="sh">Altura (cm)</Label><Input id="sh" type="number" value={form.heightCm} onChange={(e) => setForm({ ...form, heightCm: e.target.value })} /></div>
            </div>
            <div><Label htmlFor="sg">Objetivo</Label><Input id="sg" value={form.goal} onChange={(e) => setForm({ ...form, goal: e.target.value })} /></div>
          </div>
          <div className="space-y-4 border-t border-line pt-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">Atestado médico</p>
            <div className="grid grid-cols-2 gap-4">
              <div><Label htmlFor="san">Número</Label><Input id="san" value={form.atestadoNumero} onChange={(e) => setForm({ ...form, atestadoNumero: e.target.value })} /></div>
              <div><Label htmlFor="sad">Data</Label><Input id="sad" type="date" value={form.atestadoData} onChange={(e) => setForm({ ...form, atestadoData: e.target.value })} /></div>
            </div>
          </div>
          {edit && (
            <div className="space-y-4 border-t border-line pt-4">
              <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">Situação</p>
              <div><Label htmlFor="ss">Status</Label><Select id="ss" value={form.situacao} onChange={(e) => setForm({ ...form, situacao: e.target.value })}><option value="ATIVO">Ativo</option><option value="INATIVO">Inativo</option><option value="BLOQUEADO">Bloqueado</option></Select></div>
            </div>
          )}
        </div>
      </Modal>

      {/* Delete Confirmation */}
      <ConfirmDialog
        open={!!confirmTarget}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => del.mutate(confirmTarget!.id)}
        loading={del.isPending}
        title="Excluir aluno"
        message={<>Tem certeza que deseja excluir <strong>{confirmTarget?.fullName}</strong>? Essa ação não pode ser desfeita.</>}
      />

      {/* Detail History Modal */}
      <Modal open={!!detailStudent} onClose={() => setDetailStudent(null)} title={`Histórico — ${detailStudent?.fullName}`}
        footer={<Button variant="outline" onClick={() => setDetailStudent(null)}>Fechar</Button>}>
        <div className="space-y-4">
          <div className="flex gap-3">
            <div><Label>De</Label><Input type="date" value={detailFrom} onChange={(e) => setDetailFrom(e.target.value)} /></div>
            <div><Label>Até</Label><Input type="date" value={detailTo} onChange={(e) => setDetailTo(e.target.value)} /></div>
          </div>
          {detailHistory.isLoading ? <TableSkeleton rows={5} /> : (
            <Table>
              <THead><TR><TH>Data</TH><TH>Horário</TH><TH>Status</TH><TH>Entrada</TH><TH>Saída</TH><TH>Permanência</TH></TR></THead>
              <TBody>
                {(detailHistory.data || []).length === 0 && (
                  <TR><TD colSpan={6} className="py-6 text-center text-content-soft">Nenhum registro no período.</TD></TR>
                )}
                {(detailHistory.data || []).map((a: any) => (
                  <TR key={a.id}>
                    <TD>{new Date(a.date).toLocaleDateString("pt-BR")}</TD>
                    <TD>{a.slotStart} – {a.slotEnd}</TD>
                    <TD><Badge tone={a.status === "confirmado" ? "success" : a.status === "faltou" ? "faltou" : a.status === "cancelado" ? "cancelled" : "neutral"}>{a.status}</Badge></TD>
                    <TD className="text-content-soft">{a.entradaConfirmadaEm ? new Date(a.entradaConfirmadaEm).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }) : "—"}</TD>
                    <TD className="text-content-soft">{a.saidaConfirmadaEm ? new Date(a.saidaConfirmadaEm).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }) : "—"}</TD>
                    <TD className="tabular-nums text-content-soft">{a.permanenciaMinutos != null ? `${a.permanenciaMinutos} min` : "—"}</TD>
                  </TR>
                ))}
              </TBody>
            </Table>
          )}
        </div>
      </Modal>
    </div>
  );
}