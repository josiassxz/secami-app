// Rótulos dos papéis (RBAC) como aparecem pro usuário. A chave `professor` é
// a do backend; na interface o perfil se chama "Instrutor".
const ROTULOS: Record<string, string> = {
  admin: "Admin",
  gerente: "Gerente",
  recepcao: "Recepção",
  professor: "Instrutor",
  aluno: "Aluno",
};

export function rotuloPapel(papel: string): string {
  return ROTULOS[papel] ?? papel;
}

/** Tom do selo de tipo de cadastro na lista de alunos. */
export function tomDoTipo(tipo: string): string {
  if (tipo === "Instrutor") return "success";
  if (tipo === "VIP") return "vip";
  if (tipo === "Lutas") return "lutas";
  return tipo === "Militar" ? "warning" : "info";
}

/** Rótulo do tipo na listagem: Lutas mostra a turma ("Lutas · Fem"). */
export function rotuloDoTipo(tipo: string, turmaLutas?: string | null): string {
  if (tipo !== "Lutas" || !turmaLutas) return tipo;
  return `Lutas · ${turmaLutas === "FEMININO" ? "Fem" : "Masc"}`;
}
