import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn, formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import {
  Avatar, Badge, Button, Card, CardContent, Input, Label, Select,
  Skeleton, Table, TableSkeleton, TBody, TD, TH, THead, TR,
} from "@/components/ui";
import {
  CalendarClock, CheckCircle2, XCircle, Ban, Clock3, ShieldCheck,
  ChevronLeft, ChevronRight, Download, Search,
} from "lucide-react";

/* ------------------------------------------------------------------ */
/* Helpers                                                            */
/* ------------------------------------------------------------------ */

function ago(days: number) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().slice(0, 10);
}

function horaLocal(iso?: string | null) {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
}

function formatarPermanencia(min: number) {
  const h = Math.floor(min / 60);
  const m = Math.round(min % 60);
  return h > 0 ? `${h}h${m.toString().padStart(2, "0")}` : `${m}min`;
}

const STATUS_META: Record<string, { label: string; icon: any; iconClass: string }> = {
  agendado:   { label: "Agendado",   icon: CalendarClock, iconClass: "bg-info/10 text-info" },
  confirmado: { label: "Confirmado", icon: CheckCircle2,  iconClass: "bg-success/10 text-success" },
  faltou:     { label: "Faltou",     icon: XCircle,       iconClass: "bg-danger/10 text-danger" },
  cancelado:  { label: "Cancelado",  icon: Ban,           iconClass: "bg-surface-alt text-content-soft" },
};

const PAGE_SIZE = 50;
const SEARCH_DEBOUNCE_MS = 300;

/* ------------------------------------------------------------------ */
/* Component                                                          */
/* ------------------------------------------------------------------ */

export default function Reports() {
  /* ---- filter state ---- */
  const [from, setFrom] = useState(ago(30));
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const [status, setStatus] = useState("");
  const [q, setQ] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [page, setPage] = useState(0);

  useEffect(() => {
    const id = setTimeout(() => setDebouncedQ(q), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(id);
  }, [q]);

  // Reset page when filters change
  useEffect(() => { setPage(0); }, [from, to, status, debouncedQ]);

  /* ---- queries ---- */
  const queryParams = `from=${from}&to=${to}${status ? `&status=${encodeURIComponent(status)}` : ""}${debouncedQ ? `&q=${encodeURIComponent(debouncedQ)}` : ""}&page=${page}&size=${PAGE_SIZE}`;

  const { data, isLoading } = useQuery({
    queryKey: ["report-appts", from, to, status, debouncedQ, page],
    queryFn: () => api(`/appointments?${queryParams}`),
  });

  const { data: summary, isLoading: summaryLoading } = useQuery({
    queryKey: ["report-summary", from, to, status, debouncedQ],
    queryFn: () => api(`/appointments/summary?from=${from}&to=${to}${status ? `&status=${encodeURIComponent(status)}` : ""}${debouncedQ ? `&q=${encodeURIComponent(debouncedQ)}` : ""}`),
  });

  /* ---- derived ---- */
  const rows: any[] = data?.content || [];
  const total: number = data?.totalElements ?? 0;
  const totalPages: number = data?.totalPages ?? 0;
  const fromRow = total === 0 ? 0 : page * PAGE_SIZE + 1;
  const toRow = Math.min((page + 1) * PAGE_SIZE, total);

  /* ---- export ---- */
  function handleExport() {
    const url = `/appointments/export?from=${from}&to=${to}${status ? `&status=${encodeURIComponent(status)}` : ""}${debouncedQ ? `&q=${encodeURIComponent(debouncedQ)}` : ""}`;
    window.open(url, "_blank");
  }

  /* ---- render ---- */
  return (
    <div>
      <PageHeader
        title="Relatórios"
        subtitle="Frequência e agendamentos"
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Input type="date" className="w-auto" aria-label="Data inicial" value={from} onChange={(e) => setFrom(e.target.value)} />
            <span className="text-sm text-content-soft">até</span>
            <Input type="date" className="w-auto" aria-label="Data final" value={to} onChange={(e) => setTo(e.target.value)} />
            <Button variant="outline" onClick={handleExport}>
              <Download className="h-4 w-4" /> Exportar Excel
            </Button>
          </div>
        }
      />

      {/* Filters bar */}
      <Card className="mb-6">
        <div className="flex flex-wrap items-end gap-4 p-4">
          <div className="relative max-w-xs flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input
              className="pl-9"
              placeholder="Buscar por nome ou CPF"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>
          <div className="w-40">
            <Label>Status</Label>
            <Select value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="">Todos</option>
              <option value="agendado">Agendado</option>
              <option value="confirmado">Confirmado</option>
              <option value="faltou">Faltou</option>
              <option value="cancelado">Cancelado</option>
            </Select>
          </div>
        </div>
      </Card>

      {/* KPI Cards — status counts */}
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {(["agendado", "confirmado", "faltou", "cancelado"] as const).map((s) => {
          const meta = STATUS_META[s];
          const Icon = meta.icon;
          const count = summary ? (summary as any)[s] : undefined;
          return (
            <Card key={s}>
              <CardContent className="flex items-center gap-4 py-5">
                <div className={cn("flex h-12 w-12 items-center justify-center rounded-lg", meta.iconClass)}>
                  <Icon className="h-5 w-5" />
                </div>
                <div>
                  {summaryLoading ? (
                    <Skeleton className="mb-1 h-7 w-12" />
                  ) : (
                    <div className="text-[26px] font-bold leading-none tabular-nums text-content">{count ?? 0}</div>
                  )}
                  <div className="mt-1 text-sm text-content-soft">{meta.label}</div>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* KPI Cards — metrics */}
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <Card>
          <CardContent className="flex items-center gap-4 py-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-info/10 text-info">
              <Clock3 className="h-5 w-5" />
            </div>
            <div>
              {summaryLoading ? (
                <Skeleton className="mb-1 h-7 w-16" />
              ) : (
                <div className="text-[26px] font-bold leading-none tabular-nums text-content">
                  {summary?.permanenciaMediaMinutos != null ? formatarPermanencia(summary.permanenciaMediaMinutos) : "—"}
                </div>
              )}
              <div className="mt-1 text-sm text-content-soft">Permanência média</div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="flex items-center gap-4 py-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-danger/10 text-danger">
              <XCircle className="h-5 w-5" />
            </div>
            <div>
              {summaryLoading ? (
                <Skeleton className="mb-1 h-7 w-16" />
              ) : (
                <div className="text-[26px] font-bold leading-none tabular-nums text-content">
                  {summary ? `${(summary.taxaFalta * 100).toFixed(0)}%` : "—"}
                </div>
              )}
              <div className="mt-1 text-sm text-content-soft">Taxa de falta</div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="flex items-center gap-4 py-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-success/10 text-success">
              <ShieldCheck className="h-5 w-5" />
            </div>
            <div>
              {summaryLoading ? (
                <Skeleton className="mb-1 h-7 w-16" />
              ) : (
                <div className="text-[26px] font-bold leading-none tabular-nums text-content">
                  {summary?.confirmadosCatraca ?? 0}
                </div>
              )}
              <div className="mt-1 text-sm text-content-soft">Confirmados pela catraca</div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Data table */}
      <Card className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={8} />
        ) : (
          <Table>
            <THead>
              <TR>
                <TH>Data</TH>
                <TH>Aluno</TH>
                <TH>Tipo</TH>
                <TH>Horário</TH>
                <TH>Status</TH>
                <TH>Entrada/saída real</TH>
                <TH>Permanência</TH>
              </TR>
            </THead>
            <TBody>
              {rows.map((a: any) => (
                <TR key={a.id}>
                  <TD>{formatDate(a.date)}</TD>
                  <TD>
                    <div className="flex items-center gap-2.5">
                      <Avatar name={a.studentName} />
                      <span className="font-medium">{a.studentName}</span>
                    </div>
                  </TD>
                  <TD>
                    <Badge tone={a.studentType === "Militar" ? "warning" : "info"}>{a.studentType}</Badge>
                  </TD>
                  <TD className="font-semibold tabular-nums">{a.slotStart}</TD>
                  <TD><Badge tone={a.status}>{a.status}</Badge></TD>
                  <TD className="tabular-nums">
                    {a.entradaConfirmadaEm ? (
                      <span className="inline-flex items-center gap-1 text-success">
                        <ShieldCheck className="h-3.5 w-3.5" />
                        {horaLocal(a.entradaConfirmadaEm)}{a.saidaConfirmadaEm ? ` – ${horaLocal(a.saidaConfirmadaEm)}` : ""}
                      </span>
                    ) : (
                      <span className="text-content-faint">—</span>
                    )}
                  </TD>
                  <TD className="tabular-nums">
                    {a.permanenciaMinutos != null ? formatarPermanencia(a.permanenciaMinutos) : "—"}
                  </TD>
                </TR>
              ))}
              {rows.length === 0 && (
                <TR><TD colSpan={7} className="py-10 text-center text-content-soft">Sem registros no período.</TD></TR>
              )}
            </TBody>
          </Table>
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-line px-4 py-3 text-sm text-content-soft">
            <span>{fromRow}–{toRow} de {total}</span>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                <ChevronLeft className="h-4 w-4" /> Anterior
              </Button>
              <Button variant="outline" size="sm" disabled={page + 1 >= totalPages} onClick={() => setPage((p) => p + 1)}>
                Próxima <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </Card>
    </div>
  );
}