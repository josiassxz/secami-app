import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  api,
  ApiError,
  getAccessToken,
  getRefreshToken,
  login,
  setTokens,
} from "@/lib/api";

// BASE vem de import.meta.env.VITE_API_URL, que não está setado em teste,
// então cai no fallback definido em api.ts.
const BASE = "http://localhost:8080";

function jsonResponse(status: number, body?: unknown) {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function authHeader(init: RequestInit | undefined) {
  return (init?.headers as Record<string, string> | undefined)?.["Authorization"];
}

describe("api()", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("inclui o header Authorization quando há access token salvo", async () => {
    setTokens("access-1", "refresh-1");
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse(200, { ok: true }));

    const result = await api("/ping");

    expect(result).toEqual({ ok: true });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(authHeader(fetchSpy.mock.calls[0][1])).toBe("Bearer access-1");
  });

  it("não inclui Authorization quando não há token salvo", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse(200, { ok: true }));

    await api("/ping");

    expect(authHeader(fetchSpy.mock.calls[0][1])).toBeUndefined();
  });

  it(
    "fluxo completo de refresh: 401 -> refresh com sucesso -> repete a chamada " +
      "original com o novo token -> sucesso",
    async () => {
      setTokens("access-expirado", "refresh-valido");

      const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = String(input);
        if (url === `${BASE}/dados`) {
          const auth = authHeader(init);
          if (auth === "Bearer access-expirado") {
            return jsonResponse(401, { message: "token expirado" });
          }
          if (auth === "Bearer access-novo") {
            return jsonResponse(200, { valor: 42 });
          }
          throw new Error(`Authorization inesperado na chamada a /dados: ${auth}`);
        }
        if (url === `${BASE}/auth/refresh`) {
          expect(init?.method).toBe("POST");
          expect(JSON.parse(String(init?.body))).toEqual({ refreshToken: "refresh-valido" });
          return jsonResponse(200, { accessToken: "access-novo", refreshToken: "refresh-novo" });
        }
        throw new Error(`URL inesperada: ${url}`);
      });

      const result = await api<{ valor: number }>("/dados");

      expect(result).toEqual({ valor: 42 });
      // 1) chamada original (401) -> 2) refresh -> 3) repetição da chamada original (200)
      expect(fetchSpy).toHaveBeenCalledTimes(3);
      expect(getAccessToken()).toBe("access-novo");
      expect(getRefreshToken()).toBe("refresh-novo");
    }
  );

  it("quando o refresh falha (refresh token também inválido): limpa os tokens, avisa o app e propaga o erro 401 original", async () => {
    setTokens("access-expirado", "refresh-invalido");

    vi.spyOn(globalThis, "fetch").mockImplementation(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url === `${BASE}/dados`) return jsonResponse(401, { message: "token expirado" });
      if (url === `${BASE}/auth/refresh`) return jsonResponse(401, { message: "refresh inválido" });
      throw new Error(`URL inesperada: ${url}`);
    });

    const onExpired = vi.fn();
    window.addEventListener("secami:auth-expired", onExpired);
    try {
      await expect(api("/dados")).rejects.toMatchObject({ status: 401 });

      // Bug corrigido: antes os tokens velhos ficavam presos no localStorage
      // pra sempre, e nada avisava o resto do app que a sessão morreu.
      expect(getAccessToken()).toBeNull();
      expect(getRefreshToken()).toBeNull();
      expect(onExpired).toHaveBeenCalledTimes(1);
    } finally {
      window.removeEventListener("secami:auth-expired", onExpired);
    }
  });

  it("em 401 sem refresh token salvo: nem tenta chamar /auth/refresh, mas ainda limpa tokens e avisa o app", async () => {
    setTokens("access-expirado", "algo");
    localStorage.removeItem("secami.refresh");

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url === `${BASE}/dados`) return jsonResponse(401, {});
      throw new Error(`não deveria chamar: ${url}`);
    });

    const onExpired = vi.fn();
    window.addEventListener("secami:auth-expired", onExpired);
    try {
      await expect(api("/dados")).rejects.toBeInstanceOf(ApiError);

      expect(fetchSpy).toHaveBeenCalledTimes(1); // sem tentativa de refresh
      expect(getAccessToken()).toBeNull();
      expect(onExpired).toHaveBeenCalledTimes(1);
    } finally {
      window.removeEventListener("secami:auth-expired", onExpired);
    }
  });

  it("não tenta refresh de novo se a chamada repetida (pós-refresh) também voltar 401 (retry=false)", async () => {
    setTokens("access-expirado", "refresh-valido");

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url === `${BASE}/dados`) return jsonResponse(401, { message: "sem permissão" });
      if (url === `${BASE}/auth/refresh`) {
        return jsonResponse(200, { accessToken: "access-novo", refreshToken: "refresh-novo" });
      }
      throw new Error(`URL inesperada: ${url}`);
    });

    await expect(api("/dados")).rejects.toMatchObject({ status: 401 });

    // original (401) + refresh (200) + repetição (401, sem novo refresh) = 3
    expect(fetchSpy).toHaveBeenCalledTimes(3);
    // a sessão foi considerada morta depois da 2ª falha também
    expect(getAccessToken()).toBeNull();
  });

  it("erro de outros status (ex: 500) não mexe em token nenhum e propaga ApiError com a mensagem do backend", async () => {
    setTokens("access-1", "refresh-1");
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      jsonResponse(500, { message: "Erro interno" })
    );

    await expect(api("/dados")).rejects.toMatchObject({ status: 500, message: "Erro interno" });
    expect(getAccessToken()).toBe("access-1");
  });

  it("quando o corpo do erro não tem message/error, usa a mensagem padrão 'Erro <status>'", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(jsonResponse(404));

    await expect(api("/inexistente")).rejects.toMatchObject({ status: 404, message: "Erro 404" });
  });
});

describe("login()", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("em sucesso: chama /auth/login com usuário/senha e guarda os tokens retornados", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse(200, { accessToken: "a1", refreshToken: "r1" }));

    const data = await login("fulano", "senha123");

    expect(data).toEqual({ accessToken: "a1", refreshToken: "r1" });
    expect(getAccessToken()).toBe("a1");
    expect(getRefreshToken()).toBe("r1");
    expect(fetchSpy).toHaveBeenCalledWith(
      `${BASE}/auth/login`,
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ username: "fulano", password: "senha123" }),
      })
    );
  });

  it("em credenciais inválidas: lança ApiError com a mensagem do backend e não grava tokens", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      jsonResponse(401, { message: "Usuário ou senha inválidos" })
    );

    await expect(login("fulano", "errada")).rejects.toMatchObject({
      status: 401,
      message: "Usuário ou senha inválidos",
    });
    expect(getAccessToken()).toBeNull();
    expect(getRefreshToken()).toBeNull();
  });
});
