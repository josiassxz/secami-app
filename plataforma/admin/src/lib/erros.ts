// Erros de API e o texto seguro pra exibi-los. Módulo separado de api.ts pra
// que as telas possam usar `mensagemDeErro` sem depender do cliente HTTP (e
// pra que testes que mockam "@/lib/api" continuem com o comportamento real).

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const MSG_CONEXAO =
  "Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.";
export const MSG_GENERICA = "Algo deu errado. Tente novamente em instantes.";
export const MSG_RESPOSTA_INESPERADA =
  "O servidor devolveu uma resposta inesperada. Tente novamente em instantes.";

export function mensagemPadraoPorStatus(status: number): string {
  if (status === 401) return "Sessão expirada. Faça login novamente.";
  if (status === 403) return "Você não tem permissão para esta ação.";
  if (status === 404) return "Recurso não encontrado.";
  if (status >= 500) return "Servidor indisponível no momento. Tente novamente em instantes.";
  return "Não foi possível completar a operação. Tente novamente.";
}

/** Texto seguro pra mostrar ao usuário a partir de QUALQUER erro capturado.
 *  Só `ApiError` carrega mensagem já tratada (do backend ou montada aqui);
 *  qualquer outra coisa — SyntaxError de JSON, TypeError "Failed to fetch",
 *  erro de render etc. — é detalhe técnico e vira `fallback`. */
export function mensagemDeErro(err: unknown, fallback: string = MSG_GENERICA): string {
  if (err instanceof ApiError && err.message.trim()) return err.message;
  return fallback;
}

