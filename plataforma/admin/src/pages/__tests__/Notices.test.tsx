import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import Notices from "@/pages/Notices";
import { api } from "@/lib/api";
import { situacaoDoAviso } from "@/lib/avisos";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({ api: vi.fn() }));
const apiMock = vi.mocked(api);

const AVISO = {
  id: "n1",
  title: "Academia fechada",
  content: "Manutenção no feriado.",
  type: "warning",
  active: true,
  targetRoles: ["aluno"],
  exibirDe: "2026-10-01",
  exibirAte: "2026-10-05",
};

function setupApi(lista: unknown[] = [AVISO]) {
  const escritas: { method: string; path: string; body: any }[] = [];
  apiMock.mockImplementation(async (path: string, opts?: any) => {
    const method = opts?.method ?? "GET";
    if (method === "GET") return lista;
    escritas.push({ method, path, body: opts?.body ? JSON.parse(opts.body) : null });
    return {};
  });
  return escritas;
}

afterEach(() => apiMock.mockReset());

describe("situacaoDoAviso", () => {
  const base = { ...AVISO };
  it("considera ativo e o período, com as datas inclusive", () => {
    expect(situacaoDoAviso({ ...base, active: false }, "2026-10-02").rotulo).toBe("Inativo");
    expect(situacaoDoAviso(base, "2026-09-30").rotulo).toBe("Agendado");
    expect(situacaoDoAviso(base, "2026-10-01").rotulo).toBe("Em exibição");
    expect(situacaoDoAviso(base, "2026-10-05").rotulo).toBe("Em exibição");
    expect(situacaoDoAviso(base, "2026-10-06").rotulo).toBe("Encerrado");
    expect(situacaoDoAviso({ ...base, exibirDe: null, exibirAte: null }, "2030-01-01").rotulo).toBe("Em exibição");
  });
});

describe("Avisos - admin", () => {
  it("mostra o período de exibição de cada aviso", async () => {
    setupApi();
    renderWithProviders(<Notices />);
    expect(await screen.findByText("Academia fechada")).toBeInTheDocument();
    expect(screen.getByText(/Exibição de 01\/10\/2026 a 05\/10\/2026/)).toBeInTheDocument();
  });

  it("publica um aviso novo com o período escolhido", async () => {
    const escritas = setupApi([]);
    renderWithProviders(<Notices />);
    fireEvent.click(await screen.findByRole("button", { name: /Novo aviso/ }));
    const d = screen.getByRole("dialog");
    fireEvent.change(within(d).getByLabelText("Título"), { target: { value: "Semana da saúde" } });
    fireEvent.change(within(d).getByLabelText("Conteúdo"), { target: { value: "Avaliação física gratuita." } });
    fireEvent.change(within(d).getByLabelText("Exibir de"), { target: { value: "2026-10-10" } });
    fireEvent.change(within(d).getByLabelText("Exibir até"), { target: { value: "2026-10-17" } });
    fireEvent.click(within(d).getByRole("button", { name: "Publicar" }));

    await waitFor(() => expect(escritas).toHaveLength(1));
    expect(escritas[0]).toEqual({
      method: "POST",
      path: "/notices",
      body: {
        title: "Semana da saúde",
        content: "Avaliação física gratuita.",
        type: "info",
        active: true,
        targetRoles: ["aluno"],
        exibirDe: "2026-10-10",
        exibirAte: "2026-10-17",
      },
    });
  });

  it("não publica com a data final antes da inicial", async () => {
    const escritas = setupApi([]);
    renderWithProviders(<Notices />);
    fireEvent.click(await screen.findByRole("button", { name: /Novo aviso/ }));
    const d = screen.getByRole("dialog");
    fireEvent.change(within(d).getByLabelText("Título"), { target: { value: "X" } });
    fireEvent.change(within(d).getByLabelText("Conteúdo"), { target: { value: "Y" } });
    fireEvent.change(within(d).getByLabelText("Exibir de"), { target: { value: "2026-10-10" } });
    fireEvent.change(within(d).getByLabelText("Exibir até"), { target: { value: "2026-10-01" } });
    fireEvent.click(within(d).getByRole("button", { name: "Publicar" }));

    expect(await screen.findByText(/data final da exibição deve ser igual ou posterior/)).toBeInTheDocument();
    expect(escritas).toHaveLength(0);
  });

  it("edita um aviso existente (período e ativo) com PUT", async () => {
    const escritas = setupApi();
    renderWithProviders(<Notices />);
    fireEvent.click(await screen.findByRole("button", { name: "Editar aviso Academia fechada" }));
    const d = screen.getByRole("dialog");
    expect((within(d).getByLabelText("Exibir de") as HTMLInputElement).value).toBe("2026-10-01");
    fireEvent.change(within(d).getByLabelText("Exibir até"), { target: { value: "" } });
    fireEvent.click(within(d).getByLabelText("Aviso ativo"));
    fireEvent.click(within(d).getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(escritas).toHaveLength(1));
    expect(escritas[0].method).toBe("PUT");
    expect(escritas[0].path).toBe("/notices/n1");
    expect(escritas[0].body).toMatchObject({ exibirDe: "2026-10-01", exibirAte: null, active: false, type: "warning" });
  });
});
