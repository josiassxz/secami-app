import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import Login from "@/pages/Login";
import { useAuth } from "@/lib/auth";

vi.mock("@/lib/auth", () => ({
  useAuth: vi.fn(),
}));

const mockedUseAuth = vi.mocked(useAuth);

function renderLogin(signIn: (u: string, p: string) => Promise<void>) {
  mockedUseAuth.mockReturnValue({
    user: null,
    loading: false,
    signIn,
    signOut: vi.fn(),
    hasRole: () => false,
  });

  return render(
    <MemoryRouter initialEntries={["/login"]}>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<div>Página inicial</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe("<Login />", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("renderiza os campos de usuário e senha e o botão de entrar", () => {
    renderLogin(vi.fn());

    expect(screen.getByLabelText("Usuário")).toBeInTheDocument();
    expect(screen.getByLabelText("Senha")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Entrar" })).toBeInTheDocument();
  });

  it("submit chama signIn com usuário e senha digitados e navega pra / em caso de sucesso", async () => {
    const signIn = vi.fn().mockResolvedValue(undefined);
    renderLogin(signIn);

    await userEvent.type(screen.getByLabelText("Usuário"), "fulano");
    await userEvent.type(screen.getByLabelText("Senha"), "senha123");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));

    await waitFor(() => expect(signIn).toHaveBeenCalledWith("fulano", "senha123"));
    await waitFor(() => expect(screen.getByText("Página inicial")).toBeInTheDocument());
  });

  it("mostra a mensagem de erro na tela quando o login falha e NÃO navega", async () => {
    const signIn = vi.fn().mockRejectedValue(new Error("Usuário ou senha inválidos"));
    renderLogin(signIn);

    await userEvent.type(screen.getByLabelText("Usuário"), "fulano");
    await userEvent.type(screen.getByLabelText("Senha"), "senhaerrada");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Usuário ou senha inválidos");
    expect(screen.queryByText("Página inicial")).not.toBeInTheDocument();
  });

  it("quando o erro não tem mensagem, mostra um texto padrão em vez de deixar a tela muda", async () => {
    const signIn = vi.fn().mockRejectedValue({});
    renderLogin(signIn);

    await userEvent.type(screen.getByLabelText("Usuário"), "fulano");
    await userEvent.type(screen.getByLabelText("Senha"), "x");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Não foi possível entrar.");
  });

  it("desabilita o botão enquanto o login está em andamento", async () => {
    let resolveSignIn: () => void = () => {};
    const signIn = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveSignIn = resolve;
        })
    );
    renderLogin(signIn);

    await userEvent.type(screen.getByLabelText("Usuário"), "fulano");
    await userEvent.type(screen.getByLabelText("Senha"), "senha123");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));

    expect(screen.getByRole("button", { name: "Entrar" })).toBeDisabled();

    resolveSignIn();
    await waitFor(() => expect(screen.getByText("Página inicial")).toBeInTheDocument());
  });

  it("limpa o erro anterior ao tentar de novo", async () => {
    const signIn = vi
      .fn()
      .mockRejectedValueOnce(new Error("Usuário ou senha inválidos"))
      .mockResolvedValueOnce(undefined);
    renderLogin(signIn);

    await userEvent.type(screen.getByLabelText("Usuário"), "fulano");
    await userEvent.type(screen.getByLabelText("Senha"), "errada");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));
    await screen.findByRole("alert");

    await userEvent.clear(screen.getByLabelText("Senha"));
    await userEvent.type(screen.getByLabelText("Senha"), "certa");
    await userEvent.click(screen.getByRole("button", { name: "Entrar" }));

    await waitFor(() => expect(screen.queryByRole("alert")).not.toBeInTheDocument());
    await waitFor(() => expect(screen.getByText("Página inicial")).toBeInTheDocument());
  });
});
