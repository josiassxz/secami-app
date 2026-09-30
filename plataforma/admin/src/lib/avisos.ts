// Regras de exibição dos avisos (período + ativo), usadas pela tela Avisos do admin.

export type Aviso = {
  id: string;
  title: string;
  content: string;
  type: string;
  active: boolean;
  targetRoles?: string[];
  exibirDe?: string | null;
  exibirAte?: string | null;
};

/** Hoje no fuso local do navegador, em AAAA-MM-DD (mesmo formato das datas do aviso). */
function hojeIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** Situação do aviso hoje, considerando ativo + período de exibição (datas inclusive). */
export function situacaoDoAviso(n: Aviso, hoje = hojeIso()): { rotulo: string; tom: string } {
  if (!n.active) return { rotulo: "Inativo", tom: "cancelado" };
  if (n.exibirDe && hoje < n.exibirDe) return { rotulo: "Agendado", tom: "info" };
  if (n.exibirAte && hoje > n.exibirAte) return { rotulo: "Encerrado", tom: "neutral" };
  return { rotulo: "Em exibição", tom: "success" };
}
