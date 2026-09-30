import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { mensagemDeErro } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { formatDate } from "@/lib/utils";
import type { AlunoResumo, Ficha } from "@/lib/fichas";
import { PageHeader } from "@/components/PageHeader";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { FichaEditor, type ModoEditor } from "@/components/FichaEditor";
import { Avatar, Badge, Button, Card, CardContent, Input, Skeleton, Table, TBody, TD, TH, THead, TR } from "@/components/ui";
import { ClipboardList, Copy, Pencil, Plus, Search, Trash2 } from "lucide-react";

/**
 * Fichas de treino (A–D) por aluno. Instrutor (papel professor) e admin
 * montam, editam, reaproveitam ("usar como modelo") e excluem fichas com os
 * exercícios do catálogo — o aluno vê a ficha em "Meu Treino" no app.
 */
export default function WorkoutPlans() {
  const { hasRole } = useAuth();
  const podeEditar = hasRole("admin", "professor");
  const qc = useQueryClient();
  const [q, setQ] = useState("");
  const [student, setStudent] = useState<AlunoResumo | null>(null);
  const [editor, setEditor] = useState<{ modo: ModoEditor; ficha: Ficha | null } | null>(null);
  const [excluir, setExcluir] = useState<Ficha | null>(null);

  const students = useQuery({
    queryKey: ["wp-students", q],
    queryFn: () => api(`/students?q=${encodeURIComponent(q)}&size=6&perfil=aluno`),
    enabled: q.length >= 2,
  });
  const plans = useQuery({
    queryKey: ["plans", student?.id],
    queryFn: () => api<Ficha[]>(`/students/${student!.id}/workout-plans`),
    enabled: !!student,
  });

  const remover = useMutation({
    mutationFn: (f: Ficha) => api(`/workout-plans/${f.id}`, { method: "DELETE" }),
    onSuccess: (_d, f) => {
      qc.invalidateQueries({ queryKey: ["plans", f.studentId] });
      setExcluir(null);
      toast("success", `Ficha ${f.sheetLabel} excluída.`);
    },
    onError: (err) => {
      setExcluir(null);
      toast("error", mensagemDeErro(err, "Não foi possível excluir a ficha."));
    },
  });

  function aoSalvar(salva: Ficha, destino: AlunoResumo) {
    const modo = editor?.modo;
    setEditor(null);
    qc.invalidateQueries({ queryKey: ["plans", destino.id] });
    if (destino.id !== student?.id) {
      // Modelo aplicado a outro aluno: passa a mostrar as fichas dele.
      setStudent(destino);
      setQ(destino.fullName);
    }
    toast(
      "success",
      modo === "editar"
        ? `Ficha ${salva.sheetLabel} atualizada.`
        : `Ficha ${salva.sheetLabel} criada para ${destino.fullName}.`
    );
  }

  const fichas = plans.data || [];

  return (
    <div>
      <PageHeader title="Fichas de Treino" subtitle="Prescrição por aluno (A–D)" />

      <Card className="mb-6 p-4">
        <div className="relative max-w-md">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
          <Input className="pl-9" placeholder="Buscar aluno (nome ou CPF)" value={q}
            onChange={(e) => { setQ(e.target.value); setStudent(null); }} />
        </div>
        {q.length >= 2 && !student && (
          <div className="mt-3 max-h-72 divide-y divide-line overflow-y-auto rounded-md border border-line bg-surface shadow-2">
            {students.isLoading ? (
              <div className="px-3 py-3 text-sm text-content-soft">Buscando…</div>
            ) : (students.data?.content || []).length > 0 ? (
              (students.data?.content || []).map((s: any) => (
                <button key={s.id} onClick={() => { setStudent({ id: s.id, fullName: s.fullName, cpf: s.cpf }); setQ(s.fullName); }}
                  className="flex w-full items-center gap-3 px-3 py-3 text-left transition-colors duration-fast hover:bg-surface-alt focus-visible:bg-surface-alt focus-visible:outline-none">
                  <Avatar name={s.fullName} className="h-7 w-7 text-[11px]" />
                  <span className="flex-1 truncate text-sm font-medium text-content">{s.fullName}</span>
                  <span className="shrink-0 text-xs tabular-nums text-content-soft">{s.cpf}</span>
                </button>
              ))
            ) : (
              <div className="px-3 py-3 text-sm text-content-soft">Nenhum aluno encontrado.</div>
            )}
          </div>
        )}
        {!student && q.length < 2 && (
          <p className="mt-3 text-sm text-content-faint">Digite ao menos 2 letras para localizar o aluno.</p>
        )}
      </Card>

      {student && (
        <>
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <Avatar name={student.fullName} className="h-9 w-9" />
            <div className="min-w-0 flex-1">
              <h3 className="text-lg font-semibold leading-tight text-content">{student.fullName}</h3>
              <p className="text-xs text-content-soft">
                {plans.data ? `${fichas.length} ficha${fichas.length === 1 ? "" : "s"} cadastrada${fichas.length === 1 ? "" : "s"}` : "Fichas de treino"}
              </p>
            </div>
            {podeEditar && (
              <Button onClick={() => setEditor({ modo: "novo", ficha: null })}>
                <Plus className="h-4 w-4" /> Nova ficha
              </Button>
            )}
          </div>

          {plans.isLoading ? (
            <div className="space-y-5">
              {Array.from({ length: 2 }).map((_, i) => (
                <Card key={i} className="p-5">
                  <div className="mb-4 flex items-center gap-3">
                    <Skeleton className="h-10 w-10 rounded-full" />
                    <Skeleton className="h-5 w-40" />
                  </div>
                  <Skeleton className="h-28 w-full" />
                </Card>
              ))}
            </div>
          ) : fichas.length === 0 ? (
            <Card>
              <CardContent className="flex flex-col items-center gap-2 py-10 text-center text-content-soft">
                <ClipboardList className="h-8 w-8 text-content-faint" />
                <p>Nenhuma ficha cadastrada.</p>
                {podeEditar && (
                  <p className="text-sm">Use "Nova ficha" para montar a primeira com os exercícios do catálogo.</p>
                )}
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-5">
              {fichas.map((p) => (
                <Card key={p.id} className={!p.active ? "opacity-70" : undefined}>
                  <CardContent className="pt-5">
                    <div className="mb-4 flex flex-wrap items-center gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-container text-base font-bold text-brand">
                        {p.sheetLabel}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="truncate font-semibold text-content">{p.title}</span>
                          {!p.active && <Badge tone="cancelado">inativa</Badge>}
                          {p.validUntil && <Badge tone="neutral">válida até {formatDate(p.validUntil)}</Badge>}
                        </div>
                        <span className="text-xs text-content-soft">
                          {p.exercises.length} exercício{p.exercises.length === 1 ? "" : "s"}
                        </span>
                      </div>
                      {podeEditar && (
                        <div className="flex shrink-0 items-center gap-1">
                          <Button variant="ghost" size="sm" onClick={() => setEditor({ modo: "modelo", ficha: p })}>
                            <Copy className="h-4 w-4" /> Usar como modelo
                          </Button>
                          <Button variant="ghost" size="sm" onClick={() => setEditor({ modo: "editar", ficha: p })}>
                            <Pencil className="h-4 w-4" /> Editar
                          </Button>
                          <Button variant="ghost" size="sm" aria-label={`Excluir ficha ${p.sheetLabel}`} onClick={() => setExcluir(p)}>
                            <Trash2 className="h-4 w-4 text-danger" />
                          </Button>
                        </div>
                      )}
                    </div>
                    <Table>
                      <THead><TR><TH>Exercício</TH><TH>Séries</TH><TH>Reps</TH><TH>Descanso</TH><TH>Observações</TH></TR></THead>
                      <TBody>
                        {[...p.exercises].sort((a, b) => (a.ordem ?? 0) - (b.ordem ?? 0)).map((e, i) => (
                          <TR key={i}>
                            <TD className="font-medium">{e.exerciseName}</TD>
                            <TD className="tabular-nums">{e.sets ?? "—"}</TD>
                            <TD className="tabular-nums">{e.reps ?? "—"}</TD>
                            <TD className="tabular-nums">{e.restSeconds ? `${e.restSeconds}s` : "—"}</TD>
                            <TD className="text-content-soft">{e.notes || "—"}</TD>
                          </TR>
                        ))}
                      </TBody>
                    </Table>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </>
      )}

      <FichaEditor
        open={!!editor}
        modo={editor?.modo ?? "novo"}
        ficha={editor?.ficha ?? null}
        aluno={student}
        onClose={() => setEditor(null)}
        onSaved={aoSalvar}
      />

      <ConfirmDialog
        open={!!excluir}
        onClose={() => setExcluir(null)}
        onConfirm={() => excluir && remover.mutate(excluir)}
        loading={remover.isPending}
        title={`Excluir a ficha ${excluir?.sheetLabel ?? ""}?`}
        message={`"${excluir?.title ?? ""}" deixa de aparecer para o aluno. Essa ação não pode ser desfeita por aqui.`}
      />
    </div>
  );
}
