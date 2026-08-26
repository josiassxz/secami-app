import { cn } from "@/lib/utils";
import { Loader2, ArrowUpRight } from "lucide-react";
import { Link } from "react-router-dom";
import {
  type ButtonHTMLAttributes,
  type HTMLAttributes,
  type InputHTMLAttributes,
  type LabelHTMLAttributes,
  type SelectHTMLAttributes,
  type TdHTMLAttributes,
  type ThHTMLAttributes,
  type TextareaHTMLAttributes,
  forwardRef,
} from "react";

type Variant = "brand" | "outline" | "ghost" | "danger" | "gold";
type Size = "sm" | "md";

const btnVariants: Record<Variant, string> = {
  brand: "bg-brand text-brand-fg hover:bg-brand-hover active:brightness-95 shadow-1",
  gold: "bg-gold text-gold-fg hover:brightness-95 active:brightness-90 shadow-1",
  outline: "border border-line bg-surface text-content hover:bg-surface-alt active:bg-surface-alt",
  ghost: "text-content-soft hover:bg-surface-alt hover:text-content active:bg-surface-alt",
  danger: "bg-danger text-white hover:brightness-95 active:brightness-90 shadow-1",
};
const btnSizes: Record<Size, string> = {
  sm: "h-8 px-3 text-sm rounded-md",
  md: "h-10 px-4 text-sm rounded-md",
};

export function Button({
  className,
  variant = "brand",
  size = "md",
  loading,
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
}) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 font-medium transition-all duration-fast ease-standard active:scale-[.98] disabled:opacity-50 disabled:pointer-events-none disabled:shadow-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/50 focus-visible:ring-offset-2 focus-visible:ring-offset-surface",
        btnVariants[variant],
        btnSizes[size],
        className
      )}
      disabled={loading || props.disabled}
      {...props}
    >
      {loading && <Loader2 className="h-4 w-4 animate-spin" />}
      {children}
    </button>
  );
}

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "h-10 w-full rounded-md border border-line-input bg-surface px-3 text-sm text-content placeholder:text-content-faint outline-none transition-colors duration-fast hover:border-brand focus:border-brand/50 focus:ring-2 focus:ring-brand/25 disabled:cursor-not-allowed disabled:border-line disabled:bg-surface-alt disabled:text-content-faint disabled:hover:border-line",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...props }, ref) => (
    <textarea
      ref={ref}
      className={cn(
        "min-h-[90px] w-full rounded-md border border-line-input bg-surface px-3 py-2 text-sm text-content placeholder:text-content-faint outline-none transition-colors duration-fast hover:border-brand focus:border-brand/50 focus:ring-2 focus:ring-brand/25 disabled:cursor-not-allowed disabled:border-line disabled:bg-surface-alt disabled:text-content-faint disabled:hover:border-line",
        className
      )}
      {...props}
    />
  )
);
Textarea.displayName = "Textarea";

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, children, ...props }, ref) => (
    <select
      ref={ref}
      className={cn(
        "h-10 w-full rounded-md border border-line-input bg-surface px-3 text-sm text-content outline-none transition-colors duration-fast hover:border-brand focus:border-brand/50 focus:ring-2 focus:ring-brand/25 disabled:cursor-not-allowed disabled:border-line disabled:bg-surface-alt disabled:text-content-faint disabled:hover:border-line",
        className
      )}
      {...props}
    >
      {children}
    </select>
  )
);
Select.displayName = "Select";

export function Label({ className, ...props }: LabelHTMLAttributes<HTMLLabelElement>) {
  return (
    <label
      className={cn("mb-1 block text-sm font-medium text-content-soft", className)}
      {...props}
    />
  );
}

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("rounded-lg border border-line bg-surface shadow-1", className)}
      {...props}
    />
  );
}
export function CardHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("p-5 pb-2", className)} {...props} />;
}
export function CardTitle({ className, ...props }: HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={cn("text-lg font-semibold text-content", className)} {...props} />;
}
export function CardContent({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("p-5 pt-2", className)} {...props} />;
}

const badgeStyles: Record<string, string> = {
  agendado: "bg-info/15 text-info",
  confirmado: "bg-success/15 text-success",
  faltou: "bg-danger/15 text-danger",
  cancelado: "bg-surface-alt text-content-soft",
  info: "bg-info/15 text-info",
  warning: "bg-warning/15 text-warning",
  success: "bg-success/15 text-success",
  neutral: "bg-surface-alt text-content-soft",
};
export function Badge({ tone = "neutral", children }: { tone?: string; children: React.ReactNode }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
        badgeStyles[tone] || badgeStyles.neutral
      )}
    >
      {children}
    </span>
  );
}

/** Avatar com iniciais (usado em listas de pessoas). */
export function Avatar({ name, className }: { name: string; className?: string }) {
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
  return (
    <span
      className={cn(
        "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-container text-xs font-bold text-brand",
        className
      )}
    >
      {initials || "?"}
    </span>
  );
}

/** Tile de acesso rápido (grade verde-limão + selo dourado — referência visual). */
export function QuickLinkCard({
  icon: Icon,
  label,
  to,
}: {
  icon: any;
  label: string;
  to: string;
}) {
  return (
    <Link
      to={to}
      className="group flex min-h-[132px] flex-col justify-between rounded-lg bg-lime p-4 text-lime-fg shadow-1 transition-all duration-fast ease-standard hover:shadow-2 hover:-translate-y-0.5 active:scale-[.98] active:shadow-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/50 focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
    >
      <span className="flex h-9 w-9 items-center justify-center rounded-full bg-gold text-gold-fg shadow-sm">
        <ArrowUpRight className="h-4 w-4" />
      </span>
      <span className="flex items-end justify-between gap-2">
        <span className="text-sm font-bold leading-snug">{label}</span>
        <Icon className="h-6 w-6 shrink-0 opacity-40" />
      </span>
    </Link>
  );
}

export function Spinner() {
  return (
    <div className="flex items-center justify-center py-10 text-content-soft">
      <Loader2 className="h-6 w-6 animate-spin" />
    </div>
  );
}

/** Bloco de carregamento (skeleton). */
export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("animate-pulse rounded-md bg-surface-alt", className)} />;
}

export function TableSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="space-y-2 p-4">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-3">
          <Skeleton className="h-8 w-8 rounded-full" />
          <Skeleton className="h-4 flex-1" />
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-4 w-16" />
        </div>
      ))}
    </div>
  );
}

/** Barra de progresso/ocupação. */
export function Meter({
  value,
  max,
  tone = "brand",
}: {
  value: number;
  max: number;
  tone?: "brand" | "warning" | "danger";
}) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
  const color =
    tone === "danger" ? "bg-danger" : tone === "warning" ? "bg-warning" : "bg-brand";
  return (
    <div className="h-2 w-full overflow-hidden rounded-full bg-surface-alt">
      <div
        className={cn("h-full rounded-full transition-all", color)}
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

// ---- Tabela ----
export function Table({ className, ...props }: HTMLAttributes<HTMLTableElement>) {
  return (
    <div className="w-full overflow-x-auto rounded-lg">
      <table className={cn("w-full text-sm", className)} {...props} />
    </div>
  );
}
export function THead({ className, ...props }: HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <thead
      className={cn("bg-surface-alt/70 text-left text-content-soft", className)}
      {...props}
    />
  );
}
export function TBody({ className, ...props }: HTMLAttributes<HTMLTableSectionElement>) {
  return <tbody className={className} {...props} />;
}
export function TH({ className, ...props }: ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th
      className={cn(
        "whitespace-nowrap px-4 py-3 text-xs font-semibold uppercase tracking-wider",
        className
      )}
      {...props}
    />
  );
}
export function TR({ className, ...props }: HTMLAttributes<HTMLTableRowElement>) {
  return (
    <tr
      className={cn(
        "border-b border-line/60 transition-colors duration-fast last:border-0 hover:bg-surface-alt/50",
        className
      )}
      {...props}
    />
  );
}
export function TD({ className, ...props }: TdHTMLAttributes<HTMLTableCellElement>) {
  return <td className={cn("px-4 py-3 text-content", className)} {...props} />;
}
