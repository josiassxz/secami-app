import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { api, ApiError, mensagemDeErro, MSG_CONEXAO, MSG_GENERICA } from "@/lib/api";

const HTML = '<!DOCTYPE html><html><body><h1>502 Bad Gateway</h1></body></html>';

function htmlResponse(status: number) {
  return new Response(HTML, { status, headers: { "Content-Type": "text/html" } });
}

async function falha(chamada: () => Promise<unknown>): Promise<ApiError> {
  try {
    await chamada();
  } catch (e) {
    expect(e).toBeInstanceOf(ApiError);
    return e as ApiError;
  }
  throw new Error("esperava ApiError");
}

describe("api() — erros nunca chegam técnicos na tela", () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => vi.restoreAllMocks());

  it('502 com HTML não vaza "Unexpected token \'<\'" — vira mensagem de servidor', async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(htmlResponse(502));
    const e = await falha(() => api("/x"));
    expect(e.status).toBe(502);
    expect(e.message).toMatch(/Servidor indisponível/);
    expect(e.message).not.toMatch(/Unexpected token|DOCTYPE|JSON/);
  });

  it("200 com HTML (SPA/proxy respondendo no lugar da API) vira resposta inesperada", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(htmlResponse(200));
    const e = await falha(() => api("/x"));
    expect(e.message).toMatch(/resposta inesperada/);
    expect(e.message).not.toMatch(/Unexpected token|DOCTYPE/);
  });

  it("falha de rede vira mensagem de conexão (sem 'Failed to fetch')", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValueOnce(new TypeError("Failed to fetch"));
    const e = await falha(() => api("/x"));
    expect(e.status).toBe(0);
    expect(e.message).toBe(MSG_CONEXAO);
  });

  it("404 com texto puro usa a mensagem padrão do status", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(new Response("Not Found", { status: 404 }));
    const e = await falha(() => api("/x"));
    expect(e.message).toBe("Recurso não encontrado.");
  });

  it('"message" que não é string cai na mensagem padrão', async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ message: { a: 1 } }), { status: 400 })
    );
    const e = await falha(() => api("/x"));
    expect(e.message).toBe("Não foi possível completar a operação. Tente novamente.");
  });

  it("mensagem do backend é preservada", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ message: "Horário cheio." }), { status: 409 })
    );
    const e = await falha(() => api("/x"));
    expect(e.message).toBe("Horário cheio.");
  });

  it("corpo vazio com 204 continua sendo sucesso (null)", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(new Response(null, { status: 204 }));
    expect(await api("/x", { method: "DELETE" })).toBeNull();
  });

  it("refresh que falha por rede não estoura — cai no fluxo de sessão expirada", async () => {
    localStorage.setItem("secami.access", "a");
    localStorage.setItem("secami.refresh", "r");
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(new Response("{}", { status: 401 })) // chamada original
      .mockRejectedValueOnce(new TypeError("Failed to fetch")); // refresh
    const e = await falha(() => api("/x"));
    expect(e.status).toBe(401);
    expect(localStorage.getItem("secami.access")).toBeNull();
  });
});

describe("mensagemDeErro", () => {
  it("usa a mensagem de ApiError", () => {
    expect(mensagemDeErro(new ApiError(409, "Já existe."))).toBe("Já existe.");
  });

  it("qualquer outro erro vira fallback, nunca o message técnico", () => {
    const tecnico = new SyntaxError('Unexpected token \'<\', "<!DOCTYPE "... is not valid JSON');
    expect(mensagemDeErro(tecnico)).toBe(MSG_GENERICA);
    expect(mensagemDeErro(tecnico, "Falhou ao salvar.")).toBe("Falhou ao salvar.");
    expect(mensagemDeErro(undefined)).toBe(MSG_GENERICA);
  });
});
