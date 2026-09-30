import { afterEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import ErrorBoundary from "@/components/ErrorBoundary";

function Quebra(): never {
  throw new SyntaxError('Unexpected token \'<\', "<!DOCTYPE "... is not valid JSON');
}

describe("ErrorBoundary", () => {
  afterEach(() => vi.restoreAllMocks());

  it("mostra aviso amigável, sem a mensagem técnica, quando um filho quebra no render", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    render(
      <ErrorBoundary>
        <Quebra />
      </ErrorBoundary>
    );
    expect(screen.getByText("Algo deu errado nesta tela")).toBeInTheDocument();
    expect(screen.queryByText(/Unexpected token/)).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Recarregar" })).toBeInTheDocument();
  });

  it("renderiza os filhos normalmente quando não há erro", () => {
    render(
      <ErrorBoundary>
        <p>tudo certo</p>
      </ErrorBoundary>
    );
    expect(screen.getByText("tudo certo")).toBeInTheDocument();
  });
});
