import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Avatar, Badge, Button, Card, Input, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { AlertCircle, CalendarDays, CheckCircle2, LogIn, LogOut, Search, Undo2, UserCheck } from "lucide-react";

const todayStr = () => new Date().toISOString().slice(0, 10);

type Flash = { type: "success" | "error"; text: string };

export default function CheckIn() {
  const qc = useQueryClient();
  const [date, setDate] = useState(todayStr());
  const [q, setQ] = useState("");

  // Feedback rápido (toast) — a recepção trabalha em ritmo acelerado e
  // precisa de confirmação visual imediata de sucesso/erro em cada ação.
  const [flash, setFlash] = useState<Flash | null>(null);
  const [flashShow, setFlashShow] = useState(false);
  const hideTimer = useRef<number>();
  const clearTimer = useRef<number>();

  useEffect(() => () => {
    window.clearTimeout(hideTimer.current);
    window.clearTimeout(clearTimer.current);
  }, []);

  function notify(type: Flash["type"], text: string) {
    window.clearTimeout(hideTimer.current);
    window.clearTimeout(clearTimer.current);
    setFlash({ type, text });
    requestAnimationFrame(() => setFlashShow(true));
    hideTimer.current = window.setTimeout(() => {
      setFlashShow(false);
      clearTimer.current = window.setTimeout(() => setFlash(null), 200);
    }, 2800);
  }

  const checkins = useQuery({ queryKey: ["checkins", date], queryFn: () => api(`/checkins?date=${date}`) });
  const students = useQuery({
    queryKey: ["students-search", q],
    queryFn: () => api(`/students?q=${encodeURIComponent(q)}&size=6`),
    enabled: q.length >= 2,
  });

  const doCheckIn = useMutation({
    mutationFn: (studentId: string) => api(`/checkins`, { method: "POST", body: JSON.stringify({ studentId, date }) }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["checkins"] });
      setQ("");
      notify("success", "Check-in registrado.");
    },
    onError: (e: any) => notify("error", e?.message || "Não foi possível registrar o check-in."),
  });
  const doCheckout = useMutation({
    mutationFn: (id: string) => api(`/checkins/${id}/checkout`, { method: "PATCH" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["checkins"] });
      notify("success", "Saída registrada.");
    },
    onError: (e: any) => notify("error", e?.message || "Não foi possível registrar a saída."),
  });
  const doUndo = useMutation({
    mutationFn: (id: string) => api(`/checkins/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["checkins"] });
      notify("success", "Check-in desfeito.");
    },
    onError: (e: any) => notify("error", e?.message || "Não foi possível desfazer o check-in."),
  });

  const rows: any[] = checkins.data || [];

  return (
    <div>
      <PageHeader
        title="Check-in"
        subtitle="Presença na recepção"
        actions={
          <div className="relative">
            <CalendarDays className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input type="date" className="w-auto pl-9" value={date} onChange={(e) => setDate(e.target.value)} />
          </div>
        }
      />

      <Card className="mb-6 p-4">
        <div className="relative max-w-md">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
          <Input
            className="pl-9"
            placeholder="Buscar aluno para check-in (nome ou CPF)"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        {q.length >= 2 && (
          <div className="mt-2 divide-y divide-line overflow-hidden rounded-md border border-line">
            {(students.data?.content || []).map((s: any) => {
              const pending = doCheckIn.isPending && doCheckIn.variables === s.id;
              return (
                <div
                  key={s.id}
                  className="flex items-center justify-between gap-3 px-3 py-2.5 transition-colors duration-fast hover:bg-surface-alt"
                >
                  <div className="flex min-w-0 items-center gap-3">
                    <Avatar name={s.fullName} />
                    <div className="min-w-0">
                      <div className="truncate text-sm font-medium text-content">{s.fullName}</div>
                      <div className="text-xs text-content-soft">{s.cpf} · {s.studentType}</div>
                    </div>
                  </div>
                  <Button
                    size="sm"
                    loading={pending}
                    disabled={doCheckIn.isPending && !pending}
                    onClick={() => doCheckIn.mutate(s.id)}
                  >
                    <LogIn className="h-4 w-4" /> Check-in
                  </Button>
                </div>
              );
            })}
            {(students.data?.content || []).length === 0 && (
              <div className="px-3 py-2.5 text-sm text-content-soft">Nenhum aluno encontrado.</div>
            )}
          </div>
        )}
      </Card>

      <Card className="overflow-hidden">
        {checkins.isLoading ? (
          <TableSkeleton rows={6} />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-2 px-4 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
              <UserCheck className="h-6 w-6" />
            </div>
            <p className="font-medium text-content">Nenhum check-in neste dia</p>
            <p className="max-w-xs text-sm text-content-soft">
              Busque um aluno acima para registrar a primeira entrada do dia.
            </p>
          </div>
        ) : (
          <>
            {/* Desktop: tabela */}
            <div className="hidden md:block">
              <Table>
                <THead>
                  <TR>
                    <TH>Aluno</TH>
                    <TH>Entrada</TH>
                    <TH>Saída</TH>
                    <TH>Situação</TH>
                    <TH></TH>
                  </TR>
                </THead>
                <TBody>
                  {rows.map((c: any) => {
                    const present = !c.checkOutTime;
                    const checkoutPending = doCheckout.isPending && doCheckout.variables === c.id;
                    const undoPending = doUndo.isPending && doUndo.variables === c.id;
                    return (
                      <TR key={c.id} className={present ? "bg-success/[.04]" : undefined}>
                        <TD>
                          <div className="flex items-center gap-3">
                            <Avatar name={c.studentName} />
                            <span className="font-medium">{c.studentName}</span>
                          </div>
                        </TD>
                        <TD className="tabular-nums">{c.checkInTime}</TD>
                        <TD className="tabular-nums">{c.checkOutTime || "—"}</TD>
                        <TD>
                          <Badge tone={present ? "agendado" : "confirmado"}>
                            {present ? "presente" : "concluído"}
                          </Badge>
                        </TD>
                        <TD className="text-right">
                          <div className="flex justify-end gap-1.5">
                            {present && (
                              <Button
                                variant="outline"
                                size="sm"
                                loading={checkoutPending}
                                disabled={undoPending}
                                onClick={() => doCheckout.mutate(c.id)}
                              >
                                <LogOut className="h-4 w-4" /> Saída
                              </Button>
                            )}
                            <Button
                              variant="ghost"
                              size="sm"
                              title="Desfazer check-in"
                              aria-label="Desfazer check-in"
                              loading={undoPending}
                              disabled={checkoutPending}
                              onClick={() => doUndo.mutate(c.id)}
                            >
                              {!undoPending && <Undo2 className="h-4 w-4 text-danger" />}
                            </Button>
                          </div>
                        </TD>
                      </TR>
                    );
                  })}
                </TBody>
              </Table>
            </div>

            {/* Mobile/tablet: cards empilhados (< md) */}
            <div className="divide-y divide-line md:hidden">
              {rows.map((c: any) => {
                const present = !c.checkOutTime;
                const checkoutPending = doCheckout.isPending && doCheckout.variables === c.id;
                const undoPending = doUndo.isPending && doUndo.variables === c.id;
                return (
                  <div key={c.id} className={cn("p-4", present && "bg-success/[.04]")}>
                    <div className="flex items-center justify-between gap-3">
                      <div className="flex min-w-0 items-center gap-3">
                        <Avatar name={c.studentName} />
                        <div className="min-w-0">
                          <div className="truncate font-medium text-content">{c.studentName}</div>
                          <div className="tabular-nums text-xs text-content-soft">
                            {c.checkInTime}{c.checkOutTime ? ` – ${c.checkOutTime}` : ""}
                          </div>
                        </div>
                      </div>
                      <Badge tone={present ? "agendado" : "confirmado"}>
                        {present ? "presente" : "concluído"}
                      </Badge>
                    </div>
                    <div className="mt-2.5 flex justify-end gap-1.5">
                      {present && (
                        <Button
                          variant="outline"
                          size="sm"
                          loading={checkoutPending}
                          disabled={undoPending}
                          onClick={() => doCheckout.mutate(c.id)}
                        >
                          <LogOut className="h-4 w-4" /> Saída
                        </Button>
                      )}
                      <Button
                        variant="ghost"
                        size="sm"
                        title="Desfazer check-in"
                        aria-label="Desfazer check-in"
                        loading={undoPending}
                        disabled={checkoutPending}
                        onClick={() => doUndo.mutate(c.id)}
                      >
                        {!undoPending && <Undo2 className="h-4 w-4 text-danger" />} Desfazer
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </Card>

      {/* Toast de feedback — sucesso/erro das ações de check-in/checkout/desfazer */}
      {flash && (
        <div
          role="status"
          aria-live="polite"
          className={cn(
            "fixed right-6 top-6 z-50 flex max-w-sm items-start gap-2.5 rounded-md border bg-surface px-4 py-3 text-sm font-medium shadow-3 transition-all duration-base ease-standard",
            flashShow ? "translate-y-0 opacity-100" : "-translate-y-2 opacity-0",
            flash.type === "success" ? "border-success/30 text-success" : "border-danger/30 text-danger"
          )}
        >
          {flash.type === "success" ? (
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
          ) : (
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          )}
          <span className="text-content">{flash.text}</span>
        </div>
      )}
    </div>
  );
}
