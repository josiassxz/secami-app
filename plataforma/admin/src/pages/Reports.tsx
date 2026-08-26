import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn, formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Avatar, Badge, Card, CardContent, Input, Skeleton, Table, TableSkeleton, TBody, TD, TH, THead, TR } from "@/components/ui";
import { CalendarClock, CheckCircle2, XCircle, Ban } from "lucide-react";

function ago(days: number) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().slice(0, 10);
}

const STATUS_META: Record<string, { label: string; icon: any; iconClass: string }> = {
  agendado: { label: "Agendado", icon: CalendarClock, iconClass: "bg-info/10 text-info" },
  confirmado: { label: "Confirmado", icon: CheckCircle2, iconClass: "bg-success/10 text-success" },
  faltou: { label: "Faltou", icon: XCircle, iconClass: "bg-danger/10 text-danger" },
  cancelado: { label: "Cancelado", icon: Ban, iconClass: "bg-surface-alt text-content-soft" },
};

export default function Reports() {
  const [from, setFrom] = useState(ago(30));
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));

  const { data, isLoading } = useQuery({
    queryKey: ["report-appts", from, to],
    queryFn: () => api(`/appointments?from=${from}&to=${to}`),
  });

  const rows = data || [];
  const counts = rows.reduce((acc: any, a: any) => {
    acc[a.status] = (acc[a.status] || 0) + 1;
    return acc;
  }, {});

  return (
    <div>
      <PageHeader title="Relatórios" subtitle="Frequência e agendamentos"
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Input type="date" className="w-auto" aria-label="Data inicial" value={from} onChange={(e) => setFrom(e.target.value)} />
            <span className="text-sm text-content-soft">até</span>
            <Input type="date" className="w-auto" aria-label="Data final" value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
        } />

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {(["agendado", "confirmado", "faltou", "cancelado"] as const).map((s) => {
          const meta = STATUS_META[s];
          const Icon = meta.icon;
          return (
            <Card key={s}>
              <CardContent className="flex items-center gap-4 py-5">
                <div className={cn("flex h-12 w-12 items-center justify-center rounded-lg", meta.iconClass)}>
                  <Icon className="h-5 w-5" />
                </div>
                <div>
                  {isLoading ? (
                    <Skeleton className="mb-1 h-7 w-12" />
                  ) : (
                    <div className="text-[26px] font-bold leading-none tabular-nums text-content">{counts[s] || 0}</div>
                  )}
                  <div className="mt-1 text-sm text-content-soft">{meta.label}</div>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={8} />
        ) : (
          <Table>
            <THead><TR><TH>Data</TH><TH>Aluno</TH><TH>Tipo</TH><TH>Horário</TH><TH>Status</TH></TR></THead>
            <TBody>
              {rows.slice(0, 300).map((a: any) => (
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
                </TR>
              ))}
              {rows.length === 0 && <TR><TD colSpan={5} className="py-10 text-center text-content-soft">Sem registros no período.</TD></TR>}
            </TBody>
          </Table>
        )}
        {rows.length > 300 && <p className="p-3 text-center text-xs text-content-faint">Mostrando 300 de {rows.length} registros.</p>}
      </Card>
    </div>
  );
}
