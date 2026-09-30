import { useEffect, useState } from "react";
import { AlertCircle, CheckCircle2, Info, X } from "lucide-react";
import { onToast, type ToastDetail } from "@/lib/toast";
import { cn } from "@/lib/utils";

type Item = ToastDetail & { id: number };

const ICONES = { error: AlertCircle, success: CheckCircle2, info: Info } as const;
const ESTILOS = {
  error: "border-danger/40 bg-surface text-content [&_svg:first-child]:text-danger",
  success: "border-brand/40 bg-surface text-content [&_svg:first-child]:text-brand",
  info: "border-line bg-surface text-content [&_svg:first-child]:text-content-soft",
} as const;

let seq = 0;

/** Renderiza os toasts globais (ver lib/toast.ts). Montar uma vez, no topo. */
export default function Toaster() {
  const [items, setItems] = useState<Item[]>([]);

  useEffect(
    () =>
      onToast((d) => {
        const id = ++seq;
        setItems((prev) => [...prev.slice(-2), { ...d, id }]);
        window.setTimeout(() => setItems((prev) => prev.filter((i) => i.id !== id)), 6000);
      }),
    []
  );

  if (items.length === 0) return null;
  return (
    <div
      role="region"
      aria-label="Notificações"
      className="pointer-events-none fixed inset-x-0 top-4 z-[100] flex flex-col items-center gap-2 px-4"
    >
      {items.map((i) => {
        const Icone = ICONES[i.type];
        return (
          <div
            key={i.id}
            role={i.type === "error" ? "alert" : "status"}
            className={cn(
              "pointer-events-auto flex w-full max-w-md items-start gap-3 rounded-lg border px-4 py-3 text-sm shadow-2",
              ESTILOS[i.type]
            )}
          >
            <Icone className="mt-0.5 h-4 w-4 shrink-0" />
            <span className="flex-1">{i.text}</span>
            <button
              type="button"
              aria-label="Fechar"
              className="text-content-soft hover:text-content"
              onClick={() => setItems((prev) => prev.filter((x) => x.id !== i.id))}
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        );
      })}
    </div>
  );
}
