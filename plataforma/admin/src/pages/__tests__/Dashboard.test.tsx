import { afterEach, describe, expect, it, vi } from "vitest";
import { screen, waitFor, within } from "@testing-library/react";
import Dashboard from "@/pages/Dashboard";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({
  api: vi.fn(),
}));
vi.mock("@/lib/auth", () => ({
  useAuth: vi.fn(),
}));

const apiMock = vi.mocked(api);
const useAuthMock = vi.mocked(useAuth);

function mockAuth(roles: string[], nome = "Fulano de Tal") {
  useAuthMock.mockReturnValue({
    user: { id: "1", samAccountName: "fulano", nome, email: "fulano@x.com", roles },
    loading: false,
    signIn: vi.fn(),
    signOut: vi.fn(),
    hasRole: (...want: string[]) => want.some((r) => roles.includes(r)),
  });
}

const APPTS_TODAY = [
  { id: "a1", slotStart: "07:00", studentName: "Ana Souza", studentType: "Civil", status: "confirmado" },
  { id: "a2", slotStart: "06:00", studentName: "Beto Lima", studentType: "Militar", status: "agendado" },
  { id: "a3", slotStart: "08:00", studentName: "Cida Reis", studentType: "Civil", status: "cancelado" },
  { id: "a4", slotStart: "09:00", studentName: "Davi Melo", studentType: "Militar", status: "faltou" },
];

const SCHEDULE_TODAY = [
  { slotStart: "06:00", civilCount: 3, militarCount: 1, maxCapacity: 10, blocked: false },
  { slotStart: "07:00", civilCount: 10, militarCount: 0, maxCapacity: 10, blocked: false },
];

/** Configura o mock de `api` pra responder por prefixo de path, como o app real faria. */
function setupApi(overrides: Record<string, unknown> = {}) {
  const responses: Record<string, unknown> = {
    "/students": { totalElements: 42, content: [] },
    // Mesmo formato do backend real: GET /appointments é paginado.
    "/appointments": { content: APPTS_TODAY, totalElements: APPTS_TODAY.length },
    "/schedule": SCHEDULE_TODAY,
    "/checkins": [{ id: "c1" }, { id: "c2" }, { id: "c3" }],
    "/notices/active": [],
    ...overrides,
  };
  apiMock.mockImplementation((path: string) => {
    const key = Object.keys(responses).find((k) => path.startsWith(k));
    return Promise.resolve(key ? responses[key] : undefined);
  });
}

afterEach(() => {
  vi.clearAllMocks();
});

/** Acha o valor numérico exibido no StatCard a partir do texto do label
 *  (o value fica no primeiro filho do wrapper que também contém o label). */
function statValue(label: string) {
  const labelEl = screen.getByText(label);
  return labelEl.parentElement!.firstElementChild as HTMLElement;
}

describe("Dashboard", () => {
  it("renderiza os KPIs corretamente com dados mockados", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Dashboard />);

    // Alunos cadastrados vem de students.totalElements
    await waitFor(() => expect(statValue("Alunos cadastrados").textContent).toBe("42"));

    // Agendamentos hoje conta os não-cancelados (4 totais - 1 cancelado = 3)
    expect(statValue("Agendamentos hoje").textContent).toBe("3");

    // Check-ins hoje vem do length da lista de checkins
    expect(statValue("Check-ins hoje").textContent).toBe("3");

    // Faltas hoje conta status === "faltou" (1 aluno: Davi Melo)
    expect(statValue("Faltas hoje").textContent).toBe("1");
  });

  it("mostra só os links de Acesso rápido que o papel do usuário logado permite", async () => {
    // Papel "professor": Alunos, Agenda, Check-in, Fichas de Treino — mas não Avisos/Relatórios (admin/gerente)
    mockAuth(["professor"]);
    setupApi();
    renderWithProviders(<Dashboard />);

    await waitFor(() => expect(apiMock).toHaveBeenCalled());

    expect(screen.getByRole("link", { name: /Alunos/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Agenda/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Check-in/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Fichas de Treino/ })).toBeInTheDocument();

    expect(screen.queryByRole("link", { name: /Avisos/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /Relatórios/ })).not.toBeInTheDocument();
  });

  it("mostra o grid completo de Acesso rápido para o papel admin", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Dashboard />);

    await waitFor(() => expect(apiMock).toHaveBeenCalled());

    for (const label of ["Alunos", "Agenda", "Check-in", "Fichas de Treino", "Avisos", "Relatórios"]) {
      expect(screen.getByRole("link", { name: new RegExp(label) })).toBeInTheDocument();
    }
  });

  it("mostra o skeleton de carregamento antes dos dados chegarem", () => {
    mockAuth(["admin"]);
    // Promise que nunca resolve — mantém as queries em estado de loading.
    apiMock.mockImplementation(() => new Promise(() => {}));
    const { container } = renderWithProviders(<Dashboard />);

    expect(container.querySelectorAll(".animate-pulse").length).toBeGreaterThan(0);
    // Os valores dos KPIs ainda não devem estar na tela.
    expect(screen.queryByText("42")).not.toBeInTheDocument();
  });

  it("renderiza a tabela de Agendamentos de hoje com os dados mockados", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Dashboard />);

    const table = await screen.findByRole("table");
    // Cancelado é filtrado da lista exibida.
    await waitFor(() => expect(within(table).queryByText("Cida Reis")).not.toBeInTheDocument());

    expect(within(table).getByText("Ana Souza")).toBeInTheDocument();
    expect(within(table).getByText("Beto Lima")).toBeInTheDocument();
    expect(within(table).getByText("Davi Melo")).toBeInTheDocument();

    // Ordenado por horário: 06:00 (Beto) antes de 07:00 (Ana) antes de 09:00 (Davi).
    const rows = within(table).getAllByRole("row").slice(1); // primeira linha é o cabeçalho
    expect(rows[0]).toHaveTextContent("Beto Lima");
    expect(rows[1]).toHaveTextContent("Ana Souza");
    expect(rows[2]).toHaveTextContent("Davi Melo");
  });

  it("mostra mensagem de vazio quando não há agendamentos hoje", async () => {
    mockAuth(["admin"]);
    setupApi({ "/appointments": { content: [], totalElements: 0 } });
    renderWithProviders(<Dashboard />);

    expect(await screen.findByText("Nenhum agendamento para hoje.")).toBeInTheDocument();
  });
});
