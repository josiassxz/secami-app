import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import WorkoutPlans from "@/pages/WorkoutPlans";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({ api: vi.fn() }));
vi.mock("@/lib/auth", () => ({ useAuth: vi.fn() }));

const apiMock = vi.mocked(api);
const useAuthMock = vi.mocked(useAuth);

function mockAuth(roles: string[]) {
  useAuthMock.mockReturnValue({
    user: { id: "u1", samAccountName: "prof", nome: "Instrutor Teste", email: "prof@x.com", roles },
    loading: false,
    signIn: vi.fn(),
    signOut: vi.fn(),
    hasRole: (...want: string[]) => want.some((r) => roles.includes(r)),
  });
}

const ANA = { id: "s1", fullName: "Ana Souza", cpf: "123.***.***-00" };
const BETO = { id: "s2", fullName: "Beto Lima", cpf: "456.***.***-11" };

const CATALOGO = [
  { id: "e1", name: "Supino reto", muscleGroup: "Peito" },
  { id: "e2", name: "Puxada alta", muscleGroup: "Costas" },
  { id: "e3", name: "Crucifixo antigo", muscleGroup: "Peito", arquivado: true },
];

const FICHA_A = {
  id: "p1",
  studentId: "s1",
  studentName: "Ana Souza",
  sheetLabel: "A",
  title: "Peito e tríceps",
  active: true,
  exercises: [
    { exerciseId: "e1", exerciseName: "Supino reto", ordem: 0, sets: 4, reps: "10", restSeconds: 90 },
  ],
};

/** Mock de `api` por caminho: fichas por aluno (mutáveis), busca de alunos,
 *  catálogo, e escritas em /workout-plans registradas em `escritas`. */
function setupApi(fichasPorAluno: Record<string, unknown[]> = { s1: [FICHA_A], s2: [] }) {
  const escritas: { method: string; path: string; body: any }[] = [];
  apiMock.mockImplementation(async (path: string, opts?: any) => {
    const method = opts?.method ?? "GET";
    if (path.startsWith("/workout-plans")) {
      const body = opts?.body ? JSON.parse(opts.body) : null;
      escritas.push({ method, path, body });
      if (method === "DELETE") return undefined;
      return { id: "novo", studentName: "", exercises: [], active: true, ...body };
    }
    if (path.startsWith("/students/s1/workout-plans")) return fichasPorAluno.s1 ?? [];
    if (path.startsWith("/students/s2/workout-plans")) return fichasPorAluno.s2 ?? [];
    if (path.startsWith("/students?")) {
      const q = decodeURIComponent(path.match(/q=([^&]*)/)?.[1] ?? "").toLowerCase();
      return { content: [ANA, BETO].filter((s) => s.fullName.toLowerCase().includes(q)) };
    }
    if (path.startsWith("/exercises")) return CATALOGO;
    return undefined;
  });
  return escritas;
}

async function abrirAluno(nome = "Ana") {
  renderWithProviders(<WorkoutPlans />);
  fireEvent.change(screen.getByPlaceholderText("Buscar aluno (nome ou CPF)"), { target: { value: nome } });
  fireEvent.click(await screen.findByText(nome === "Ana" ? "Ana Souza" : "Beto Lima"));
}

function dialogo() {
  return screen.getByRole("dialog");
}

afterEach(() => {
  apiMock.mockReset();
  useAuthMock.mockReset();
});

describe("Fichas de Treino - permissões", () => {
  it("instrutor vê Nova ficha, Editar, Usar como modelo e Excluir", async () => {
    mockAuth(["professor"]);
    setupApi();
    await abrirAluno();
    expect(await screen.findByText("Peito e tríceps")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Nova ficha/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Usar como modelo/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Editar/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Excluir ficha A" })).toBeInTheDocument();
  });

  it("quem não é instrutor nem admin só visualiza", async () => {
    mockAuth(["gerente"]);
    setupApi();
    await abrirAluno();
    expect(await screen.findByText("Peito e tríceps")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Nova ficha/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Editar/ })).not.toBeInTheDocument();
  });
});

describe("Fichas de Treino - nova ficha", () => {
  it("monta a ficha com exercícios do catálogo e envia pro aluno selecionado", async () => {
    mockAuth(["professor"]);
    const escritas = setupApi();
    await abrirAluno();
    fireEvent.click(await screen.findByRole("button", { name: /Nova ficha/ }));

    const d = dialogo();
    // Ana já tem a ficha A: a sugestão é a próxima letra livre.
    await waitFor(() => expect((within(d).getByLabelText("Ficha") as HTMLSelectElement).value).toBe("B"));
    // Arquivado não aparece no catálogo.
    await within(d).findByRole("option", { name: "Puxada alta" });
    expect(within(d).queryByRole("option", { name: "Crucifixo antigo" })).not.toBeInTheDocument();

    fireEvent.change(within(d).getByLabelText("Título"), { target: { value: "Costas e bíceps" } });
    fireEvent.change(within(d).getByLabelText("Exercício 1"), { target: { value: "e2" } });
    fireEvent.change(within(d).getByLabelText("Repetições do exercício 1"), { target: { value: "10-12" } });
    fireEvent.change(within(d).getByLabelText("Observações do exercício 1"), { target: { value: "pegada aberta" } });
    fireEvent.click(within(d).getByRole("button", { name: /Adicionar exercício/ }));
    fireEvent.change(within(d).getByLabelText("Exercício 2"), { target: { value: "e1" } });
    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));

    await waitFor(() => expect(escritas).toHaveLength(1));
    expect(escritas[0].method).toBe("POST");
    expect(escritas[0].body).toEqual({
      studentId: "s1",
      sheetLabel: "B",
      title: "Costas e bíceps",
      active: true,
      validUntil: null,
      exercises: [
        { exerciseId: "e2", exerciseName: "Puxada alta", sets: 3, reps: "10-12", restSeconds: 60, notes: "pegada aberta" },
        { exerciseId: "e1", exerciseName: "Supino reto", sets: 3, reps: "12", restSeconds: 60, notes: null },
      ],
    });
    await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  });

  it("não salva sem título, sem exercício escolhido ou com número inválido", async () => {
    mockAuth(["professor"]);
    const escritas = setupApi();
    await abrirAluno();
    fireEvent.click(await screen.findByRole("button", { name: /Nova ficha/ }));
    const d = dialogo();

    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));
    expect(await within(d).findByText("Informe o título da ficha.")).toBeInTheDocument();
    expect(within(d).getByText("Escolha o exercício.")).toBeInTheDocument();
    expect(screen.getByText("Revise os campos destacados.")).toBeInTheDocument();

    fireEvent.change(within(d).getByLabelText("Título"), { target: { value: "Ficha" } });
    fireEvent.change(within(d).getByLabelText("Exercício 1"), { target: { value: "e1" } });
    fireEvent.change(within(d).getByLabelText("Séries do exercício 1"), { target: { value: "três" } });
    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));
    expect(await within(d).findByText("Séries e descanso aceitam só números inteiros.")).toBeInTheDocument();

    fireEvent.click(within(d).getByRole("button", { name: "Remover exercício 1" }));
    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));
    expect(await within(d).findByText("Adicione pelo menos um exercício.")).toBeInTheDocument();
    expect(escritas).toHaveLength(0);
  });
});

describe("Fichas de Treino - editar, modelo e excluir", () => {
  it("edita a ficha existente com PUT, mantendo o aluno", async () => {
    mockAuth(["admin"]);
    const escritas = setupApi();
    await abrirAluno();
    fireEvent.click(await screen.findByRole("button", { name: /Editar/ }));
    const d = dialogo();
    expect((within(d).getByLabelText("Título") as HTMLInputElement).value).toBe("Peito e tríceps");
    expect(within(d).queryByRole("button", { name: "Trocar aluno" })).not.toBeInTheDocument();

    fireEvent.change(within(d).getByLabelText("Séries do exercício 1"), { target: { value: "5" } });
    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));

    await waitFor(() => expect(escritas).toHaveLength(1));
    expect(escritas[0]).toMatchObject({ method: "PUT", path: "/workout-plans/p1" });
    expect(escritas[0].body.sheetLabel).toBe("A");
    expect(escritas[0].body.exercises[0]).toMatchObject({ exerciseId: "e1", sets: 5, reps: "10", restSeconds: 90 });
  });

  it("usa uma ficha existente como modelo para OUTRO aluno, sem alterar a original", async () => {
    mockAuth(["professor"]);
    const escritas = setupApi();
    await abrirAluno();
    fireEvent.click(await screen.findByRole("button", { name: /Usar como modelo/ }));
    const d = dialogo();
    expect(within(d).getByText(/Modelo: ficha A "Peito e tríceps" de Ana Souza/)).toBeInTheDocument();

    fireEvent.click(within(d).getByRole("button", { name: "Trocar aluno" }));
    fireEvent.change(within(d).getByLabelText("Buscar aluno de destino"), { target: { value: "Beto" } });
    fireEvent.click(await within(d).findByText("Beto Lima"));
    // Beto não tem fichas: a letra sugerida volta pra A.
    await waitFor(() => expect((within(d).getByLabelText("Ficha") as HTMLSelectElement).value).toBe("A"));
    fireEvent.click(within(d).getByRole("button", { name: "Salvar ficha" }));

    await waitFor(() => expect(escritas).toHaveLength(1));
    expect(escritas[0].method).toBe("POST");
    expect(escritas[0].body).toMatchObject({
      studentId: "s2",
      sheetLabel: "A",
      title: "Peito e tríceps",
      exercises: [{ exerciseId: "e1", sets: 4, reps: "10", restSeconds: 90 }],
    });
    // A tela passa a mostrar o aluno de destino.
    expect(await screen.findByRole("heading", { name: "Beto Lima" })).toBeInTheDocument();
  });

  it("exclui só depois de confirmar", async () => {
    mockAuth(["professor"]);
    const escritas = setupApi();
    await abrirAluno();
    fireEvent.click(await screen.findByRole("button", { name: "Excluir ficha A" }));
    expect(escritas).toHaveLength(0);

    const d = await screen.findByRole("dialog");
    fireEvent.click(within(d).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(escritas).toEqual([{ method: "DELETE", path: "/workout-plans/p1", body: null }]));
  });
});
