import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import Punicoes, { type Punicao } from "@/pages/Punicoes";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { ApiError } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({ api: vi.fn() }));
vi.mock("@/lib/auth", () => ({ useAuth: vi.fn() }));
vi.mock("@/lib/toast", () => ({ toast: vi.fn() }));
const apiMock = vi.mocked(api);
const useAuthMock = vi.mocked(useAuth);
const toastMock = vi.mocked(toast);

function mockAuth(roles: string[]) {
  useAuthMock.mockReturnValue({
    user: { id: "1", samAccountName: "fulano", nome: "Fulano", email: "f@x.com", roles },
    loading: false,
    signIn: vi.fn(),
    signOut: vi.fn(),
    hasRole: (...want: string[]) => want.some((r) => roles.includes(r)),
  });
}

const ALUNOS = [
  { studentId: "a1", fullName: "Ana Lutadora", turmaLutas: "FEMININO", pendentes: 1, cumpridas: 1 },
  { studentId: "a2", fullName: "Beto Faixa", turmaLutas: "MASCULINO", pendentes: 0, cumpridas: 0 },
];

function punicao(over: Partial<Punicao>): Punicao {
  return {
    id: "p1", studentId: "a1", studentName: "Ana Lutadora",
    itens: [{ itemId: "i1", nome: "10 flexões" }], observacao: null, status: "PENDENTE",
    aplicadaEm: "2026-11-10T12:00:00Z", aplicadaPorNome: "Mestre", cumpridaEm: null, cumpridaPorNome: null,
    concluidaEm: null, ...over,
  };
}

const ABERTAS: Punicao[] = [
  punicao({ id: "p0", status: "CUMPRIDA", itens: [{ itemId: "i2", nome: "1 Coca-Cola" }], cumpridaEm: "2026-11-11T12:00:00Z" }),
  punicao({ id: "p1", itens: [{ itemId: "i1", nome: "10 flexões" }, { itemId: "i2", nome: "1 Coca-Cola" }], observacao: "Chegou atrasado" }),
];

const ITENS = [
  { id: "i1", nome: "10 flexões", ativo: true },
  { id: "i2", nome: "1 Coca-Cola", ativo: true },
  { id: "i3", nome: "Polichinelos", ativo: false },
];

type Opts = { cumprir?: () => Promise<unknown>; onDelete?: () => Promise<unknown> };

function setupApi({ cumprir, onDelete }: Opts = {}) {
  apiMock.mockImplementation(async (path: string, opts: any = {}) => {
    const method = opts?.method ?? "GET";
    if (path.startsWith("/punicoes/alunos?")) return ALUNOS;
    if (path === "/punicoes/alunos/a1") return ABERTAS;
    if (path === "/punicoes/alunos/a1/historico")
      return [punicao({ id: "pc", status: "CONCLUIDA", itens: [{ itemId: "i9", nome: "Burpees" }], concluidaEm: "2026-10-01T12:00:00Z" })];
    if (path === "/punicoes/itens" && method === "GET") return ITENS.filter((i) => i.ativo);
    if (path === "/punicoes/itens?todos=true") return ITENS;
    if (path === "/punicoes/itens" && method === "POST") return { id: "n1", ...JSON.parse(opts.body), ativo: true };
    if (path.startsWith("/punicoes/itens/") && method === "PUT") return { id: "x", ...JSON.parse(opts.body) };
    if (path === "/punicoes" && method === "POST") return punicao({ id: "novo" });
    if (path.endsWith("/cumprir")) return cumprir ? cumprir() : [];
    if (method === "DELETE") return onDelete ? onDelete() : undefined;
    if (path === "/admin/configuracoes/punicoes") return { porCiclo: 2, diasParaConcluir: 30 };
    return undefined;
  });
}

function callsTo(path: string, method?: string) {
  return apiMock.mock.calls.filter(([p, o]: any) => p === path && (method ? o?.method === method : true));
}

afterEach(() => {
  vi.clearAllMocks();
});

async function abrirAna() {
  fireEvent.click(await screen.findByRole("button", { name: /Ana Lutadora/ }));
  return await screen.findByText("10 flexões + 1 Coca-Cola");
}

describe("Punições - alunos", () => {
  it("lista os alunos de Lutas com turma e contagens", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    expect(await screen.findByText("Ana Lutadora")).toBeInTheDocument();
    expect(screen.getByText("Beto Faixa")).toBeInTheDocument();
    expect(screen.getByText("Feminino")).toBeInTheDocument();
    expect(screen.getByText("1 pendente · 1 cumprida")).toBeInTheDocument();
    expect(screen.getByText("0 pendentes · 0 cumpridas")).toBeInTheDocument();
  });

  it("instrutor de lutas vê o texto genérico da regra e não busca a configuração", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    expect(await screen.findByText(/a cada ciclo de punições cumpridas elas são encerradas/i)).toBeInTheDocument();
    expect(callsTo("/admin/configuracoes/punicoes")).toHaveLength(0);
  });

  it("admin vê a regra com os valores da configuração", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    expect(await screen.findByText(/A cada 2 punições cumpridas, elas são encerradas.*após 30 dias/)).toBeInTheDocument();
  });

  it("mostra as punições em aberto do aluno; só a pendente tem cumprir e lixeira", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    await abrirAna();
    expect(screen.getByText("Chegou atrasado")).toBeInTheDocument();
    expect(screen.getByText("pendente")).toBeInTheDocument();
    expect(screen.getByText("cumprida")).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: /Marcar como cumprida/ })).toHaveLength(1);
    expect(screen.getByRole("button", { name: "Excluir punição 10 flexões + 1 Coca-Cola" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Excluir punição 1 Coca-Cola" })).not.toBeInTheDocument();
  });

  it("aplica punição com os itens marcados e a observação", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: /Aplicar punição/ }));
    const d = await screen.findByRole("dialog");

    // Sem item marcado não envia.
    fireEvent.click(within(d).getByRole("button", { name: "Aplicar" }));
    expect(within(d).getByText("Escolha pelo menos uma punição.")).toBeInTheDocument();
    expect(callsTo("/punicoes", "POST")).toHaveLength(0);

    // Item inativo não aparece pra aplicar.
    expect(within(d).queryByLabelText("Polichinelos")).not.toBeInTheDocument();
    fireEvent.click(await within(d).findByLabelText("1 Coca-Cola"));
    fireEvent.click(within(d).getByLabelText("10 flexões"));
    fireEvent.change(within(d).getByLabelText("Observação (opcional)"), { target: { value: "  Faltou sem avisar " } });
    fireEvent.click(within(d).getByRole("button", { name: "Aplicar" }));

    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes", {
        method: "POST",
        body: JSON.stringify({ studentId: "a1", itemIds: ["i1", "i2"], observacao: "Faltou sem avisar" }),
      })
    );
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("success", "Punição aplicada a Ana Lutadora."));
    await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  });

  it("aplica sem observação: o campo não vai no corpo", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: /Aplicar punição/ }));
    const d = await screen.findByRole("dialog");
    fireEvent.click(await within(d).findByLabelText("10 flexões"));
    fireEvent.click(within(d).getByRole("button", { name: "Aplicar" }));
    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes", {
        method: "POST",
        body: JSON.stringify({ studentId: "a1", itemIds: ["i1"] }),
      })
    );
  });

  it("marcar como cumprida usa a lista devolvida e avisa quando fecha o ciclo", async () => {
    mockAuth(["lutas"]);
    setupApi({ cumprir: async () => [] });
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: /Marcar como cumprida/ }));
    await waitFor(() => expect(apiMock).toHaveBeenCalledWith("/punicoes/p1/cumprir", { method: "POST" }));
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("success", "Ciclo concluído: 2 punições encerradas."));
    expect(await screen.findByText("Nenhuma punição em aberto.")).toBeInTheDocument();
  });

  it("marcar como cumprida sem fechar ciclo mostra a punição como cumprida", async () => {
    mockAuth(["lutas"]);
    setupApi({ cumprir: async () => [ABERTAS[0], { ...ABERTAS[1], status: "CUMPRIDA", cumpridaEm: "2026-11-12T10:00:00Z" }] });
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: /Marcar como cumprida/ }));
    await waitFor(() =>
      expect(toastMock).toHaveBeenCalledWith("success", 'Punição "10 flexões + 1 Coca-Cola" marcada como cumprida.')
    );
    await waitFor(() => expect(screen.queryByRole("button", { name: /Marcar como cumprida/ })).not.toBeInTheDocument());
  });

  it("exclui pendente só depois de confirmar", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: "Excluir punição 10 flexões + 1 Coca-Cola" }));
    const d = screen.getByRole("dialog");
    expect(callsTo("/punicoes/p1", "DELETE")).toHaveLength(0);
    fireEvent.click(within(d).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(callsTo("/punicoes/p1", "DELETE")).toHaveLength(1));
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("success", 'Punição "10 flexões + 1 Coca-Cola" excluída.'));
  });

  it("mostra a mensagem do servidor quando a exclusão é recusada", async () => {
    mockAuth(["lutas"]);
    const msg = "Só dá para excluir punição pendente.";
    setupApi({ onDelete: async () => { throw new ApiError(422, msg); } });
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: "Excluir punição 10 flexões + 1 Coca-Cola" }));
    fireEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("error", msg));
  });

  it("ver histórico lista também as concluídas", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />);
    await abrirAna();
    fireEvent.click(screen.getByRole("button", { name: /Ver histórico/ }));
    const hist = await screen.findByRole("list", { name: "Histórico de punições" });
    expect(await within(hist).findByText("Burpees")).toBeInTheDocument();
    expect(within(hist).getByText("concluída")).toBeInTheDocument();
  });
});

describe("Punições - catálogo", () => {
  it("lista ativos e inativos e cria um item novo", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />, { route: "/punicoes?aba=catalogo" });
    expect(await screen.findByText("Polichinelos")).toBeInTheDocument();
    expect(screen.getAllByText("ativa")).toHaveLength(2);
    expect(screen.getByText("inativa")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Novo item/ }));
    const d = screen.getByRole("dialog");
    fireEvent.click(within(d).getByRole("button", { name: "Salvar" }));
    expect(within(d).getByText("Informe o nome da punição.")).toBeInTheDocument();

    fireEvent.change(within(d).getByLabelText("Nome"), { target: { value: " 20 abdominais " } });
    fireEvent.click(within(d).getByRole("button", { name: "Salvar" }));
    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes/itens", { method: "POST", body: JSON.stringify({ nome: "20 abdominais" }) })
    );
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("success", 'Punição "20 abdominais" criada.'));
  });

  it("ativa/desativa mantendo o nome", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Punicoes />, { route: "/punicoes?aba=catalogo" });
    fireEvent.click(await screen.findByRole("button", { name: "Desativar 10 flexões" }));
    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes/itens/i1", { method: "PUT", body: JSON.stringify({ nome: "10 flexões", ativo: false }) })
    );
    fireEvent.click(screen.getByRole("button", { name: "Ativar Polichinelos" }));
    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes/itens/i3", { method: "PUT", body: JSON.stringify({ nome: "Polichinelos", ativo: true }) })
    );
  });

  it("renomeia um item", async () => {
    mockAuth(["lutas"]);
    setupApi();
    renderWithProviders(<Punicoes />, { route: "/punicoes?aba=catalogo" });
    fireEvent.click(await screen.findByRole("button", { name: "Editar 1 Coca-Cola" }));
    const d = screen.getByRole("dialog");
    fireEvent.change(within(d).getByLabelText("Nome"), { target: { value: "1 Guaraná" } });
    fireEvent.click(within(d).getByRole("button", { name: "Salvar" }));
    await waitFor(() =>
      expect(apiMock).toHaveBeenCalledWith("/punicoes/itens/i2", { method: "PUT", body: JSON.stringify({ nome: "1 Guaraná", ativo: true }) })
    );
  });
});
