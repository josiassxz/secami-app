import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, downloadMedia } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { mensagemDeErro } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { cn, formatDate, formatDateTime } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Avatar, Badge, Button, Card, Label, Table, TableSkeleton, TBody, TD, TH, THead, TR, Textarea } from "@/components/ui";
import { FileCheck2, FileText, Loader2 } from "lucide-react";

/** Contadores do painel/menu (mesma queryKey em Dashboard e Layout). */
export type ResumoAtestados = { vencendo: number; bloqueados: number; pendentes: number };

type Pendente = {
  id: string;
  studentId: string;
  studentName: string;
  cpf: string;
  email?: string;
  phone?: string;
  departmentName?: string;
  enviadoEm: string;
  emissaoData: string;
  medicoNome: string;
  medicoCrm: string;
  medicoCrmUf: string;
  arquivoId: string;
  vencimentoAtual?: string;
  diasRestantesAtual?: number;
  bloqueado: boolean;
};

type AlunoAtestado = {
  studentId: string;
  studentName: string;
  cpf: string;
  departmentName?: string;
  phone?: string;
  vencimento?: string;
  diasRestantes: number;
  base: "ATESTADO" | "CADASTRO";
  bloqueado: boolean;
  envioEmAnalise: boolean;
};

type Aba = "pendentes" | "vencendo" | "bloqueados";

const ROTULOS: Record<Aba, string> = {
  pendentes: "Aguardando validação",
  vencendo: "Vencem em 30 dias",
  bloqueados: "Bloqueados",
};

/** "vence hoje", "vence em 3 dias", "vencido há 2 dias". */
export function textoPrazo(dias: number): string {
  if (dias === 0) return "vence hoje";
  if (dias === 1) return "vence amanhã";
  if (dias > 1) return `vence em ${dias} dias`;
  if (dias === -1) return "vencido há 1 dia";
  return `vencido há ${-dias} dias`;
}

/**
 * Atestados médicos (só alunos civis): fila de validação dos novos atestados
 * enviados pelo app e as listas de quem vence em 30 dias e de quem está
 * bloqueado por atestado vencido. Recepção vê só as listas.
 */
export default function Atestados() {
  const { hasRole } = useAuth();
  const podeValidar = hasRole("admin", "gerente");
  const qc = useQueryClient();
  const [params, setParams] = useSearchParams();
  const abas: Aba[] = podeValidar ? ["pendentes", "vencendo", "bloqueados"] : ["vencendo", "bloqueados"];
  const pedida = params.get("aba") as Aba | null;
  const aba: Aba = pedida && abas.includes(pedida) ? pedida : abas[0];

  const [recusar, setRecusar] = useState<Pendente | null>(null);
  const [motivo, setMotivo] = useState("");
  const [erroRecusa, setErroRecusa] = useState<string | null>(null);
  const [abrindoPdf, setAbrindoPdf] = useState<string | null>(null);

  const resumo = useQuery({
    queryKey: ["atestados-resumo"],
    queryFn: () => api<ResumoAtestados>("/admin/atestados/resumo"),
  });
  const pendentes = useQuery({
    queryKey: ["atestados-pendentes"],
    queryFn: () => api<Pendente[]>("/admin/atestados/pendentes"),
    enabled: podeValidar && aba === "pendentes",
  });
  const lista = useQuery({
    queryKey: ["atestados-alunos", aba],
    queryFn: () => api<AlunoAtestado[]>(`/admin/atestados/alunos?lista=${aba}`),
    enabled: aba !== "pendentes",
  });

  function atualizar() {
    qc.invalidateQueries({ queryKey: ["atestados-pendentes"] });
    qc.invalidateQueries({ queryKey: ["atestados-resumo"] });
    qc.invalidateQueries({ queryKey: ["atestados-alunos"] });
  }

  const aprovar = useMutation({
    mutationFn: (p: Pendente) => api(`/admin/atestados/${p.id}/aprovar`, { method: "POST" }),
    onSuccess: (_d, p) => {
      atualizar();
      toast("success", `Atestado de ${p.studentName} aprovado.${p.bloqueado ? " Acesso liberado." : ""}`);
    },
    onError: (e) => toast("error", mensagemDeErro(e, "Não foi possível aprovar o atestado.")),
  });

  const recusa = useMutation({
    mutationFn: ({ p, motivo }: { p: Pendente; motivo: string }) =>
      api(`/admin/atestados/${p.id}/recusar`, { method: "POST", body: JSON.stringify({ motivo }) }),
    onSuccess: (_d, { p }) => {
      atualizar();
      setRecusar(null);
      toast("success", `Atestado de ${p.studentName} recusado. O aluno vê o motivo no aplicativo.`);
    },
    onError: (e) => setErroRecusa(mensagemDeErro(e, "Não foi possível recusar o atestado.")),
  });

  function confirmarRecusa() {
    if (!recusar) return;
    if (!motivo.trim()) {
      setErroRecusa("Informe o motivo da recusa.");
      return;
    }
    recusa.mutate({ p: recusar, motivo: motivo.trim() });
  }

  async function verPdf(p: Pendente) {
    setAbrindoPdf(p.id);
    try {
      const blob = await downloadMedia(p.arquivoId);
      const url = URL.createObjectURL(blob);
      window.open(url, "_blank", "noopener,noreferrer");
      setTimeout(() => URL.revokeObjectURL(url), 60_000);
    } catch (e) {
      toast("error", mensagemDeErro(e, "Não foi possível abrir o atestado."));
    } finally {
      setAbrindoPdf(null);
    }
  }

  const contagem: Record<Aba, number | undefined> = {
    pendentes: resumo.data?.pendentes,
    vencendo: resumo.data?.vencendo,
    bloqueados: resumo.data?.bloqueados,
  };

  return (
    <div>
      <PageHeader title="Atestados" subtitle="Validade de 1 ano · só alunos civis (militares e instrutores não entram)" />

      <div role="tablist" className="mb-4 flex flex-wrap gap-2">
        {abas.map((a) => (
          <button
            key={a}
            role="tab"
            aria-selected={aba === a}
            onClick={() => setParams({ aba: a })}
            className={cn(
              "rounded-full px-3.5 py-1.5 text-sm font-semibold transition-colors",
              aba === a ? "bg-brand text-brand-fg shadow-1" : "bg-surface-alt text-content-soft hover:text-content"
            )}
          >
            {ROTULOS[a]}
            {contagem[a] !== undefined && <> <span className="ml-1 tabular-nums opacity-80">({contagem[a]})</span></>}
          </button>
        ))}
      </div>

      {aba === "pendentes" ? (
        pendentes.isLoading ? (
          <Card className="h-40 animate-pulse" />
        ) : (pendentes.data ?? []).length === 0 ? (
          <Vazio texto="Nenhum atestado aguardando validação." />
        ) : (
          <div className="space-y-4">
            {(pendentes.data ?? []).map((p) => (
              <Card key={p.id} className="p-5">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                  <div className="flex items-start gap-3">
                    <Avatar name={p.studentName} />
                    <div>
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-semibold text-content">{p.studentName}</span>
                        {p.bloqueado ? (
                          <Badge tone="faltou">acesso bloqueado</Badge>
                        ) : p.diasRestantesAtual !== undefined ? (
                          <Badge tone="warning">atual {textoPrazo(p.diasRestantesAtual)}</Badge>
                        ) : null}
                      </div>
                      <div className="mt-0.5 text-xs text-content-soft">
                        {p.cpf} · {p.departmentName ?? "Sem secretaria"} · enviado em {formatDateTime(p.enviadoEm)}
                      </div>
                    </div>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <Button variant="outline" size="sm" disabled={abrindoPdf === p.id} onClick={() => verPdf(p)}>
                      {abrindoPdf === p.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <FileText className="h-4 w-4" />}
                      Ver atestado (PDF)
                    </Button>
                    <Button variant="outline" size="sm" onClick={() => { setRecusar(p); setMotivo(""); setErroRecusa(null); }}>
                      Recusar
                    </Button>
                    <Button size="sm" loading={aprovar.isPending && aprovar.variables?.id === p.id} onClick={() => aprovar.mutate(p)}>
                      Aprovar
                    </Button>
                  </div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-x-6 gap-y-3 text-sm sm:grid-cols-4">
                  <Campo rotulo="Emissão do novo atestado" valor={formatDate(p.emissaoData)} />
                  <Campo rotulo="Médico" valor={`${p.medicoNome} (CRM ${p.medicoCrm}/${p.medicoCrmUf})`} />
                  <Campo rotulo="Vencimento atual" valor={p.vencimentoAtual ? formatDate(p.vencimentoAtual) : "—"} />
                  <Campo rotulo="Contato" valor={p.phone || p.email || "—"} />
                </div>
              </Card>
            ))}
          </div>
        )
      ) : (
        <Card className="overflow-hidden">
          {lista.isLoading ? (
            <TableSkeleton rows={6} />
          ) : (lista.data ?? []).length === 0 ? (
            <Vazio texto={aba === "vencendo" ? "Nenhum atestado vence nos próximos 30 dias." : "Nenhum aluno bloqueado por atestado vencido."} />
          ) : (
            <Table>
              <THead>
                <TR><TH>Aluno</TH><TH>CPF</TH><TH>Secretaria</TH><TH>Vencimento</TH><TH>Prazo</TH><TH>Novo atestado</TH></TR>
              </THead>
              <TBody>
                {(lista.data ?? []).map((a) => (
                  <TR key={a.studentId}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar name={a.studentName} />
                        <div className="min-w-0">
                          <div className="truncate font-medium">{a.studentName}</div>
                          {a.phone && <div className="text-xs text-content-soft">{a.phone}</div>}
                        </div>
                      </div>
                    </TD>
                    <TD className="tabular-nums text-content-soft">{a.cpf}</TD>
                    <TD className="text-content-soft">{a.departmentName || "—"}</TD>
                    <TD className="tabular-nums">
                      {a.vencimento ? formatDate(a.vencimento) : "—"}
                      <div className="text-xs text-content-faint">
                        {a.base === "ATESTADO" ? "pela data do atestado" : "pela data de cadastro"}
                      </div>
                    </TD>
                    <TD><Badge tone={a.bloqueado ? "faltou" : "warning"}>{textoPrazo(a.diasRestantes)}</Badge></TD>
                    <TD>{a.envioEmAnalise ? <Badge tone="info">em análise</Badge> : <span className="text-content-faint">—</span>}</TD>
                  </TR>
                ))}
              </TBody>
            </Table>
          )}
        </Card>
      )}

      <Modal
        open={!!recusar}
        onClose={() => !recusa.isPending && setRecusar(null)}
        title={`Recusar atestado de ${recusar?.studentName ?? ""}`}
        footer={
          <>
            <Button variant="outline" onClick={() => setRecusar(null)} disabled={recusa.isPending}>Cancelar</Button>
            <Button variant="danger" loading={recusa.isPending} onClick={confirmarRecusa}>Confirmar recusa</Button>
          </>
        }
      >
        <div className="space-y-2">
          <Label htmlFor="motivo-recusa-atestado">Motivo da recusa</Label>
          <Textarea
            id="motivo-recusa-atestado"
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            placeholder="O aluno vê esse texto no aplicativo e pode enviar outro atestado."
            autoFocus
          />
          {erroRecusa && <p className="text-sm text-danger">{erroRecusa}</p>}
        </div>
      </Modal>
    </div>
  );
}

function Campo({ rotulo, valor }: { rotulo: string; valor: string }) {
  return (
    <div>
      <div className="text-xs text-content-faint">{rotulo}</div>
      <div className="text-content">{valor}</div>
    </div>
  );
}

function Vazio({ texto }: { texto: string }) {
  return (
    <div className="flex flex-col items-center gap-2 px-4 py-14 text-center text-content-soft">
      <FileCheck2 className="h-8 w-8 text-content-faint" />
      <p>{texto}</p>
    </div>
  );
}
