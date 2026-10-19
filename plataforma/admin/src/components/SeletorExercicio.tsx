import { useEffect, useId, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

export type OpcaoExercicio = { id: string; name: string };

/** Compara sem acento e sem caixa ("supino" acha "Supino reto", "rosca" acha "Rosca"). */
function normalizar(texto: string) {
  return texto.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().trim();
}

/**
 * Select de exercício do catálogo com filtro por nome: abre a lista inteira
 * (agrupada por grupo muscular), e o que for digitado vai filtrando. Teclado:
 * setas, Enter escolhe, Esc fecha.
 */
export function SeletorExercicio({
  rotulo,
  valor,
  nomeAtual,
  grupos,
  carregando,
  invalido,
  onEscolher,
}: {
  rotulo: string;
  /** id do exercício escolhido ("" = nenhum). */
  valor: string;
  /** Nome mostrado no campo (inclui o caso "fora do catálogo"). */
  nomeAtual: string;
  grupos: readonly (readonly [string, readonly OpcaoExercicio[]])[];
  carregando?: boolean;
  invalido?: boolean;
  onEscolher: (id: string) => void;
}) {
  const [aberto, setAberto] = useState(false);
  const [busca, setBusca] = useState<string | null>(null);
  const [ativo, setAtivo] = useState(0);
  const listaId = useId();
  const raiz = useRef<HTMLDivElement>(null);

  const filtrados = useMemo(() => {
    const termo = normalizar(busca ?? "");
    return grupos
      .map(([grupo, lista]) => [grupo, termo ? lista.filter((e) => normalizar(e.name).includes(termo)) : lista] as const)
      .filter(([, lista]) => lista.length > 0);
  }, [grupos, busca]);
  const planos = useMemo(() => filtrados.flatMap(([, lista]) => lista), [filtrados]);

  useEffect(() => {
    if (!aberto) return;
    function fora(e: MouseEvent) {
      if (raiz.current && !raiz.current.contains(e.target as Node)) fechar();
    }
    document.addEventListener("mousedown", fora);
    return () => document.removeEventListener("mousedown", fora);
  }, [aberto]);

  function abrir() {
    setAberto(true);
    setAtivo(Math.max(0, planos.findIndex((e) => e.id === valor)));
  }
  function fechar() {
    setAberto(false);
    setBusca(null);
  }
  function escolher(e: OpcaoExercicio) {
    onEscolher(e.id);
    fechar();
  }

  function onKeyDown(ev: React.KeyboardEvent<HTMLInputElement>) {
    if (ev.key === "ArrowDown") {
      ev.preventDefault();
      if (!aberto) abrir();
      else setAtivo((i) => Math.min(i + 1, planos.length - 1));
    } else if (ev.key === "ArrowUp") {
      ev.preventDefault();
      setAtivo((i) => Math.max(i - 1, 0));
    } else if (ev.key === "Enter") {
      if (aberto && planos[ativo]) {
        ev.preventDefault();
        escolher(planos[ativo]);
      }
    } else if (ev.key === "Escape") {
      if (aberto) {
        ev.preventDefault();
        ev.stopPropagation(); // não fecha o modal da ficha
        fechar();
      }
    }
  }

  const texto = busca ?? nomeAtual;
  let indice = -1;

  return (
    <div ref={raiz}>
      <div className="relative">
      <input
        type="text"
        role="combobox"
        aria-label={rotulo}
        aria-expanded={aberto}
        aria-controls={listaId}
        aria-autocomplete="list"
        aria-invalid={invalido || undefined}
        autoComplete="off"
        placeholder={carregando ? "Carregando exercícios…" : "Selecione ou digite para buscar"}
        value={texto}
        onFocus={abrir}
        onClick={() => !aberto && abrir()}
        onChange={(e) => {
          setBusca(e.target.value);
          setAberto(true);
          setAtivo(0);
        }}
        onKeyDown={onKeyDown}
        className={cn(
          "h-10 w-full rounded-md border bg-surface pl-3 pr-9 text-sm text-content placeholder:text-content-faint",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
          invalido ? "border-danger" : "border-line"
        )}
      />
      <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-soft" />
      </div>
      {aberto && (
        <div
          id={listaId}
          role="listbox"
          aria-label={rotulo}
          className="mt-1 max-h-64 w-full overflow-y-auto rounded-md border border-line bg-surface py-1 shadow-1"
        >
          {planos.length === 0 ? (
            <div className="px-3 py-2 text-sm text-content-soft">
              {carregando ? "Carregando exercícios…" : "Nenhum exercício com esse nome."}
            </div>
          ) : (
            filtrados.map(([grupo, lista]) => (
              <div key={grupo} role="group" aria-label={grupo}>
                <div className="px-3 pb-1 pt-2 text-[11px] font-semibold uppercase tracking-wide text-content-faint">
                  {grupo}
                </div>
                {lista.map((e) => {
                  indice += 1;
                  const i = indice;
                  return (
                    <div
                      key={e.id}
                      role="option"
                      aria-selected={e.id === valor}
                      onMouseDown={(ev) => {
                        ev.preventDefault(); // mantém o foco no campo
                        escolher(e);
                      }}
                      onMouseEnter={() => setAtivo(i)}
                      className={cn(
                        "cursor-pointer px-3 py-1.5 text-sm text-content",
                        i === ativo && "bg-surface-alt",
                        e.id === valor && "font-semibold text-brand"
                      )}
                    >
                      {e.name}
                    </div>
                  );
                })}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}
