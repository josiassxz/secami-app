import { X } from "lucide-react";
import { type ReactNode, useEffect } from "react";

export function Modal({
  open,
  onClose,
  title,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  /** Largura máxima: md (padrão, formulários curtos) ou xl (editores com lista). */
  size?: "md" | "xl";
}) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    if (open) document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div
        role="dialog"
        aria-label={title}
        className={`relative z-10 w-full ${size === "xl" ? "max-w-4xl" : "max-w-lg"} overflow-hidden rounded-lg border border-line bg-surface shadow-xl`}
      >
        <div className="flex items-center justify-between border-b border-line px-5 py-3">
          <h3 className="font-semibold text-content">{title}</h3>
          <button onClick={onClose} className="text-content-soft hover:text-content">
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="max-h-[70vh] overflow-y-auto px-5 py-4">{children}</div>
        {footer && (
          <div className="flex justify-end gap-2 border-t border-line px-5 py-3">{footer}</div>
        )}
      </div>
    </div>
  );
}
