import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Avatar, Badge, Card, Input, Meter, Skeleton } from "@/components/ui";
import { CalendarDays, CalendarX, CheckCircle2, Lock, ShieldAlert, XCircle } from "lucide-react";

const todayStr = () => new Date().toISOString().slice(0, 10);

const LEGEND = [
  { tone: "bg-success", label: "Disponível" },
  { tone: "bg-warning", label: "Restrito a militares" },
  { tone: "bg-danger", label: "Lotado ou bloqueado" },
];

export default function Schedule() {
  const [date, setDate] = useState(todayStr());
  const { data, isLoading } = useQuery({
    queryKey: ["schedule", date],
    queryFn: () => api(`/schedule?date=${date}`),
  });

  const slots: any[] = data || [];

  return (
    <div>
      <PageHeader
        title="Agenda"
        subtitle="Grade de horários por dia"
        actions={
          <div className="relative">
            <CalendarDays className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
            <Input
              type="date"
              className="w-auto pl-9"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </div>
        }
      />

      {!isLoading && slots.length > 0 && (
        <div className="mb-4 flex flex-wrap items-center gap-x-5 gap-y-1.5">
          {LEGEND.map((l) => (
            <span key={l.label} className="flex items-center gap-1.5 text-xs text-content-soft">
              <span className={cn("h-2 w-2 rounded-full", l.tone)} />
              {l.label}
            </span>
          ))}
        </div>
      )}

      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-36" />
          ))}
        </div>
      ) : slots.length === 0 ? (
        <Card className="flex flex-col items-center gap-2 px-4 py-16 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
            <CalendarX className="h-6 w-6" />
          </div>
          <p className="font-medium text-content">Nenhum horário configurado</p>
          <p className="max-w-xs text-sm text-content-soft">
            Não há grade de horários cadastrada para esta data.
          </p>
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {slots.map((s: any) => {
            const cheio = s.civilCount >= s.maxCapacity;
            const razao = s.maxCapacity > 0 ? s.civilCount / s.maxCapacity : 0;
            const indisponivel = s.blocked || cheio;

            return (
              <Card
                key={s.slotStart}
                className={cn(
                  "flex flex-col border-l-4 p-4",
                  s.blocked
                    ? "border-l-content-faint bg-surface-alt/40"
                    : cheio
                    ? "border-l-danger bg-danger/[.04]"
                    : s.civilRestricted
                    ? "border-l-warning bg-warning/[.04]"
                    : "border-l-success"
                )}
              >
                <div className="mb-3 flex items-center justify-between gap-2">
                  <span
                    className={cn(
                      "text-base font-bold tabular-nums",
                      indisponivel ? "text-content-soft" : "text-content"
                    )}
                  >
                    {s.slotStart}–{s.slotEnd}
                  </span>
                  {s.blocked ? (
                    <Badge tone="faltou">
                      <Lock className="mr-1 h-3 w-3" /> bloqueado
                    </Badge>
                  ) : s.civilRestricted ? (
                    <Badge tone="warning">
                      <ShieldAlert className="mr-1 h-3 w-3" /> só militares
                    </Badge>
                  ) : cheio ? (
                    <Badge tone="faltou">
                      <XCircle className="mr-1 h-3 w-3" /> cheio
                    </Badge>
                  ) : (
                    <Badge tone="success">
                      <CheckCircle2 className="mr-1 h-3 w-3" /> disponível
                    </Badge>
                  )}
                </div>

                <div className="mb-1.5">
                  <Meter
                    value={s.civilCount}
                    max={s.maxCapacity}
                    tone={cheio ? "danger" : razao > 0.75 ? "warning" : "brand"}
                  />
                </div>
                <div className="flex justify-between text-xs text-content-soft">
                  <span>
                    Civis <b className="tabular-nums text-content">{s.civilCount}/{s.maxCapacity}</b>
                  </span>
                  <span>
                    Militares <b className="tabular-nums text-content">{s.militarCount}</b>
                  </span>
                </div>

                {s.appointments?.length > 0 && (
                  <ul className="mt-3 max-h-44 space-y-1.5 overflow-y-auto border-t border-line pt-2.5 text-sm">
                    {s.appointments.map((a: any) => (
                      <li key={a.id} className="flex items-center justify-between gap-2">
                        <span className="flex min-w-0 items-center gap-2">
                          <Avatar name={a.studentName} className="h-6 w-6 text-[10px]" />
                          <span className="truncate text-content">{a.studentName}</span>
                        </span>
                        <Badge tone={a.status}>{a.status}</Badge>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
