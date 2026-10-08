import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import Atestados, { textoPrazo } from "@/pages/Atestados";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { toast } from "@/lib/toast";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({ api: vi.fn(), downloadMedia: vi.fn() }));
vi.mock("@/lib/auth", () => ({ useAuth: vi.fn() }));
vi.mock("@/lib/toast", () => ({ toast: vi.fn() }));
const apiMock = vi.mocked(api);
const useAuthMock = vi.mocked(useAuth);

function mockAuth(roles: string[]) {
  useAuthMock.mockReturnValue({
    user: { id: "u", samAccountName: "", nome: "Admin", email: "a@x", roles },
    loading: false,
    signIn: vi.fn(),
    signOut: vi.fn(),
    hasRole: (...want: string[]) => want.some((r) => roles.includes(r)),
  });
}

const PENDENTE = {
  id: "e1", studentId: "s1", studentName: "Ana Souza", cpf: "123.456.789-09", phone: "62999990000",
  departmentName: "SGG", enviadoEm: "2026-10-08T10:00:00-03:00", emissaoData: "2026-10-01",
  medicoNome: "Dra. Lia", medicoCrm: "1234", medicoCrmUf: "GO", arquivoId: "m1",
  vencimentoAtual: "2026-10-05", diasRestantesAtual: -3, bloqueado: true,
};
const VENCENDO = [{ studentId: "s2", studentName: "Beto Lima", cpf: "456.***.***-11", vencimento: "2026-10-20", diasRestantes: 12, base: "CADASTRO", bloqueado: false, envioEmAnalise: true }];

function setupApi() {
  const posts: { path: string; body: any }[] = [];
  apiMock.mockImplementation(async (path: string, opts?: any) => {
    if (opts?.method === "POST") { posts.push({ path, body: opts.body ? JSON.parse(opts.body) : null }); return {}; }
    if (path === "/admin/atestados/resumo") return { vencendo: 1, bloqueados: 2, pendentes: 1 };
    if (path === "/admin/atestados/pendentes") return [PENDENTE];
    if (path.startsWith("/admin/atestados/alunos?lista=vencendo")) return VENCENDO;
    if (path.startsWith("/admin/atestados/alunos?lista=bloqueados")) return [];
    return undefined;
  });
  return posts;
}

afterEach(() => { apiMock.mockReset(); useAuthMock.mockReset(); vi.mocked(toast).mockReset(); });

describe("textoPrazo", () => {
  it("descreve o prazo em palavras", () => {
    expect(textoPrazo(0)).toBe("vence hoje");
    expect(textoPrazo(1)).toBe("vence amanhã");
    expect(textoPrazo(12)).toBe("vence em 12 dias");
    expect(textoPrazo(-1)).toBe("vencido há 1 dia");
    expect(textoPrazo(-5)).toBe("vencido há 5 dias");
  });
});

describe("Atestados - admin", () => {
  it("mostra a fila com os contadores nas abas e aprova", async () => {
    mockAuth(["admin"]);
    const posts = setupApi();
    renderWithProviders(<Atestados />, { route: "/atestados" });
    expect(await screen.findByText("Ana Souza")).toBeInTheDocument();
    expect(await screen.findByRole("tab", { name: /Aguardando validação \(1\)/ })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /Bloqueados \(2\)/ })).toBeInTheDocument();
    expect(screen.getByText("acesso bloqueado")).toBeInTheDocument();
    expect(screen.getByText("Dra. Lia (CRM 1234/GO)")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Aprovar" }));
    await waitFor(() => expect(posts).toEqual([{ path: "/admin/atestados/e1/aprovar", body: null }]));
  });

  it("recusar exige motivo e envia o texto", async () => {
    mockAuth(["gerente"]);
    const posts = setupApi();
    renderWithProviders(<Atestados />, { route: "/atestados" });
    fireEvent.click(await screen.findByRole("button", { name: "Recusar" }));
    const d = screen.getByRole("dialog");
    fireEvent.click(within(d).getByRole("button", { name: "Confirmar recusa" }));
    expect(await within(d).findByText("Informe o motivo da recusa.")).toBeInTheDocument();
    expect(posts).toHaveLength(0);

    fireEvent.change(within(d).getByLabelText("Motivo da recusa"), { target: { value: "PDF ilegível" } });
    fireEvent.click(within(d).getByRole("button", { name: "Confirmar recusa" }));
    await waitFor(() => expect(posts).toEqual([{ path: "/admin/atestados/e1/recusar", body: { motivo: "PDF ilegível" } }]));
  });

  it("aba vencendo lista prazo, base e envio em análise", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Atestados />, { route: "/atestados?aba=vencendo" });
    expect(await screen.findByText("Beto Lima")).toBeInTheDocument();
    expect(screen.getByText("vence em 12 dias")).toBeInTheDocument();
    expect(screen.getByText("pela data de cadastro")).toBeInTheDocument();
    expect(screen.getByText("em análise")).toBeInTheDocument();
  });

  it("recepção vê só as listas, sem a fila de validação", async () => {
    mockAuth(["recepcao"]);
    setupApi();
    renderWithProviders(<Atestados />, { route: "/atestados" });
    expect(await screen.findByText("Beto Lima")).toBeInTheDocument();
    expect(screen.queryByRole("tab", { name: /Aguardando validação/ })).not.toBeInTheDocument();
    expect(apiMock.mock.calls.some(([p]) => p === "/admin/atestados/pendentes")).toBe(false);
  });
});
