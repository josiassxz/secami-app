import { Outlet, Link, useLocation } from 'react-router-dom';
import { useAuth } from '@/lib/AuthContext';
import { base44 } from '@/api/base44Client';
import { useState } from 'react';
import {
  LayoutDashboard, Users, Calendar, Dumbbell, ClipboardList,
  LogOut, Menu, X, Settings, UserCheck, ChevronRight, Activity, Bell, CalendarOff, Building2
} from 'lucide-react';
import { cn } from '@/lib/utils';

const navItems = {
  admin: [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/students', icon: Users, label: 'Alunos' },
    { path: '/checkin', icon: UserCheck, label: 'Check-in' },
    { path: '/schedule', icon: Calendar, label: 'Agenda' },
    { path: '/exercises', icon: Dumbbell, label: 'Exercícios' },
    { path: '/workout-plans', icon: ClipboardList, label: 'Fichas' },
    { path: '/slot-config', icon: Settings, label: 'Config. Horários' },
    { path: '/notices', icon: Bell, label: 'Informativos' },
    { path: '/blocked-dates', icon: CalendarOff, label: 'Datas Bloqueadas' },
    { path: '/departments', icon: Building2, label: 'Secretarias' },
    { path: '/reports', icon: Activity, label: 'Relatórios' },
  ],
  gerente: [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/students', icon: Users, label: 'Alunos' },
    { path: '/schedule', icon: Calendar, label: 'Agenda' },
    { path: '/slot-config', icon: Settings, label: 'Config. Horários' },
    { path: '/notices', icon: Bell, label: 'Informativos' },
    { path: '/blocked-dates', icon: CalendarOff, label: 'Datas Bloqueadas' },
    { path: '/departments', icon: Building2, label: 'Secretarias' },
    { path: '/reports', icon: Activity, label: 'Relatórios' },
  ],
  recepcao: [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/students', icon: Users, label: 'Alunos' },
    { path: '/checkin', icon: UserCheck, label: 'Check-in' },
    { path: '/schedule', icon: Calendar, label: 'Agenda' },
  ],
  professor: [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/checkin', icon: UserCheck, label: 'Check-in' },
    { path: '/schedule', icon: Calendar, label: 'Agenda' },
    { path: '/exercises', icon: Dumbbell, label: 'Exercícios' },
    { path: '/workout-plans', icon: ClipboardList, label: 'Fichas de Treino' },
    { path: '/students', icon: Users, label: 'Alunos' },
  ],
  aluno: [
    { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/my-workout', icon: Dumbbell, label: 'Meu Treino' },
    { path: '/my-schedule', icon: Calendar, label: 'Minha Agenda' },
    { path: '/schedule', icon: Calendar, label: 'Agenda' },
    { path: '/exercises', icon: Dumbbell, label: 'Exercícios' },
    { path: '/my-history', icon: Activity, label: 'Meu Histórico' },

    { path: '/my-profile', icon: Users, label: 'Meu Perfil' },
  ],
};

export default function Layout() {
  const { user } = useAuth();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const role = user?.role || 'aluno';
  const roleLabel = { user: 'Usuário', admin: 'Admin', gerente: 'Gerente', recepcao: 'Recepção', professor: 'Professor', aluno: 'Aluno' }[role] || role;
  const items = navItems[role] || navItems['aluno'];

  const handleLogout = () => base44.auth.logout();

  return (
    <div className="min-h-screen bg-background flex font-inter">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-30 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={cn(
        "fixed top-0 left-0 h-full w-64 bg-sidebar z-40 flex flex-col transition-transform duration-300 border-r border-sidebar-border",
        sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
      )}>
        {/* Logo */}
        <div className="flex items-center gap-3 px-4 py-4 border-b border-sidebar-border">
          <img
            src="https://media.base44.com/images/public/69c292e80a168be0a1fb9df3/c56ee6484_Logo_secami.jpg"
            alt="Logo"
            className="w-10 h-10 rounded-full object-contain flex-shrink-0"
          />
          <span className="font-bold text-sm text-foreground leading-tight">Academia Secami</span>
          <button onClick={() => setSidebarOpen(false)} className="ml-auto lg:hidden text-muted-foreground">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* User info */}
        <div className="px-6 py-4 border-b border-sidebar-border">
          <p className="text-sm font-medium text-foreground truncate">{user?.full_name || user?.email}</p>
          <p className="text-xs text-muted-foreground capitalize">{roleLabel}</p>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          {items.map(({ path, icon: Icon, label }, idx) => {
            const active = location.pathname === path;
            return (
              <Link
                key={`${path}-${idx}`}
                to={path}
                onClick={() => setSidebarOpen(false)}
                className={cn(
                  "flex items-center gap-3 px-4 py-4 rounded-lg text-base font-medium transition-all group",
                  active
                    ? "bg-primary text-primary-foreground"
                    : "text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
                )}
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                <span className="flex-1">{label}</span>
                {active && <ChevronRight className="w-3 h-3" />}
              </Link>
            );
          })}
        </nav>

        {/* Logout */}
        <div className="px-3 py-4 border-t border-sidebar-border">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-all w-full"
          >
            <LogOut className="w-4 h-4" />
            Sair
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 lg:ml-64 flex flex-col min-h-screen">
        {/* Top bar (mobile) */}
        <header className="sticky top-0 z-20 bg-background/80 backdrop-blur border-b border-border px-4 py-3 flex items-center gap-3 lg:hidden">
          <button onClick={() => setSidebarOpen(true)} className="text-muted-foreground p-3 -ml-3 rounded-lg hover:bg-muted/30">
            <Menu className="w-7 h-7" />
          </button>
          <button onClick={() => setSidebarOpen(true)} className="flex items-center gap-2 hover:opacity-80 transition-opacity">
            <img
              src="https://media.base44.com/images/public/69c292e80a168be0a1fb9df3/c56ee6484_Logo_secami.jpg"
              alt="Logo"
              className="w-8 h-8 rounded-full object-contain"
            />
            <span className="font-bold text-foreground text-sm">Academia Secami</span>
          </button>
        </header>

        <main className="flex-1 p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}