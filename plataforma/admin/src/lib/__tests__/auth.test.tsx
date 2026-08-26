import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "@/lib/auth";
import * as api from "@/lib/api";
import type { Me } from "@/lib/api";

vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return {
    ...actual,
    login: vi.fn(),
    me: vi.fn(),
  };
});

const mockedLogin = vi.mocked(api.login);
const mockedMe = vi.mocked(api.me);

function makeUser(roles: string[]): Me {
  return {
    id: "1",
    samAccountName: "fulano",
    nome: "Fulano de Tal",
    email: "fulano@example.com",
    roles,
  };
}

/** Componente-sonda: expõe o estado do AuthProvider como texto pra asserção. */
function Probe({ rolesToCheck }: { rolesToCheck: string[] }) {
  const { user, loading, signIn, signOut, hasRole } = useAuth();
  return (
    <div>
      <div data-testid="loading">{String(loading)}</div>
      <div data-testid="user">{user?.nome ?? "none"}</div>
      <div data-testid="hasRole">{String(hasRole(...rolesToCheck))}</div>
      <button onClick={() => signIn("fulano", "senha")}>signin</button>
      <button onClick={() => signOut()}>signout</button>
    </div>
  );
}

function renderProbe(rolesToCheck: string[] = []) {
  return render(
    <AuthProvider>
      <Probe rolesToCheck={rolesToCheck} />
    </AuthProvider>
  );
}

describe("AuthProvider / useAuth", () => {
  beforeEach(() => {
    localStorage.clear();
    mockedLogin.mockReset();
    mockedMe.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("sem token salvo: termina de carregar sem usuário logado", async () => {
    renderProbe();
    await waitFor(() => expect(screen.getByTestId("loading")).toHaveTextContent("false"));
    expect(screen.getByTestId("user")).toHaveTextContent("none");
  });

  it("com token salvo e /me OK: carrega o usuário automaticamente", async () => {
    api.setTokens("access-1", "refresh-1");
    mockedMe.mockResolvedValueOnce(makeUser(["admin"]));

    renderProbe();

    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));
    expect(screen.getByTestId("loading")).toHaveTextContent("false");
  });

  it("com token salvo mas /me falha: limpa os tokens e segue deslogado", async () => {
    api.setTokens("access-1", "refresh-1");
    mockedMe.mockRejectedValueOnce(new api.ApiError(401, "inválido"));

    renderProbe();

    await waitFor(() => expect(screen.getByTestId("loading")).toHaveTextContent("false"));
    expect(screen.getByTestId("user")).toHaveTextContent("none");
    expect(api.getAccessToken()).toBeNull();
  });

  it("signIn: faz login, carrega /me e atualiza o usuário no contexto", async () => {
    mockedLogin.mockResolvedValueOnce({ accessToken: "a", refreshToken: "r" });
    mockedMe.mockResolvedValueOnce(makeUser(["gerente"]));

    renderProbe();
    await waitFor(() => expect(screen.getByTestId("loading")).toHaveTextContent("false"));

    await userEvent.click(screen.getByText("signin"));

    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));
    expect(mockedLogin).toHaveBeenCalledWith("fulano", "senha");
  });

  it("signOut: limpa tokens e derruba o usuário do contexto", async () => {
    api.setTokens("access-1", "refresh-1");
    mockedMe.mockResolvedValueOnce(makeUser(["admin"]));

    renderProbe();
    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));

    await userEvent.click(screen.getByText("signout"));

    expect(screen.getByTestId("user")).toHaveTextContent("none");
    expect(api.getAccessToken()).toBeNull();
  });

  it("evento secami:auth-expired (disparado pelo api.ts quando o refresh falha) derruba o usuário logado", async () => {
    api.setTokens("access-1", "refresh-1");
    mockedMe.mockResolvedValueOnce(makeUser(["admin"]));

    renderProbe();
    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));

    act(() => {
      window.dispatchEvent(new Event("secami:auth-expired"));
    });

    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("none"));
  });
});

describe("hasRole (via useAuth)", () => {
  beforeEach(() => {
    localStorage.clear();
    mockedLogin.mockReset();
    mockedMe.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("sem usuário logado: hasRole é sempre false, mesmo pedindo papel nenhum", async () => {
    render(
      <AuthProvider>
        <Probe rolesToCheck={["admin"]} />
      </AuthProvider>
    );
    await waitFor(() => expect(screen.getByTestId("loading")).toHaveTextContent("false"));
    expect(screen.getByTestId("hasRole")).toHaveTextContent("false");
  });

  it("usuário com um papel: true pro papel certo, false pra outro", async () => {
    api.setTokens("a", "r");
    mockedMe.mockResolvedValueOnce(makeUser(["professor"]));

    const { rerender } = render(
      <AuthProvider>
        <Probe rolesToCheck={["professor"]} />
      </AuthProvider>
    );
    await waitFor(() => expect(screen.getByTestId("hasRole")).toHaveTextContent("true"));

    // Mesmo AuthProvider (não remonta), só troca o papel que a sonda pede:
    // hasRole tem que recalcular e virar false, já que o usuário não é "admin".
    rerender(
      <AuthProvider>
        <Probe rolesToCheck={["admin"]} />
      </AuthProvider>
    );
    expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal");
    await waitFor(() => expect(screen.getByTestId("hasRole")).toHaveTextContent("false"));
  });

  it("usuário com múltiplos papéis: hasRole(...) é true se QUALQUER papel pedido bater (OR)", async () => {
    api.setTokens("a", "r");
    mockedMe.mockResolvedValueOnce(makeUser(["gerente", "professor"]));

    render(
      <AuthProvider>
        <Probe rolesToCheck={["admin", "professor"]} />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("hasRole")).toHaveTextContent("true"));
  });

  it("usuário logado mas nenhum papel pedido bate: false", async () => {
    api.setTokens("a", "r");
    mockedMe.mockResolvedValueOnce(makeUser(["recepcao"]));

    render(
      <AuthProvider>
        <Probe rolesToCheck={["admin", "gerente", "professor"]} />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));
    expect(screen.getByTestId("hasRole")).toHaveTextContent("false");
  });

  it("hasRole sem nenhum papel pedido (lista vazia): false (nada foi satisfeito)", async () => {
    api.setTokens("a", "r");
    mockedMe.mockResolvedValueOnce(makeUser(["admin"]));

    render(
      <AuthProvider>
        <Probe rolesToCheck={[]} />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("user")).toHaveTextContent("Fulano de Tal"));
    expect(screen.getByTestId("hasRole")).toHaveTextContent("false");
  });
});
