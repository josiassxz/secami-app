// Tipos e regras das fichas de treino (A–D) usados pela tela "Fichas de
// Treino" e pelo editor. Espelham o contrato de /workout-plans do backend
// (campos nulos são omitidos na resposta).

export const ROTULOS_FICHA = ["A", "B", "C", "D"] as const;

export type ExercicioDaFicha = {
  exerciseId?: string | null;
  exerciseName?: string | null;
  ordem?: number;
  sets?: number | null;
  reps?: string | null;
  restSeconds?: number | null;
  notes?: string | null;
};

export type Ficha = {
  id: string;
  studentId: string;
  studentName: string;
  sheetLabel: string;
  title: string;
  active: boolean;
  validUntil?: string | null;
  exercises: ExercicioDaFicha[];
};

export type AlunoResumo = { id: string; fullName: string; cpf?: string };

export type ExercicioDoCatalogo = {
  id: string;
  name: string;
  muscleGroup?: string | null;
  equipment?: string | null;
  arquivado?: boolean;
};

/** Primeira letra ainda não usada pelo aluno; com A–D todas em uso, volta pra A. */
export function proximoRotulo(usados: string[]): string {
  return ROTULOS_FICHA.find((r) => !usados.includes(r)) ?? "A";
}
