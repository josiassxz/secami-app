import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { Avatar, Badge, Card, CardContent, Input, Skeleton, Table, TBody, TD, TH, THead, TR } from "@/components/ui";
import { ClipboardList, Search } from "lucide-react";

export default function WorkoutPlans() {
  const [q, setQ] = useState("");
  const [student, setStudent] = useState<any>(null);

  const students = useQuery({
    queryKey: ["wp-students", q],
    queryFn: () => api(`/students?q=${encodeURIComponent(q)}&size=6`),
    enabled: q.length >= 2,
  });
  const plans = useQuery({
    queryKey: ["plans", student?.id],
    queryFn: () => api(`/students/${student.id}/workout-plans`),
    enabled: !!student,
  });

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
                <button key={s.id} onClick={() => { setStudent(s); setQ(s.fullName); }}
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
          <div className="mb-4 flex items-center gap-3">
            <Avatar name={student.fullName} className="h-9 w-9" />
            <div>
              <h3 className="text-lg font-semibold leading-tight text-content">{student.fullName}</h3>
              <p className="text-xs text-content-soft">
                {plans.data ? `${plans.data.length} ficha${plans.data.length === 1 ? "" : "s"} cadastrada${plans.data.length === 1 ? "" : "s"}` : "Fichas de treino"}
              </p>
            </div>
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
          ) : (plans.data || []).length === 0 ? (
            <Card>
              <CardContent className="flex flex-col items-center gap-2 py-10 text-center text-content-soft">
                <ClipboardList className="h-8 w-8 text-content-faint" />
                <p>Nenhuma ficha cadastrada.</p>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-5">
              {(plans.data || []).map((p: any) => (
                <Card key={p.id} className={!p.active ? "opacity-70" : undefined}>
                  <CardContent className="pt-5">
                    <div className="mb-4 flex items-center gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-container text-base font-bold text-brand">
                        {p.sheetLabel}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="truncate font-semibold text-content">{p.title}</span>
                          {!p.active && <Badge tone="cancelado">inativa</Badge>}
                        </div>
                        <span className="text-xs text-content-soft">
                          {p.exercises.length} exercício{p.exercises.length === 1 ? "" : "s"}
                        </span>
                      </div>
                    </div>
                    <Table>
                      <THead><TR><TH>Exercício</TH><TH>Séries</TH><TH>Reps</TH><TH>Descanso</TH></TR></THead>
                      <TBody>
                        {p.exercises.map((e: any, i: number) => (
                          <TR key={i}>
                            <TD className="font-medium">{e.exerciseName}</TD>
                            <TD className="tabular-nums">{e.sets ?? "—"}</TD>
                            <TD className="tabular-nums">{e.reps ?? "—"}</TD>
                            <TD className="tabular-nums">{e.restSeconds ? `${e.restSeconds}s` : "—"}</TD>
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
    </div>
  );
}
