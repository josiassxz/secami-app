import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { ArrowDown, ArrowUp, Plus, Search, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import {
  ROTULOS_FICHA,
  proximoRotulo,
  type AlunoResumo,
  type ExercicioDoCatalogo,
  type Ficha,
} from "@/lib/fichas";
import { Modal } from "@/components/Modal";
import { Avatar, Button, Input, Label, Select } from "@/components/ui";

/**
 * Editor de ficha de treino (A–D) do admin — o instrutor/admin monta a ficha
 * de um aluno com os exercícios do catálogo. Três modos:
 * - `novo`: ficha em branco pro aluno selecionado;
 * - `editar`: altera uma ficha existente (o aluno não muda);
 * - `modelo`: parte de uma ficha existente (de qualquer aluno) e grava uma
 *   ficha NOVA — pro mesmo aluno ou pra outro, escolhido no próprio editor.
 */
export type ModoEditor = "novo" | "editar" | "modelo";

type Item = {
  chave: number;
  exerciseId: string | null;
  exerciseName: string;
  sets: string;
  reps: string;
  restSeconds: string;
  notes: string;
};

let proximaChave = 1;
const novaChave = () => proximaChave++;

/** Valor do <select> pra item sem id do catálogo (só o nome gravado). */
const SO_NOME = "__so_nome__";

function itemVazio(): Item {
  // Mesmos valores iniciais do sistema antigo (3 × 12, 60s de descanso).
  return { chave: novaChave(), exerciseId: null, exerciseName: "", sets: "3", reps: "12", restSeconds: "60", notes: "" };
}

function itensDaFicha(ficha: Ficha): Item[] {
  return [...ficha.exercises]
    .sort((a, b) => (a.ordem ?? 0) - (b.ordem ?? 0))
    .map((e) => ({
      chave: novaChave(),
      exerciseId: e.exerciseId ?? null,
      exerciseName: e.exerciseName ?? "",
      sets: e.sets != null ? String(e.sets) : "",
      reps: e.reps ?? "",
      restSeconds: e.restSeconds != null ? String(e.restSeconds) : "",
      notes: e.notes ?? "",
    }));
}

/** Inteiro >= 0 ou vazio (campo opcional). */
function numeroValido(v: string): boolean {
  return v.trim() === "" || /^\d+$/.test(v.trim());
}

function paraNumero(v: string): number | null {
  return v.trim() === "" ? null : Number(v.trim());
}

/** Rótulo curto em cima do campo — os campos da linha continuam legíveis depois de preenchidos. */
function Campo({ rotulo, className, children }: { rotulo: string; className?: string; children: React.ReactNode }) {
  return (
    <div className={className}>
      <span className="mb-0.5 block text-[11px] font-medium text-content-soft">{rotulo}</span>
      {children}
    </div>
  );
}

export function FichaEditor({
  open,
  modo,
  ficha,
  aluno,
  onClose,
  onSaved,
}: {
  open: boolean;
  modo: ModoEditor;
  /** Ficha editada (modo `editar`) ou usada como base (modo `modelo`). */
  ficha?: Ficha | null;
  /** Aluno de destino inicial. */
  aluno: AlunoResumo | null;
  onClose: () => void;
  onSaved: (ficha: Ficha, aluno: AlunoResumo) => void;
}) {
  const [destino, setDestino] = useState<AlunoResumo | null>(aluno);
  const [buscaAluno, setBuscaAluno] = useState("");
  const [trocandoAluno, setTrocandoAluno] = useState(false);
  const [rotulo, setRotulo] = useState("A");
  const [titulo, setTitulo] = useState("");
  const [ativa, setAtiva] = useState(true);
  const [validaAte, setValidaAte] = useState("");
  const [itens, setItens] = useState<Item[]>([]);
  const [tentouSalvar, setTentouSalvar] = useState(false);
  const [erroAoSalvar, setErroAoSalvar] = useState<string | null>(null);
  const [rotuloEscolhido, setRotuloEscolhido] = useState(false);

  // Reinicia o formulário a cada abertura.
  useEffect(() => {
    if (!open) return;
    setDestino(aluno);
    setBuscaAluno("");
    setTrocandoAluno(false);
    setTentouSalvar(false);
    setErroAoSalvar(null);
    if (ficha) {
      setRotulo(ficha.sheetLabel);
      setTitulo(ficha.title);
      setAtiva(modo === "editar" ? ficha.active : true);
      setValidaAte(modo === "editar" ? ficha.validUntil ?? "" : "");
      setItens(itensDaFicha(ficha));
      setRotuloEscolhido(modo === "editar");
    } else {
      setRotulo("A");
      setTitulo("");
      setAtiva(true);
      setValidaAte("");
      setItens([itemVazio()]);
      setRotuloEscolhido(false);
    }
  }, [open, ficha, aluno, modo]);

  const catalogo = useQuery({
    queryKey: ["exercicios-catalogo"],
    queryFn: () => api<ExercicioDoCatalogo[]>("/exercises"),
    enabled: open,
    staleTime: 5 * 60_000,
  });

  // Fichas que o aluno de destino já tem — pra sugerir a próxima letra livre
  // e avisar quando a escolhida já existe.
  const fichasDoDestino = useQuery({
    queryKey: ["plans", destino?.id],
    queryFn: () => api<Ficha[]>(`/students/${destino!.id}/workout-plans`),
    enabled: open && !!destino,
  });
  const rotulosUsados = useMemo(
    () =>
      (fichasDoDestino.data ?? [])
        .filter((f) => !(modo === "editar" && f.id === ficha?.id))
        .map((f) => f.sheetLabel),
    [fichasDoDestino.data, modo, ficha]
  );
  useEffect(() => {
    if (open && !rotuloEscolhido && fichasDoDestino.data) {
      setRotulo(proximoRotulo(rotulosUsados));
    }
  }, [open, rotuloEscolhido, fichasDoDestino.data, rotulosUsados]);

  const buscaAlunos = useQuery({
    queryKey: ["ficha-editor-alunos", buscaAluno],
    queryFn: () =>
      api<{ content: AlunoResumo[] }>(`/students?q=${encodeURIComponent(buscaAluno)}&size=6&perfil=aluno`),
    enabled: open && trocandoAluno && buscaAluno.trim().length >= 2,
  });

  const exerciciosAtivos = useMemo(
    () => (catalogo.data ?? []).filter((e) => !e.arquivado),
    [catalogo.data]
  );
  const grupos = useMemo(() => {
    const porGrupo = new Map<string, ExercicioDoCatalogo[]>();
    for (const e of exerciciosAtivos) {
      const g = e.muscleGroup?.trim() || "Outros";
      porGrupo.set(g, [...(porGrupo.get(g) ?? []), e]);
    }
    return [...porGrupo.entries()]
      .sort(([a], [b]) => a.localeCompare(b, "pt-BR"))
      .map(([grupo, lista]) => [grupo, lista.sort((a, b) => a.name.localeCompare(b.name, "pt-BR"))] as const);
  }, [exerciciosAtivos]);

  // ---- validação ----
  const erroAluno = !destino ? "Selecione o aluno." : null;
  const erroTitulo = titulo.trim() === "" ? "Informe o título da ficha." : null;
  const erroSemExercicio = itens.length === 0 ? "Adicione pelo menos um exercício." : null;
  const erroDoItem = (i: Item) => {
    if (!i.exerciseId && !i.exerciseName.trim()) return "Escolha o exercício.";
    if (!numeroValido(i.sets) || !numeroValido(i.restSeconds)) return "Séries e descanso aceitam só números inteiros.";
    return null;
  };
  const formularioValido =
    !erroAluno && !erroTitulo && !erroSemExercicio && itens.every((i) => erroDoItem(i) === null);

  const salvar = useMutation({
    mutationFn: () => {
      const corpo = {
        studentId: destino!.id,
        sheetLabel: rotulo,
        title: titulo.trim(),
        active: ativa,
        validUntil: validaAte || null,
        exercises: itens.map((i) => ({
          exerciseId: i.exerciseId,
          exerciseName: i.exerciseName.trim() || null,
          sets: paraNumero(i.sets),
          reps: i.reps.trim() || null,
          restSeconds: paraNumero(i.restSeconds),
          notes: i.notes.trim() || null,
        })),
      };
      return modo === "editar" && ficha
        ? api<Ficha>(`/workout-plans/${ficha.id}`, { method: "PUT", body: JSON.stringify(corpo) })
        : api<Ficha>(`/workout-plans`, { method: "POST", body: JSON.stringify(corpo) });
    },
    onSuccess: (salva) => onSaved(salva, destino!),
    onError: (err) => setErroAoSalvar(mensagemDeErro(err, "Não foi possível salvar a ficha.")),
  });

  function enviar() {
    setTentouSalvar(true);
    setErroAoSalvar(null);
    if (!formularioValido) return;
    salvar.mutate();
  }

  function atualizarItem(chave: number, mudanca: Partial<Item>) {
    setItens((lista) => lista.map((i) => (i.chave === chave ? { ...i, ...mudanca } : i)));
  }

  function escolherExercicio(chave: number, valor: string) {
    if (valor === SO_NOME) return;
    const ex = exerciciosAtivos.find((e) => e.id === valor);
    atualizarItem(chave, { exerciseId: ex?.id ?? null, exerciseName: ex?.name ?? "" });
  }

  function mover(indice: number, delta: number) {
    setItens((lista) => {
      const alvo = indice + delta;
      if (alvo < 0 || alvo >= lista.length) return lista;
      const copia = [...lista];
      [copia[indice], copia[alvo]] = [copia[alvo], copia[indice]];
      return copia;
    });
  }

  const titulos: Record<ModoEditor, string> = {
    novo: "Nova ficha",
    editar: "Editar ficha",
    modelo: "Nova ficha a partir de modelo",
  };
  const rotuloRepetido = rotulosUsados.includes(rotulo);

  return (
    <Modal
      open={open}
      onClose={() => !salvar.isPending && onClose()}
      title={titulos[modo]}
      size="xl"
      footer={
        <>
          {tentouSalvar && !formularioValido && (
            <span className="mr-auto self-center text-sm text-danger">Revise os campos destacados.</span>
          )}
          {erroAoSalvar && <span className="mr-auto self-center text-sm text-danger">{erroAoSalvar}</span>}
          <Button variant="outline" onClick={onClose} disabled={salvar.isPending}>
            Cancelar
          </Button>
          <Button onClick={enviar} loading={salvar.isPending}>
            Salvar ficha
          </Button>
        </>
      }
    >
      <div className="space-y-5">
        {modo === "modelo" && ficha && (
          <p className="rounded-md bg-surface-alt px-3 py-2 text-sm text-content-soft">
            Modelo: ficha {ficha.sheetLabel} "{ficha.title}" de {ficha.studentName}. Ajuste o que precisar — a
            ficha original não muda.
          </p>
        )}

        {/* Aluno de destino */}
        <div>
          <Label>Aluno</Label>
          {destino && !trocandoAluno ? (
            <div className="flex items-center gap-3 rounded-md border border-line px-3 py-2">
              <Avatar name={destino.fullName} className="h-7 w-7 text-[11px]" />
              <span className="flex-1 truncate text-sm font-medium text-content">{destino.fullName}</span>
              {modo !== "editar" && (
                <Button variant="ghost" size="sm" onClick={() => setTrocandoAluno(true)}>
                  Trocar aluno
                </Button>
              )}
            </div>
          ) : (
            <div>
              <div className="relative">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-content-faint" />
                <Input
                  aria-label="Buscar aluno de destino"
                  className="pl-9"
                  placeholder="Nome ou CPF do aluno (mín. 2 letras)"
                  value={buscaAluno}
                  autoFocus
                  onChange={(e) => setBuscaAluno(e.target.value)}
                />
              </div>
              {buscaAluno.trim().length >= 2 && (
                <div className="mt-2 max-h-48 divide-y divide-line overflow-y-auto rounded-md border border-line">
                  {buscaAlunos.isLoading ? (
                    <div className="px-3 py-2 text-sm text-content-soft">Buscando…</div>
                  ) : (buscaAlunos.data?.content ?? []).length === 0 ? (
                    <div className="px-3 py-2 text-sm text-content-soft">Nenhum aluno encontrado.</div>
                  ) : (
                    (buscaAlunos.data?.content ?? []).map((s) => (
                      <button
                        key={s.id}
                        type="button"
                        className="flex w-full items-center gap-3 px-3 py-2 text-left text-sm hover:bg-surface-alt"
                        onClick={() => {
                          setDestino(s);
                          setTrocandoAluno(false);
                          setBuscaAluno("");
                          setRotuloEscolhido(false);
                        }}
                      >
                        <Avatar name={s.fullName} className="h-6 w-6 text-[10px]" />
                        <span className="flex-1 truncate">{s.fullName}</span>
                        <span className="shrink-0 text-xs tabular-nums text-content-soft">{s.cpf}</span>
                      </button>
                    ))
                  )}
                </div>
              )}
              {destino && (
                <button type="button" className="mt-1 text-xs text-brand hover:underline" onClick={() => setTrocandoAluno(false)}>
                  Manter {destino.fullName}
                </button>
              )}
            </div>
          )}
          {tentouSalvar && erroAluno && <p className="mt-1 text-xs text-danger">{erroAluno}</p>}
        </div>

        <div className="grid gap-4 sm:grid-cols-[1fr_8rem]">
          <div>
            <Label htmlFor="ficha-titulo">Título</Label>
            <Input
              id="ficha-titulo"
              value={titulo}
              placeholder="Ex.: Treino de peito e tríceps"
              onChange={(e) => setTitulo(e.target.value)}
            />
            {tentouSalvar && erroTitulo && <p className="mt-1 text-xs text-danger">{erroTitulo}</p>}
          </div>
          <div>
            <Label htmlFor="ficha-rotulo">Ficha</Label>
            <Select
              id="ficha-rotulo"
              value={rotulo}
              onChange={(e) => {
                setRotulo(e.target.value);
                setRotuloEscolhido(true);
              }}
            >
              {ROTULOS_FICHA.map((r) => (
                <option key={r} value={r}>
                  Ficha {r}
                </option>
              ))}
            </Select>
          </div>
        </div>
        {rotuloRepetido && (
          <p className="-mt-3 text-xs text-warning">O aluno já tem outra ficha {rotulo}.</p>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <Label htmlFor="ficha-validade">Válida até (opcional)</Label>
            <Input id="ficha-validade" type="date" value={validaAte} onChange={(e) => setValidaAte(e.target.value)} />
          </div>
          <label className="flex items-center gap-2 self-end pb-2 text-sm text-content">
            <input type="checkbox" checked={ativa} onChange={(e) => setAtiva(e.target.checked)} />
            Ficha ativa (inativa não aparece para o aluno)
          </label>
        </div>

        {/* Exercícios */}
        <div>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-sm font-semibold text-content">Exercícios</span>
            <span className="text-xs text-content-soft">
              {itens.length} exercício{itens.length === 1 ? "" : "s"}
            </span>
          </div>
          {catalogo.isError && (
            <p className="mb-2 text-sm text-danger">
              {mensagemDeErro(catalogo.error, "Não foi possível carregar o catálogo de exercícios.")}
            </p>
          )}
          <div className="space-y-3">
            {itens.map((item, indice) => {
              const erro = tentouSalvar ? erroDoItem(item) : null;
              const foraDoCatalogo =
                !!item.exerciseName && !exerciciosAtivos.some((e) => e.id === item.exerciseId);
              return (
                <div key={item.chave} className="rounded-md border border-line p-3">
                  <div className="flex items-start gap-2">
                    <span className="mt-2 w-5 shrink-0 text-sm font-semibold tabular-nums text-content-soft">
                      {indice + 1}.
                    </span>
                    <div className="min-w-0 flex-1">
                      <Select
                        aria-label={`Exercício ${indice + 1}`}
                        value={item.exerciseId && !foraDoCatalogo ? item.exerciseId : foraDoCatalogo ? SO_NOME : ""}
                        onChange={(e) => escolherExercicio(item.chave, e.target.value)}
                      >
                        <option value="" disabled>
                          {catalogo.isLoading ? "Carregando exercícios…" : "Selecione o exercício"}
                        </option>
                        {foraDoCatalogo && (
                          <option value={SO_NOME}>{item.exerciseName} (fora do catálogo)</option>
                        )}
                        {grupos.map(([grupo, lista]) => (
                          <optgroup key={grupo} label={grupo}>
                            {lista.map((e) => (
                              <option key={e.id} value={e.id}>
                                {e.name}
                              </option>
                            ))}
                          </optgroup>
                        ))}
                      </Select>
                    </div>
                    <div className="flex shrink-0 items-center">
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Subir exercício ${indice + 1}`}
                        disabled={indice === 0}
                        onClick={() => mover(indice, -1)}
                      >
                        <ArrowUp className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Descer exercício ${indice + 1}`}
                        disabled={indice === itens.length - 1}
                        onClick={() => mover(indice, 1)}
                      >
                        <ArrowDown className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Remover exercício ${indice + 1}`}
                        onClick={() => setItens((lista) => lista.filter((i) => i.chave !== item.chave))}
                      >
                        <Trash2 className="h-4 w-4 text-danger" />
                      </Button>
                    </div>
                  </div>
                  <div className="mt-2 grid grid-cols-3 gap-2 pl-7 sm:grid-cols-[5rem_7rem_7rem_1fr]">
                    <Campo rotulo="Séries">
                      <Input
                        aria-label={`Séries do exercício ${indice + 1}`}
                        inputMode="numeric"
                        value={item.sets}
                        onChange={(e) => atualizarItem(item.chave, { sets: e.target.value })}
                      />
                    </Campo>
                    <Campo rotulo="Repetições">
                      <Input
                        aria-label={`Repetições do exercício ${indice + 1}`}
                        placeholder="ex.: 10-12"
                        value={item.reps}
                        onChange={(e) => atualizarItem(item.chave, { reps: e.target.value })}
                      />
                    </Campo>
                    <Campo rotulo="Descanso (s)">
                      <Input
                        aria-label={`Descanso do exercício ${indice + 1}`}
                        inputMode="numeric"
                        value={item.restSeconds}
                        onChange={(e) => atualizarItem(item.chave, { restSeconds: e.target.value })}
                      />
                    </Campo>
                    <Campo rotulo="Observações" className="col-span-3 sm:col-span-1">
                      <Input
                        aria-label={`Observações do exercício ${indice + 1}`}
                        placeholder="opcional"
                        value={item.notes}
                        onChange={(e) => atualizarItem(item.chave, { notes: e.target.value })}
                      />
                    </Campo>
                  </div>
                  {erro && <p className="mt-1 pl-7 text-xs text-danger">{erro}</p>}
                </div>
              );
            })}
          </div>
          {tentouSalvar && erroSemExercicio && <p className="mt-2 text-xs text-danger">{erroSemExercicio}</p>}
          <Button variant="outline" size="sm" className="mt-3" onClick={() => setItens((l) => [...l, itemVazio()])}>
            <Plus className="h-4 w-4" /> Adicionar exercício
          </Button>
        </div>
      </div>
    </Modal>
  );
}
