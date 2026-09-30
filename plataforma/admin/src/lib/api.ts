// Cliente HTTP com JWT (access + refresh). SPEC §9.2.
// `??` (não `||`): VITE_API_URL="" é um valor válido — faz as chamadas caírem
// em path relativo (mesma origem da página, via proxy do nginx pro backend),
// o que evita mixed content quando a página é servida em HTTPS mas ainda
// precisaria falar com o backend em HTTP puro por IP.
const BASE = (import.meta.env.VITE_API_URL as string) ?? "http://localhost:8080";

import {
  ApiError,
  MSG_CONEXAO,
  MSG_RESPOSTA_INESPERADA,
  mensagemPadraoPorStatus,
} from "./erros";

// Reexporta pra manter `import { ApiError } from "@/lib/api"` funcionando.
export { ApiError, mensagemDeErro, MSG_CONEXAO, MSG_GENERICA } from "./erros";

const ACCESS_KEY = "secami.access";
const REFRESH_KEY = "secami.refresh";

export function getAccessToken() {
  return localStorage.getItem(ACCESS_KEY);
}
export function getRefreshToken() {
  return localStorage.getItem(REFRESH_KEY);
}
export function setTokens(access: string, refresh: string) {
  localStorage.setItem(ACCESS_KEY, access);
  localStorage.setItem(REFRESH_KEY, refresh);
}
export function clearTokens() {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

/** fetch que nunca deixa a exceção crua do navegador ("Failed to fetch",
 *  "Load failed", "NetworkError...") chegar na UI. */
async function fetchSeguro(input: string, init?: RequestInit): Promise<Response> {
  try {
    return await fetch(input, init);
  } catch {
    throw new ApiError(0, MSG_CONEXAO);
  }
}

async function parse(res: Response) {
  // O corpo pode não ser JSON (página HTML de erro do nginx/gateway, texto
  // simples do Spring como "Invalid CORS request", SPA fallback devolvendo
  // index.html com 200...). JSON.parse direto vazava "Unexpected token '<',
  // "<!DOCTYPE "... is not valid JSON" pra tela.
  const text = await res.text();
  let body: any = null;
  let corpoInvalido = false;
  if (text.trim()) {
    try {
      body = JSON.parse(text);
    } catch {
      corpoInvalido = true;
    }
  }
  if (!res.ok) {
    const bruto = body?.message ?? body?.error;
    const msg =
      typeof bruto === "string" && bruto.trim() ? bruto : mensagemPadraoPorStatus(res.status);
    throw new ApiError(res.status, msg);
  }
  // 2xx com corpo não-JSON = algo (proxy/SPA) respondeu no lugar da API.
  if (corpoInvalido) throw new ApiError(res.status, MSG_RESPOSTA_INESPERADA);
  return body;
}

async function tryRefresh(): Promise<boolean> {
  const refresh = getRefreshToken();
  if (!refresh) return false;
  try {
    const res = await fetch(`${BASE}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: refresh }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    if (!data?.accessToken || !data?.refreshToken) return false;
    setTokens(data.accessToken, data.refreshToken);
    return true;
  } catch {
    // Rede fora do ar ou resposta que não é JSON: trata como "não deu pra
    // renovar" (o chamador cai no fluxo normal de sessão expirada).
    return false;
  }
}

export async function api<T = any>(
  path: string,
  options: RequestInit = {},
  retry = true
): Promise<T> {
  const headers: Record<string, string> = {
    ...(options.headers as Record<string, string>),
  };
  if (options.body && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  const token = getAccessToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetchSeguro(`${BASE}${path}`, { ...options, headers });

  if (res.status === 401) {
    if (retry && (await tryRefresh())) {
      return api<T>(path, options, false);
    }
    // Refresh ausente/expirado/inválido (ou a chamada repetida com o token
    // novo ainda voltou 401): a sessão não é mais válida. Limpa os tokens
    // velhos pra não ficar retentando refresh indefinidamente e avisa o
    // resto do app (AuthProvider) pra forçar logout/redirect imediato.
    clearTokens();
    window.dispatchEvent(new Event("secami:auth-expired"));
  }
  return parse(res);
}

// ---- Auth ----
export async function login(email: string, password: string) {
  const res = await fetchSeguro(`${BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await parse(res);
  setTokens(data.accessToken, data.refreshToken);
  return data;
}

export type Me = {
  id: string;
  samAccountName: string;
  nome: string;
  email: string;
  roles: string[];
};

export function me() {
  return api<Me>("/me");
}

// ---- Mídia (arquivos autenticados: atestado médico, foto, etc.) ----
/** Baixa um arquivo protegido (ex.: atestado médico) como Blob, incluindo o
 *  header Authorization — esses endpoints não podem ser usados num <a href>
 *  puro porque exigem token. Reaproveita a mesma lógica de retry-após-refresh
 *  usada em `api()`. */
export async function downloadMedia(id: string, retry = true): Promise<Blob> {
  const token = getAccessToken();
  const headers: Record<string, string> = {};
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetchSeguro(`${BASE}/media/${id}`, { headers });

  if (res.status === 401) {
    if (retry && (await tryRefresh())) {
      return downloadMedia(id, false);
    }
    clearTokens();
    window.dispatchEvent(new Event("secami:auth-expired"));
  }
  if (!res.ok) {
    let msg = mensagemPadraoPorStatus(res.status);
    try {
      const body = await res.json();
      const bruto = body?.message ?? body?.error;
      if (typeof bruto === "string" && bruto.trim()) msg = bruto;
    } catch {
      // corpo não é JSON (ex.: resposta vazia/HTML) — mantém a mensagem padrão
    }
    throw new ApiError(res.status, msg);
  }
  return res.blob();
}

// ---- Cadastros pendentes (auto-cadastro público aguardando aprovação) ----
export type PendingRegistration = {
  studentId: string;
  fullName: string;
  cpf: string;
  email: string;
  phone: string;
  studentType: "Civil" | "Militar" | "Instrutor";
  birthDate: string;
  weightKg: number | null;
  heightCm: number | null;
  objetivos: string[];
  departmentName: string;
  parQ: Record<string, boolean>;
  termoResponsabilidadeAceitoEm: string;
  termoCienciaAceitoEm: string;
  medicoNome: string;
  medicoCrm: string;
  medicoCrmUf: string;
  atestadoEmissaoData: string;
  atestadoArquivoId: string;
  createdAt: string;
};
