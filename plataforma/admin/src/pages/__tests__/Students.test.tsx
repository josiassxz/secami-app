import { afterEach, describe, expect, it, vi } from "vitest";
import { act, fireEvent, screen, waitFor, within } from "@testing-library/react";
import Students from "@/pages/Students";
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

function mockAuth(roles: string[]) {
  useAuthMock.mockReturnValue({
    user: { id: "1", samAccountName: "fulano", nome: "Fulano", email: "fulano@x.com", roles },
    loading: false,
    signIn: vi.fn(),
    signOut: vi.fn(),
    hasRole: (...want: string[]) => want.some((r) => roles.includes(r)),
  });
}

const STUDENTS = [
  {
    id: "s1",
    fullName: "Ana Souza",
    cpf: "123.***.**9-00",
    studentType: "Civil",
    departmentName: "SGG",
    active: true,
    atestadoValido: true,
  },
  {
    id: "s2",
    fullName: "Beto Lima",
    cpf: "456.***.**1-11",
    studentType: "Militar",
    departmentName: "PM",
    active: false,
    atestadoValido: false,
  },
];

const DEPARTMENTS = [
  { id: "d1", name: "SGG" },
  { id: "d2", name: "PM" },
];

function page({
  content = STUDENTS,
  totalElements = STUDENTS.length,
  totalPages = 1,
}: { content?: unknown[]; totalElements?: number; totalPages?: number } = {}) {
  return { content, totalElements, totalPages };
}

/** Configura o mock de `api`: GET /students?... -> lista; GET /departments -> secretarias;
 *  POST /students -> criação (customizável via onCreate). */
function setupApi({
  list = page(),
  departmentsList = DEPARTMENTS,
  onCreate,
}: {
  list?: unknown;
  departmentsList?: unknown;
  onCreate?: (body: any) => Promise<unknown>;
} = {}) {
  apiMock.mockImplementation((path: string, options: any = {}) => {
    if (options?.method === "POST" && path === "/students") {
      const body = options.body ? JSON.parse(options.body) : {};
      return onCreate ? onCreate(body) : Promise.resolve({ id: "new-1" });
    }
    if (path.startsWith("/students")) return Promise.resolve(list);
    if (path.startsWith("/departments")) return Promise.resolve(departmentsList);
    return Promise.resolve(undefined);
  });
}

afterEach(() => {
  vi.clearAllMocks();
  vi.useRealTimers();
});

describe("Students - listagem", () => {
  it("renderiza os alunos retornados pela API", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Students />);

    const table = await screen.findByRole("table");
    expect(within(table).getByText("Ana Souza")).toBeInTheDocument();
    expect(within(table).getByText("Beto Lima")).toBeInTheDocument();
    expect(within(table).getByText("SGG")).toBeInTheDocument();
    expect(within(table).getByText("PM")).toBeInTheDocument();
  });

  it("mostra estado de carregamento (skeleton) antes dos dados chegarem", () => {
    mockAuth(["admin"]);
    apiMock.mockImplementation(() => new Promise(() => {}));
    const { container } = renderWithProviders(<Students />);
    expect(container.querySelectorAll(".animate-pulse").length).toBeGreaterThan(0);
  });

  it("mostra mensagem de vazio quando não há alunos", async () => {
    mockAuth(["admin"]);
    setupApi({ list: page({ content: [], totalElements: 0 }) });
    renderWithProviders(<Students />);
    expect(await screen.findByText("Nenhum aluno cadastrado")).toBeInTheDocument();
  });

  it("não expõe o CPF completo na tela — exibe exatamente o valor mascarado que veio da API", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Students />);

    const table = await screen.findByRole("table");
    // O valor mascarado enviado pelo backend aparece tal como veio.
    expect(within(table).getByText("123.***.**9-00")).toBeInTheDocument();
    expect(within(table).getByText("456.***.**1-11")).toBeInTheDocument();
    // A tela não deve exibir um CPF completo (11 dígitos corridos, ou formatado sem máscara).
    expect(within(table).queryByText(/\b\d{11}\b/)).not.toBeInTheDocument();
    expect(within(table).queryByText(/^\d{3}\.\d{3}\.\d{3}-\d{2}$/)).not.toBeInTheDocument();
  });
});

describe("Students - busca", () => {
  it("dispara a query com o termo digitado", async () => {
    mockAuth(["admin"]);
    setupApi();
    renderWithProviders(<Students />);
    await screen.findByRole("table");
    apiMock.mockClear();

    const input = screen.getByPlaceholderText("Buscar por nome ou CPF");
    fireEvent.change(input, { target: { value: "ana" } });

    await waitFor(() => {
      const calls = apiMock.mock.calls.filter(([p]) => String(p).startsWith("/students?"));
      expect(calls.some(([p]) => String(p).includes(`q=${encodeURIComponent("ana")}`))).toBe(true);
    });
  });

  it("aplica debounce: não dispara uma requisição a cada tecla, só após pausar de digitar", async () => {
    mockAuth(["admin"]);
    setupApi();
    vi.useFakeTimers();

    renderWithProviders(<Students />);
    // Deixa a query inicial (termo vazio, disparada no mount) resolver.
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    apiMock.mockClear();

    const input = screen.getByPlaceholderText("Buscar por nome ou CPF");

    fireEvent.change(input, { target: { value: "a" } });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(100);
    });
    fireEvent.change(input, { target: { value: "an" } });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(100);
    });
    fireEvent.change(input, { target: { value: "ana" } });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(100); // só 100ms desde a última tecla — debounce ainda não completou
    });

    const callsDuringTyping = apiMock.mock.calls.filter(([p]) => String(p).startsWith("/students?"));
    expect(callsDuringTyping).toHaveLength(0);

    await act(async () => {
      await vi.advanceTimersByTimeAsync(300); // agora passa dos 300ms de pausa
    });

    const finalCalls = apiMock.mock.calls.filter(([p]) => String(p).startsWith("/students?"));
    expect(finalCalls).toHaveLength(1);
    expect(String(finalCalls[0][0])).toContain(`q=${encodeURIComponent("ana")}`);
  });
});

describe("Students - paginação", () => {
  it("avança e volta de página corretamente", async () => {
    mockAuth(["admin"]);
    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    renderWithProviders(<Students />);

    await screen.findByText("1–15 de 45");
    const prevBtn = screen.getByRole("button", { name: /Anterior/ });
    const nextBtn = screen.getByRole("button", { name: /Próxima/ });
    expect(prevBtn).toBeDisabled();
    expect(nextBtn).not.toBeDisabled();

    apiMock.mockClear();
    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    fireEvent.click(nextBtn);

    await waitFor(() => {
      const calls = apiMock.mock.calls.filter(([p]) => String(p).startsWith("/students?"));
      expect(calls.some(([p]) => String(p).includes("page=1"))).toBe(true);
    });
    await screen.findByText("16–30 de 45");
    expect(screen.getByRole("button", { name: /Anterior/ })).not.toBeDisabled();

    apiMock.mockClear();
    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    fireEvent.click(screen.getByRole("button", { name: /Anterior/ }));

    await waitFor(() => {
      const calls = apiMock.mock.calls.filter(([p]) => String(p).startsWith("/students?"));
      expect(calls.some(([p]) => String(p).includes("page=0"))).toBe(true);
    });
    await screen.findByText("1–15 de 45");
  });

  it("desabilita 'Próxima' na última página", async () => {
    mockAuth(["admin"]);
    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    renderWithProviders(<Students />);
    await screen.findByText("1–15 de 45");

    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    fireEvent.click(screen.getByRole("button", { name: /Próxima/ }));
    await screen.findByText("16–30 de 45");

    setupApi({ list: page({ totalElements: 45, totalPages: 3 }) });
    fireEvent.click(screen.getByRole("button", { name: /Próxima/ }));
    await screen.findByText("31–45 de 45");

    expect(screen.getByRole("button", { name: /Próxima/ })).toBeDisabled();
  });
});

describe("Students - novo aluno", () => {
  it("não mostra o botão 'Novo aluno' para papéis sem permissão de edição", async () => {
    mockAuth(["professor"]);
    setupApi();
    renderWithProviders(<Students />);
    await screen.findByRole("table");
    expect(screen.queryByRole("button", { name: /Novo aluno/ })).not.toBeInTheDocument();
  });

  it("valida campos obrigatórios antes de enviar o formulário", async () => {
    mockAuth(["admin"]);
    setupApi({ list: page({ content: [], totalElements: 0 }) });
    renderWithProviders(<Students />);
    await screen.findByText("Nenhum aluno cadastrado");

    fireEvent.click(screen.getByRole("button", { name: /Novo aluno/ }));
    expect(screen.getByRole("heading", { name: "Novo aluno" })).toBeInTheDocument();

    apiMock.mockClear();
    fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    expect(await screen.findByText("Informe o nome completo.")).toBeInTheDocument();
    const createCalls = apiMock.mock.calls.filter(
      ([p, opts]) => p === "/students" && (opts as any)?.method === "POST"
    );
    expect(createCalls).toHaveLength(0);

    // Preenche só o nome — ainda falta o CPF.
    fireEvent.change(screen.getByLabelText("Nome completo"), { target: { value: "Novo Aluno" } });
    fireEvent.click(screen.getByRole("button", { name: "Salvar" }));
    expect(await screen.findByText("Informe o CPF.")).toBeInTheDocument();
    expect(
      apiMock.mock.calls.filter(([p, opts]) => p === "/students" && (opts as any)?.method === "POST")
    ).toHaveLength(0);
  });

  it("mostra o erro do backend quando a criação falha", async () => {
    mockAuth(["admin"]);
    setupApi({
      list: page({ content: [], totalElements: 0 }),
      onCreate: () => Promise.reject(new Error("Já existe aluno com esse CPF.")),
    });
    renderWithProviders(<Students />);
    await screen.findByText("Nenhum aluno cadastrado");

    fireEvent.click(screen.getByRole("button", { name: /Novo aluno/ }));
    fireEvent.change(screen.getByLabelText("Nome completo"), { target: { value: "Novo Aluno" } });
    fireEvent.change(screen.getByLabelText("CPF"), { target: { value: "12345678900" } });

    fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    expect(await screen.findByText("Já existe aluno com esse CPF.")).toBeInTheDocument();
  });

  it("envia e fecha o modal quando a criação é bem-sucedida", async () => {
    mockAuth(["admin"]);
    setupApi({ list: page({ content: [], totalElements: 0 }) });
    renderWithProviders(<Students />);
    await screen.findByText("Nenhum aluno cadastrado");

    fireEvent.click(screen.getByRole("button", { name: /Novo aluno/ }));
    fireEvent.change(screen.getByLabelText("Nome completo"), { target: { value: "Novo Aluno" } });
    fireEvent.change(screen.getByLabelText("CPF"), { target: { value: "12345678900" } });

    fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => {
      expect(screen.queryByRole("heading", { name: "Novo aluno" })).not.toBeInTheDocument();
    });
    const createCalls = apiMock.mock.calls.filter(
      ([p, opts]) => p === "/students" && (opts as any)?.method === "POST"
    );
    expect(createCalls).toHaveLength(1);
  });
});
