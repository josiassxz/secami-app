import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { MutationCache, QueryCache, QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider } from "@/lib/auth";
import App from "./App";
import ErrorBoundary from "@/components/ErrorBoundary";
import Toaster from "@/components/Toaster";
import { ApiError, mensagemDeErro } from "@/lib/erros";
import { toast } from "@/lib/toast";
import "./index.css";

// Rede de proteção global: falha de carregamento ou de ação sem tratamento
// próprio vira um aviso legível — nunca fica silenciosa e nunca mostra
// mensagem técnica (SyntaxError de JSON, "Failed to fetch"...).
const queryClient = new QueryClient({
  queryCache: new QueryCache({
    onError: (error) => {
      // 401 = sessão expirada: o AuthProvider já redireciona pro login.
      if (error instanceof ApiError && error.status === 401) return;
      toast("error", mensagemDeErro(error, "Não foi possível carregar os dados."));
    },
  }),
  mutationCache: new MutationCache({
    onError: (error, _vars, _ctx, mutation) => {
      // Mutations que já mostram o erro na própria tela (onError próprio)
      // não duplicam o aviso.
      if (mutation.options.onError) return;
      if (error instanceof ApiError && error.status === 401) return;
      toast("error", mensagemDeErro(error, "Não foi possível concluir a ação."));
    },
  }),
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
});

// Promise rejeitada sem catch (ex.: handler async de botão): registra no
// console e avisa de forma genérica em vez de falhar em silêncio.
window.addEventListener("unhandledrejection", (e) => {
  console.error("[unhandledrejection]", e.reason);
  toast("error", mensagemDeErro(e.reason));
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <AuthProvider>
            <App />
          </AuthProvider>
        </BrowserRouter>
        <Toaster />
      </QueryClientProvider>
    </ErrorBoundary>
  </React.StrictMode>
);
