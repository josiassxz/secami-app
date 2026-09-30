// Toast global mínimo (event-based, sem dependência). Usado pelos handlers
// globais de erro (QueryCache/MutationCache/unhandledrejection) pra que uma
// falha nunca fique silenciosa nem chegue crua na tela.

export type ToastDetail = { type: "error" | "success" | "info"; text: string };

const EVENTO = "secami:toast";
const JANELA_DEDUPE_MS = 4000;
let ultimo: { text: string; at: number } | null = null;

export function toast(type: ToastDetail["type"], text: string) {
  // Várias queries falhando ao mesmo tempo (ex.: backend fora do ar) geram
  // a mesma mensagem N vezes — mostra uma só.
  const agora = Date.now();
  if (ultimo && ultimo.text === text && agora - ultimo.at < JANELA_DEDUPE_MS) return;
  ultimo = { text, at: agora };
  window.dispatchEvent(new CustomEvent<ToastDetail>(EVENTO, { detail: { type, text } }));
}

export function onToast(handler: (d: ToastDetail) => void): () => void {
  const listener = (e: Event) => handler((e as CustomEvent<ToastDetail>).detail);
  window.addEventListener(EVENTO, listener);
  return () => window.removeEventListener(EVENTO, listener);
}
