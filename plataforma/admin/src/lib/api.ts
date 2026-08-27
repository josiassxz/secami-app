// Cliente HTTP com JWT (access + refresh). SPEC §9.2.
const BASE = (import.meta.env.VITE_API_URL as string) || "http://localhost:8080";

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

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function parse(res: Response) {
  const text = await res.text();
  const body = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const msg = body?.message || body?.error || `Erro ${res.status}`;
    throw new ApiError(res.status, msg);
  }
  return body;
}

async function tryRefresh(): Promise<boolean> {
  const refresh = getRefreshToken();
  if (!refresh) return false;
  const res = await fetch(`${BASE}/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: refresh }),
  });
  if (!res.ok) return false;
  const data = await res.json();
  setTokens(data.accessToken, data.refreshToken);
  return true;
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

  const res = await fetch(`${BASE}${path}`, { ...options, headers });

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
  const res = await fetch(`${BASE}/auth/login`, {
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

  const res = await fetch(`${BASE}/media/${id}`, { headers });

  if (res.status === 401) {
    if (retry && (await tryRefresh())) {
      return downloadMedia(id, false);
    }
    clearTokens();
    window.dispatchEvent(new Event("secami:auth-expired"));
  }
  if (!res.ok) {
    let msg = `Erro ${res.status}`;
    try {
      const body = await res.json();
      msg = body?.message || body?.error || msg;
    } catch {
      // corpo não é JSON (ex.: resposta vazia) — mantém a mensagem padrão
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
  studentType: "Civil" | "Militar";
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
