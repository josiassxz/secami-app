import { Component, type ErrorInfo, type ReactNode } from "react";
import { Button } from "@/components/ui";

type Props = { children: ReactNode };
type State = { falhou: boolean };

/** Última rede de proteção: um erro de render em qualquer tela troca a página
 *  em branco do React por um aviso legível — sem stack, sem mensagem técnica
 *  (o detalhe vai pro console, pra quem for depurar). */
export default class ErrorBoundary extends Component<Props, State> {
  state: State = { falhou: false };

  static getDerivedStateFromError(): State {
    return { falhou: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("[ErrorBoundary]", error, info.componentStack);
  }

  render() {
    if (!this.state.falhou) return this.props.children;
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface-alt p-6">
        <div className="w-full max-w-md rounded-xl border border-line bg-surface p-8 text-center shadow-2">
          <h1 className="text-lg font-semibold text-content">Algo deu errado nesta tela</h1>
          <p className="mt-2 text-sm text-content-soft">
            Não foi possível exibir esta página. Recarregue e tente novamente. Se o problema
            continuar, avise o suporte da Academia SECAMI.
          </p>
          <div className="mt-6 flex justify-center gap-3">
            <Button variant="outline" onClick={() => (window.location.href = "/")}>
              Ir para o início
            </Button>
            <Button onClick={() => window.location.reload()}>Recarregar</Button>
          </div>
        </div>
      </div>
    );
  }
}
