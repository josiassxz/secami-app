import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import PendingRegistrations from "@/pages/PendingRegistrations";
import { api, downloadMedia, type PendingRegistration } from "@/lib/api";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({
  api: vi.fn(),
  downloadMedia: vi.fn(),
}));

const apiMock = vi.mocked(api);
const downloadMediaMock = vi.mocked(downloadMedia);

const REG: PendingRegistration = {
  studentId: "s1",
  fullName: "Maria Teste da Silva",
  cpf: "52998224725",
  email: "maria.teste@example.com",
  phone: "62999998888",
  studentType: "Civil",
  birthDate: "1990-05-15",
  weightKg: 65.5,
  heightCm: 165,
  objetivos: ["Emagrecimento", "Condicionamento"],
  departmentName: "Secretaria de Estado da Casa Militar",
  parQ: {
    problema_coracao: false,
    dor_peito_atividade: true,
    dor_peito_mes: false,
    desequilibrio_tontura: false,
    problema_osseo_articular: false,
    tratamento_pressao_coracao: false,
    outra_razao_nao_praticar: false,
    tratamento_continuo: false,
    cirurgia_compromete_atividade: false,
    outra_razao_compromete_saude: false,
  },
  termoResponsabilidadeAceitoEm: "2026-08-27T12:10:42.270894Z",
  termoCienciaAceitoEm: "2026-08-27T12:10:42.270894Z",
  medicoNome: "Dr. Joao Souza",
  medicoCrm: "12345",
  medicoCrmUf: "GO",
  atestadoEmissaoData: "2026-08-01",
  atestadoArquivoId: "f1",
  createdAt: "2026-08-27T12:10:42.273269Z",
};

/** Configura o mock de `api`: GET /admin/cadastros/pendentes -> `list` (uma
 *  variável mutável, pra simular o item sumir depois de aprovar/recusar, como
 *  a tela real faz via invalidateQueries). */
function setupApi({ list = [REG] as PendingRegistration[] } = {}) {
  let current = list;
  apiMock.mockImplementation((path: string, options: any = {}) => {
    if (path === "/admin/cadastros/pendentes") return Promise.resolve(current);
    if (options?.method === "POST" && path === `/admin/cadastros/${REG.studentId}/aprovar`) {
      current = [];
      return Promise.resolve({ ...REG });
    }
    if (options?.method === "POST" && path === `/admin/cadastros/${REG.studentId}/rejeitar`) {
      current = [];
      return Promise.resolve({ ...REG });
    }
    return Promise.resolve(undefined);
  });
  return {
    setList: (l: PendingRegistration[]) => {
      current = l;
    },
  };
}

afterEach(() => {
  vi.clearAllMocks();
});

describe("PendingRegistrations - listagem", () => {
  it("renderiza os dados principais do cadastro pendente", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);

    expect(await screen.findByText("Maria Teste da Silva")).toBeInTheDocument();
    expect(screen.getByText("maria.teste@example.com")).toBeInTheDocument();
    expect(screen.getByText("52998224725")).toBeInTheDocument();
    expect(screen.getByText(/Dr\. Joao Souza/)).toBeInTheDocument();
  });

  it("mostra estado vazio quando não há cadastros pendentes", async () => {
    setupApi({ list: [] });
    renderWithProviders(<PendingRegistrations />);

    expect(await screen.findByText("Nenhum cadastro pendente")).toBeInTheDocument();
  });

  it("esconde o questionário PAR-Q até clicar em 'ver detalhes'", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    expect(screen.queryByText(/Questionário PAR-Q/)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Ver detalhes/ }));

    expect(await screen.findByText(/Questionário PAR-Q/)).toBeInTheDocument();
    expect(
      screen.getByText(/Você sente dores no peito e\/ou tórax quando pratica atividade física/)
    ).toBeInTheDocument();
  });
});

describe("PendingRegistrations - aprovar", () => {
  it("exige o perfil selecionado antes de habilitar Aprovar", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    expect(screen.getByRole("button", { name: "Aprovar" })).toBeDisabled();

    fireEvent.change(screen.getByLabelText("Perfil"), { target: { value: "Civil" } });

    expect(screen.getByRole("button", { name: "Aprovar" })).toBeEnabled();
  });

  it("aprova como aluno com a categoria escolhida e o item some da lista", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.change(screen.getByLabelText("Perfil"), { target: { value: "Militar" } });
    fireEvent.click(screen.getByRole("button", { name: "Aprovar" }));

    await waitFor(() => {
      const calls = apiMock.mock.calls.filter(
        ([p, opts]) => p === `/admin/cadastros/${REG.studentId}/aprovar` && (opts as any)?.method === "POST"
      );
      expect(calls).toHaveLength(1);
      expect(JSON.parse((calls[0][1] as any).body)).toEqual({ perfil: "aluno", studentType: "Militar" });
    });

    await waitFor(() =>
      expect(screen.queryByText("Maria Teste da Silva")).not.toBeInTheDocument()
    );
    expect(await screen.findByText("Nenhum cadastro pendente")).toBeInTheDocument();
  });
});

describe("PendingRegistrations - aprovar como instrutor", () => {
  const aprovarCalls = () =>
    apiMock.mock.calls.filter(
      ([p, opts]) => p === `/admin/cadastros/${REG.studentId}/aprovar` && (opts as any)?.method === "POST"
    );

  it("pede confirmação antes de aprovar como instrutor", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.change(screen.getByLabelText("Perfil"), { target: { value: "Instrutor" } });
    fireEvent.click(screen.getByRole("button", { name: "Aprovar" }));

    expect(
      await screen.findByRole("heading", { name: /Aprovar Maria Teste da Silva como instrutor/ })
    ).toBeInTheDocument();
    // Só abrir o diálogo não aprova ninguém.
    expect(aprovarCalls()).toHaveLength(0);

    fireEvent.click(screen.getByRole("button", { name: "Cancelar" }));
    await waitFor(() =>
      expect(screen.queryByRole("heading", { name: /como instrutor/ })).not.toBeInTheDocument()
    );
    expect(aprovarCalls()).toHaveLength(0);
  });

  it("confirma e envia o perfil instrutor, sem categoria de aluno", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.change(screen.getByLabelText("Perfil"), { target: { value: "Instrutor" } });
    fireEvent.click(screen.getByRole("button", { name: "Aprovar" }));
    fireEvent.click(await screen.findByRole("button", { name: "Aprovar como instrutor" }));

    await waitFor(() => {
      const calls = aprovarCalls();
      expect(calls).toHaveLength(1);
      expect(JSON.parse((calls[0][1] as any).body)).toEqual({ perfil: "instrutor" });
    });
    expect(await screen.findByText("Nenhum cadastro pendente")).toBeInTheDocument();
  });
});

describe("PendingRegistrations - recusar", () => {
  it("exige motivo antes de confirmar a recusa", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.click(screen.getByRole("button", { name: "Recusar" }));
    expect(await screen.findByRole("heading", { name: /Recusar cadastro/ })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Confirmar recusa" }));

    expect(await screen.findByText("Informe o motivo da recusa.")).toBeInTheDocument();
    const rejectCalls = apiMock.mock.calls.filter(
      ([p, opts]) => p === `/admin/cadastros/${REG.studentId}/rejeitar` && (opts as any)?.method === "POST"
    );
    expect(rejectCalls).toHaveLength(0);
  });

  it("recusa com motivo e o item some da lista", async () => {
    setupApi();
    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.click(screen.getByRole("button", { name: "Recusar" }));
    fireEvent.change(screen.getByLabelText("Motivo da recusa"), {
      target: { value: "Atestado ilegível, favor reenviar." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Confirmar recusa" }));

    await waitFor(() => {
      const calls = apiMock.mock.calls.filter(
        ([p, opts]) => p === `/admin/cadastros/${REG.studentId}/rejeitar` && (opts as any)?.method === "POST"
      );
      expect(calls).toHaveLength(1);
      expect(JSON.parse((calls[0][1] as any).body)).toEqual({
        motivo: "Atestado ilegível, favor reenviar.",
      });
    });

    await waitFor(() =>
      expect(screen.queryByRole("heading", { name: /Recusar cadastro/ })).not.toBeInTheDocument()
    );
    expect(await screen.findByText("Nenhum cadastro pendente")).toBeInTheDocument();
  });
});

describe("PendingRegistrations - atestado", () => {
  it("baixa o PDF autenticado e abre em nova aba ao clicar em 'Ver atestado'", async () => {
    setupApi();
    const blob = new Blob(["pdf"], { type: "application/pdf" });
    downloadMediaMock.mockResolvedValueOnce(blob);
    const createObjectURL = vi.fn(() => "blob:mock-url");
    const revokeObjectURL = vi.fn();
    vi.stubGlobal("URL", { ...URL, createObjectURL, revokeObjectURL });
    const openSpy = vi.spyOn(window, "open").mockImplementation(() => null);

    renderWithProviders(<PendingRegistrations />);
    await screen.findByText("Maria Teste da Silva");

    fireEvent.click(screen.getByRole("button", { name: /Ver atestado \(PDF\)/ }));

    await waitFor(() => expect(downloadMediaMock).toHaveBeenCalledWith("f1"));
    await waitFor(() => expect(createObjectURL).toHaveBeenCalledWith(blob));
    expect(openSpy).toHaveBeenCalledWith("blob:mock-url", "_blank", "noopener,noreferrer");

    vi.unstubAllGlobals();
  });
});
