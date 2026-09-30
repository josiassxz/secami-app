import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { PageHeader } from "@/components/PageHeader";
import {
  Avatar,
  Badge,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Meter,
  QuickLinkCard,
  Skeleton,
  Table,
  TBody,
  TD,
  TH,
  THead,
  TR,
} from "@/components/ui";
import {
  Users,
  CalendarDays,
  CheckSquare,
  AlertTriangle,
  ClipboardList,
  Megaphone,
  BarChart3,
  Activity,
} from "lucide-react";

const QUICK_LINKS = [
  { to: "/alunos", label: "Alunos", icon: Users, roles: ["admin", "gerente", "recepcao", "professor"] },
  { to: "/agenda", label: "Agenda", icon: CalendarDays, roles: ["admin", "gerente", "recepcao", "professor"] },
  { to: "/checkin", label: "Check-in", icon: CheckSquare, roles: ["admin", "recepcao", "professor"] },
  { to: "/fichas", label: "Fichas de Treino", icon: ClipboardList, roles: ["admin", "professor"] },
  { to: "/avisos", label: "Avisos", icon: Megaphone, roles: ["admin", "gerente"] },
  { to: "/relatorios", label: "Relatórios", icon: BarChart3, roles: ["admin", "gerente"] },
];

const today = () => new Date().toISOString().slice(0, 10);

/** Rótulo pequeno de seção (Label/Caption — design-system.md §3), separa os blocos
 *  da tela sem precisar de linha divisória (§1.2: espaço em vez de borda). */
function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-content-soft">
      {children}
    </h2>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
  loading,
  accent,
}: {
  icon: any;
  label: string;
  value: React.ReactNode;
  loading?: boolean;
  accent?: "gold" | "danger";
}) {
  const iconClass =
    accent === "gold"
      ? "bg-gold-container text-gold-fg"
      : accent === "danger"
      ? "bg-danger/10 text-danger"
      : "bg-brand-container text-brand";
  return (
    <Card>
      <CardContent className="flex items-center gap-4 py-5">
        <div className={`flex h-12 w-12 items-center justify-center rounded-lg ${iconClass}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div>
          {loading ? (
            <Skeleton className="mb-1 h-7 w-16" />
          ) : (
            <div className="text-2xl font-bold leading-none tabular-nums text-content">{value}</div>
          )}
          <div className="mt-1 text-sm text-content-soft">{label}</div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function Dashboard() {
  const { hasRole, user } = useAuth();
  const staff = hasRole("admin", "gerente", "recepcao", "professor");
  const d = today();

  const students = useQuery({
    queryKey: ["students-count"],
    queryFn: () => api(`/students?size=1&perfil=aluno`),
    enabled: staff,
  });
  const appts = useQuery({
    queryKey: ["appts-today", d],
    // GET /appointments é paginado (Page do Spring): os itens vêm em
    // `content`. size=200 (máximo aceito pelo backend) cobre um dia inteiro.
    queryFn: () => api(`/appointments?from=${d}&to=${d}&size=200`),
    enabled: staff,
  });
  const schedule = useQuery({
    queryKey: ["schedule-today", d],
    queryFn: () => api(`/schedule?date=${d}`),
    enabled: staff,
  });
  const checkins = useQuery({
    queryKey: ["checkins-today", d],
    queryFn: () => api(`/checkins?date=${d}`),
    enabled: hasRole("admin", "recepcao", "professor"),
  });
  const notices = useQuery({ queryKey: ["notices-active"], queryFn: () => api(`/notices/active`) });

  const apptsHoje: any[] = appts.data?.content ?? [];
  const apptList = apptsHoje.filter((a: any) => a.status !== "cancelado");
  const faltas = apptsHoje.filter((a: any) => a.status === "faltou").length;
  const slots = (schedule.data || []).filter((s: any) => !s.blocked);
  const noticeList = notices.data || [];

  return (
    <div>
      <PageHeader
        title={`Olá, ${(user?.nome?.split(" ")[0] || "").toUpperCase()}`}
        subtitle="Visão geral da academia"
      />

      {/* Acesso rápido — elemento de navegação primário da tela, por isso vem em
          destaque (cor lima saturada) logo abaixo da saudação. */}
      <section>
        <SectionLabel>Acesso rápido</SectionLabel>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-6">
          {QUICK_LINKS.filter((l) => hasRole(...l.roles)).map((l) => (
            <QuickLinkCard key={l.to} to={l.to} label={l.label} icon={l.icon} />
          ))}
        </div>
      </section>

      {/* Resumo de hoje — informativo, não navegação: cartões neutros (superfície
          branca) pra não competir visualmente com o grid lima acima. */}
      <section className="mt-8">
        <SectionLabel>Resumo de hoje</SectionLabel>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard icon={Users} label="Alunos cadastrados" loading={students.isLoading} value={students.data?.totalElements ?? "—"} />
          <StatCard icon={CalendarDays} label="Agendamentos hoje" loading={appts.isLoading} value={apptList.length} />
          <StatCard icon={CheckSquare} label="Check-ins hoje" accent="gold" loading={checkins.isLoading} value={checkins.data?.length ?? "—"} />
          <StatCard icon={AlertTriangle} label="Faltas hoje" accent="danger" loading={appts.isLoading} value={faltas} />
        </div>
      </section>

      <div className="mt-8 grid gap-6 xl:grid-cols-3">
        {/* Ocupação por horário */}
        <Card className="xl:col-span-1">
          <CardHeader className="flex items-center gap-2">
            <Activity className="h-4 w-4 text-content-soft" />
            <CardTitle>Ocupação por horário</CardTitle>
          </CardHeader>
          <CardContent>
            {schedule.isLoading ? (
              <div className="space-y-3">
                {Array.from({ length: 6 }).map((_, i) => (
                  <Skeleton key={i} className="h-6" />
                ))}
              </div>
            ) : slots.length === 0 ? (
              <p className="py-6 text-center text-sm text-content-soft">Nenhum horário configurado.</p>
            ) : (
              <div className="space-y-3">
                {slots.map((s: any) => {
                  const total = s.civilCount + s.militarCount;
                  const lotado = s.civilCount >= s.maxCapacity;
                  return (
                    <div key={s.slotStart} className="flex items-center gap-3">
                      <span className="w-11 shrink-0 text-sm font-semibold tabular-nums text-content">
                        {s.slotStart}
                      </span>
                      <div className="flex-1">
                        <Meter
                          value={s.civilCount}
                          max={s.maxCapacity}
                          tone={lotado ? "danger" : s.civilCount / s.maxCapacity > 0.75 ? "warning" : "brand"}
                        />
                      </div>
                      <span className="w-16 shrink-0 text-right text-xs tabular-nums text-content-soft">
                        {total > 0 ? `${s.civilCount}/${s.maxCapacity}` : "—"}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Agendamentos de hoje */}
        <Card className="xl:col-span-2">
          <CardHeader className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CalendarDays className="h-4 w-4 text-content-soft" />
              <CardTitle>Agendamentos de hoje</CardTitle>
            </div>
            {!appts.isLoading && apptList.length > 0 && <Badge tone="neutral">{apptList.length}</Badge>}
          </CardHeader>
          <CardContent>
            {appts.isLoading ? (
              <div className="space-y-2">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-9" />
                ))}
              </div>
            ) : apptList.length === 0 ? (
              <p className="py-8 text-center text-sm text-content-soft">Nenhum agendamento para hoje.</p>
            ) : (
              <Table>
                <THead>
                  <TR>
                    <TH>Horário</TH>
                    <TH>Aluno</TH>
                    <TH>Tipo</TH>
                    <TH>Status</TH>
                  </TR>
                </THead>
                <TBody>
                  {apptList
                    .slice()
                    .sort((a: any, b: any) => a.slotStart.localeCompare(b.slotStart))
                    .slice(0, 12)
                    .map((a: any) => (
                      <TR key={a.id}>
                        <TD className="font-semibold tabular-nums">{a.slotStart}</TD>
                        <TD>
                          <div className="flex items-center gap-2.5">
                            <Avatar name={a.studentName} />
                            <span className="font-medium">{a.studentName}</span>
                          </div>
                        </TD>
                        <TD className="text-content-soft">{a.studentType}</TD>
                        <TD>
                          <Badge tone={a.status}>{a.status}</Badge>
                        </TD>
                      </TR>
                    ))}
                </TBody>
              </Table>
            )}
            {apptList.length > 12 && (
              <p className="pt-3 text-center text-xs text-content-faint">
                Mostrando 12 de {apptList.length} — veja todos na Agenda.
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Avisos */}
      {noticeList.length > 0 && (
        <Card className="mt-8">
          <CardHeader className="flex items-center gap-2">
            <Megaphone className="h-4 w-4 text-content-soft" />
            <CardTitle>Avisos</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid gap-3 md:grid-cols-2">
              {noticeList.map((n: any) => (
                <div key={n.id} className="rounded-md border border-line bg-surface-alt/40 p-4">
                  <div className="mb-1 flex items-center gap-2">
                    <Badge tone={n.type}>{n.type}</Badge>
                    <span className="font-semibold text-content">{n.title}</span>
                  </div>
                  <p className="whitespace-pre-line text-sm leading-relaxed text-content-soft">{n.content}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
