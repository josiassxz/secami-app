import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import {
  Avatar,
  Badge,
  Button,
  Card,
  Input,
  Label,
  Select,
  Table,
  TableSkeleton,
  TBody,
  TD,
  TH,
  THead,
  TR,
} from "@/components/ui";
import { AlertCircle, ChevronLeft, ChevronRight, Plus, Search, UserX } from "lucide-react";

type Student = {
  id: string;
  fullName: string;
  cpf: string;
  studentType: string;
  departmentName?: string;
  active: boolean;
  atestadoValido: boolean;
};

const empty = {
  fullName: "",
  cpf: "",
  studentType: "Civil",
  departmentId: "",
  phone: "",
  email: "",
};

const PAGE_SIZE = 15;
const SEARCH_DEBOUNCE_MS = 300;

/** Valida os campos obrigatórios do formulário de novo aluno.
 *  Retorna a mensagem de erro do primeiro campo inválido, ou null se tudo ok. */
function validateStudentForm(f: typeof empty): string | null {
  if (!f.fullName.trim()) return "Informe o nome completo.";
  if (!f.cpf.trim()) return "Informe o CPF.";
  return null;
}

export default function Students() {
  const { hasRole } = useAuth();
  const qc = useQueryClient();
  const canEdit = hasRole("admin", "gerente");
  const [q, setQ] = useState("");
  // Termo de busca com debounce: evita disparar uma requisição a cada tecla digitada.
  const [debouncedQ, setDebouncedQ] = useState("");
  const [page, setPage] = useState(0);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<any>(empty);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    const id = setTimeout(() => setDebouncedQ(q), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(id);
  }, [q]);

  const { data, isLoading } = useQuery({
    queryKey: ["students", debouncedQ, page],
    queryFn: () => api(`/students?q=${encodeURIComponent(debouncedQ)}&page=${page}&size=${PAGE_SIZE}`),
  });
  const departments = useQuery({ queryKey: ["departments"], queryFn: () => api(`/departments`) });

  const save = useMutation({
    mutationFn: (body: any) =>
      api(`/students`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["students"] });
      setOpen(false);
      setForm(empty);
    },
    onError: (e: any) => setErr(e.message),
  });

  const rows: Student[] = data?.content || [];
  const total: number = data?.totalElements ?? 0;
  const from = total === 0 ? 0 : page * PAGE_SIZE + 1;
  const to = Math.min((page + 1) * PAGE_SIZE, total);

  return (
    <div>
      <PageHeader
        title="Alunos"
        subtitle={data ? `${total} cadastrados` : undefined}
        actions={
          canEdit && (
            <Button onClick={() => { setForm(empty); setErr(null); setOpen(true); }}>
              <Plus className="h-4 w-4" /> Novo aluno
            </Button>
          )
        }
      />

      <Card className="overflow-hidden">
        {/* Toolbar */}
        <div className="border-b border-line p-4">
          <div className="relative max-w-sm">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input
              className="pl-9"
              placeholder="Buscar por nome ou CPF"
              value={q}
              onChange={(e) => { setQ(e.target.value); setPage(0); }}
            />
          </div>
        </div>

        {isLoading ? (
          <TableSkeleton rows={8} />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-2 px-4 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
              <UserX className="h-6 w-6" />
            </div>
            <p className="font-medium text-content">
              {q ? "Nenhum aluno encontrado" : "Nenhum aluno cadastrado"}
            </p>
            <p className="max-w-xs text-sm text-content-soft">
              {q
                ? `Não encontramos resultados para "${q}". Confira o nome ou CPF digitado.`
                : "Assim que alunos forem cadastrados, eles aparecem aqui."}
            </p>
          </div>
        ) : (
          <>
            {/* Desktop: tabela */}
            <div className="hidden md:block">
              <Table>
                <THead>
                  <TR>
                    <TH>Nome</TH>
                    <TH>CPF</TH>
                    <TH>Tipo</TH>
                    <TH>Secretaria</TH>
                    <TH>Atestado</TH>
                    <TH>Situação</TH>
                  </TR>
                </THead>
                <TBody>
                  {rows.map((s) => (
                    <TR key={s.id}>
                      <TD>
                        <div className="flex items-center gap-3">
                          <Avatar name={s.fullName} />
                          <span className="font-medium">{s.fullName}</span>
                        </div>
                      </TD>
                      <TD className="tabular-nums text-content-soft">{s.cpf}</TD>
                      <TD>
                        <Badge tone={s.studentType === "Militar" ? "warning" : "info"}>
                          {s.studentType}
                        </Badge>
                      </TD>
                      <TD className="text-content-soft">{s.departmentName || "—"}</TD>
                      <TD>
                        <Badge tone={s.atestadoValido ? "success" : "faltou"}>
                          {s.atestadoValido ? "válido" : "pendente"}
                        </Badge>
                      </TD>
                      <TD>
                        <Badge tone={s.active ? "confirmado" : "cancelado"}>
                          {s.active ? "ativo" : "inativo"}
                        </Badge>
                      </TD>
                    </TR>
                  ))}
                </TBody>
              </Table>
            </div>

            {/* Mobile/tablet: cards empilhados (< md) */}
            <div className="divide-y divide-line md:hidden">
              {rows.map((s) => (
                <div key={s.id} className="space-y-2.5 p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <Avatar name={s.fullName} />
                      <div className="min-w-0">
                        <div className="truncate font-medium text-content">{s.fullName}</div>
                        <div className="tabular-nums text-xs text-content-soft">{s.cpf}</div>
                      </div>
                    </div>
                    <Badge tone={s.studentType === "Militar" ? "warning" : "info"}>
                      {s.studentType}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between gap-3 pl-11">
                    <span className="truncate text-xs text-content-soft">
                      {s.departmentName || "Sem secretaria"}
                    </span>
                    <div className="flex shrink-0 gap-1.5">
                      <Badge tone={s.atestadoValido ? "success" : "faltou"}>
                        atestado {s.atestadoValido ? "válido" : "pendente"}
                      </Badge>
                      <Badge tone={s.active ? "confirmado" : "cancelado"}>
                        {s.active ? "ativo" : "inativo"}
                      </Badge>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}

        {data && data.totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-line px-4 py-3 text-sm text-content-soft">
            <span>
              {from}–{to} de {total}
            </span>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                <ChevronLeft className="h-4 w-4" /> Anterior
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={page + 1 >= data.totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                Próxima <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </Card>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="Novo aluno"
        footer={
          <>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancelar</Button>
            <Button
              loading={save.isPending}
              onClick={() => {
                const validationError = validateStudentForm(form);
                if (validationError) {
                  setErr(validationError);
                  return;
                }
                setErr(null);
                save.mutate(form);
              }}
            >
              Salvar
            </Button>
          </>
        }
      >
        <div className="space-y-5">
          <div className="space-y-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">
              Dados pessoais
            </p>
            <div>
              <Label htmlFor="student-fullName">Nome completo</Label>
              <Input
                id="student-fullName"
                value={form.fullName}
                onChange={(e) => setForm({ ...form, fullName: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="student-cpf">CPF</Label>
                <Input
                  id="student-cpf"
                  value={form.cpf}
                  onChange={(e) => setForm({ ...form, cpf: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="student-type">Tipo</Label>
                <Select
                  id="student-type"
                  value={form.studentType}
                  onChange={(e) => setForm({ ...form, studentType: e.target.value })}
                >
                  <option value="Civil">Civil</option>
                  <option value="Militar">Militar</option>
                </Select>
              </div>
            </div>
          </div>

          <div className="space-y-4 border-t border-line pt-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-content-faint">
              Vínculo e contato
            </p>
            <div>
              <Label htmlFor="student-department">Secretaria</Label>
              <Select
                id="student-department"
                value={form.departmentId}
                onChange={(e) => setForm({ ...form, departmentId: e.target.value })}
              >
                <option value="">— selecione —</option>
                {(departments.data || []).map((d: any) => (
                  <option key={d.id} value={d.id}>{d.name}</option>
                ))}
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="student-phone">Telefone</Label>
                <Input
                  id="student-phone"
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="student-email">E-mail</Label>
                <Input
                  id="student-email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                />
              </div>
            </div>
          </div>

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
