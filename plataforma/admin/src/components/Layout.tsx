import { useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@/lib/auth";
import { api, type PendingRegistration } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Avatar } from "@/components/ui";
import {
  LayoutDashboard,
  Users,
  UserCheck,
  CalendarDays,
  CheckSquare,
  Dumbbell,
  ClipboardList,
  UserCog,
  Clock,
  CalendarOff,
  Building2,
  Megaphone,
  BarChart3,
  LogOut,
  Sun,
  Moon,
} from "lucide-react";

/** Contagem de cadastros pendentes de aprovação, pro badge no menu.
 *  Mesma queryKey usada pela tela de Cadastros Pendentes: aprovar/recusar por
 *  lá invalida essa query e o badge atualiza sozinho. Refetch periódico cobre
 *  o caso de outro admin aprovar/recusar em outra sessão. */
function usePendingRegistrationsCount(enabled: boolean) {
  const { data } = useQuery({
    queryKey: ["pending-registrations"],
    queryFn: () => api<PendingRegistration[]>("/admin/cadastros/pendentes"),
    enabled,
    refetchInterval: 60_000,
  });
  return data?.length ?? 0;
}

type NavItem = { to: string; label: string; icon: any; roles: string[] };
type NavGroup = { title: string; items: NavItem[] };

const GROUPS: NavGroup[] = [
  {
    title: "Visão geral",
    items: [
      { to: "/", label: "Painel", icon: LayoutDashboard, roles: ["admin", "gerente", "recepcao", "professor"] },
      { to: "/relatorios", label: "Relatórios", icon: BarChart3, roles: ["admin", "gerente"] },
    ],
  },
  {
    title: "Academia",
    items: [
      { to: "/alunos", label: "Alunos", icon: Users, roles: ["admin", "gerente", "recepcao", "professor"] },
      { to: "/cadastros-pendentes", label: "Cadastros Pendentes", icon: UserCheck, roles: ["admin", "gerente"] },
      { to: "/agenda", label: "Agenda", icon: CalendarDays, roles: ["admin", "gerente", "recepcao", "professor"] },
      { to: "/checkin", label: "Check-in", icon: CheckSquare, roles: ["admin", "recepcao", "professor"] },
    ],
  },
  {
    title: "Treino",
    items: [
      { to: "/exercicios", label: "Exercícios", icon: Dumbbell, roles: ["admin", "professor"] },
      { to: "/fichas", label: "Fichas de Treino", icon: ClipboardList, roles: ["admin", "professor"] },
      { to: "/coaching", label: "Coaching", icon: UserCog, roles: ["admin", "professor"] },
    ],
  },
  {
    title: "Configuração",
    items: [
      { to: "/horarios", label: "Config. Horários", icon: Clock, roles: ["admin", "gerente"] },
      { to: "/datas-bloqueadas", label: "Datas Bloqueadas", icon: CalendarOff, roles: ["admin", "gerente"] },
      { to: "/secretarias", label: "Secretarias", icon: Building2, roles: ["admin", "gerente"] },
      { to: "/avisos", label: "Avisos", icon: Megaphone, roles: ["admin", "gerente"] },
    ],
  },
];

function useTheme() {
  const [dark, setDark] = useState(
    () => localStorage.getItem("secami.theme") === "dark"
  );
  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
    localStorage.setItem("secami.theme", dark ? "dark" : "light");
  }, [dark]);
  return { dark, toggle: () => setDark((d) => !d) };
}

export default function Layout() {
  const { user, signOut, hasRole } = useAuth();
  const navigate = useNavigate();
  const { dark, toggle } = useTheme();
  const pendingCount = usePendingRegistrationsCount(hasRole("admin", "gerente"));

  const hoje = new Date().toLocaleDateString("pt-BR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });

  return (
    <div className="flex min-h-screen">
      {/* ===== Sidebar ===== */}
      <aside className="sticky top-0 flex h-screen w-60 shrink-0 flex-col border-r border-line bg-surface">
        <div className="flex items-center gap-2.5 px-5 pb-4 pt-5">
          <img
            src="/logo-casa-militar.png"
            alt="Casa Militar de Goiás"
            className="h-9 w-9 shrink-0 object-contain"
          />
          <div>
            <div className="text-sm font-bold leading-tight text-content">SECAMI</div>
            <div className="text-[11px] text-content-soft">Casa Militar · Goiás</div>
          </div>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 pb-4">
          {GROUPS.map((g) => {
            const items = g.items.filter((i) => hasRole(...i.roles));
            if (items.length === 0) return null;
            return (
              <div key={g.title} className="mb-4">
                <div className="px-3 pb-1.5 pt-2 text-[10px] font-bold uppercase tracking-[.12em] text-content-faint">
                  {g.title}
                </div>
                <div className="space-y-0.5">
                  {items.map((item) => (
                    <NavLink
                      key={item.to}
                      to={item.to}
                      end={item.to === "/"}
                      className={({ isActive }) =>
                        cn(
                          "group flex items-center gap-3 rounded-md px-3 py-2 text-[13px] font-medium transition-colors",
                          isActive
                            ? "bg-brand-container font-semibold text-brand"
                            : "text-content-soft hover:bg-surface-alt hover:text-content"
                        )
                      }
                    >
                      <item.icon className="h-4 w-4 shrink-0" />
                      <span className="flex-1">{item.label}</span>
                      {item.to === "/cadastros-pendentes" && pendingCount > 0 && (
                        <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-gold px-1.5 text-[11px] font-bold text-gold-fg">
                          {pendingCount}
                        </span>
                      )}
                    </NavLink>
                  ))}
                </div>
              </div>
            );
          })}
        </nav>

        <div className="border-t border-line p-3">
          <div className="flex items-center gap-2.5 rounded-md px-2 py-1.5">
            <Avatar name={user?.nome || "?"} />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-semibold text-content">{user?.nome}</div>
              <div className="truncate text-[11px] capitalize text-content-soft">
                {user?.roles.join(" · ")}
              </div>
            </div>
            <button
              title="Sair"
              onClick={() => {
                signOut();
                navigate("/login");
              }}
              className="rounded-md p-2 text-content-soft transition-colors hover:bg-surface-alt hover:text-danger"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* ===== Main ===== */}
      <div className="flex min-w-0 flex-1 flex-col bg-base">
        {/* Topbar */}
        <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-line bg-base/85 px-6 backdrop-blur">
          <span className="text-sm capitalize text-content-soft">{hoje}</span>
          <div className="flex items-center gap-2">
            <button
              title={dark ? "Tema claro" : "Tema escuro"}
              onClick={toggle}
              className="flex h-9 w-9 items-center justify-center rounded-md border border-line bg-surface text-content-soft transition-colors hover:text-content"
            >
              {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </button>
          </div>
        </header>

        <main className="flex-1 px-6 py-6 lg:px-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
