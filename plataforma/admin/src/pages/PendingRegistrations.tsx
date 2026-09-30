import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, downloadMedia, type PendingRegistration } from "@/lib/api";
import { mensagemDeErro } from "@/lib/erros";
import { formatDate, formatDateTime } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Modal } from "@/components/Modal";
import { Avatar, Badge, Button, Card, Label, Select, Textarea } from "@/components/ui";
import {
  AlertCircle,
  ChevronDown,
  ChevronUp,
  ClipboardCheck,
  FileText,
  Loader2,
} from "lucide-react";

/** As 10 perguntas do questionário PAR-Q, na ordem exata do formulário de
 *  cadastro ("QUESTIONÁRIO PAR-Q — Questionário de Prontidão para Atividade
 *  Física e Declaração de Saúde"). "Sim" nessas perguntas é o que indica risco. */
const PARQ_QUESTIONS: { key: string; label: string }[] = [
  {
    key: "problema_coracao",
    label:
      "1. Algum médico já disse que você possui algum problema de coração e que só deveria realizar atividade física supervisionado por profissionais de saúde?",
  },
  {
    key: "dor_peito_atividade",
    label: "2. Você sente dores no peito e/ou tórax quando pratica atividade física?",
  },
  {
    key: "dor_peito_mes",
    label:
      "3. No último mês, você sentiu dores no peito independente da prática de atividade física?",
  },
  {
    key: "desequilibrio_tontura",
    label: "4. Você apresenta desequilíbrio devido a tontura e/ou perda de consciência?",
  },
  {
    key: "problema_osseo_articular",
    label:
      "5. Você possui algum problema ósseo ou articular que poderia piorar em consequência de alteração em sua atividade física?",
  },
  {
    key: "tratamento_pressao_coracao",
    label:
      "6. Você realiza algum tipo de tratamento médico para pressão arterial e/ou problema de coração?",
  },
  {
    key: "outra_razao_nao_praticar",
    label: "7. Sabe de alguma outra razão pela qual você não deve praticar atividade física?",
  },
  {
    key: "tratamento_continuo",
    label:
      "8. Você realiza algum tratamento médico contínuo, que possa ser afetado ou prejudicado com a atividade física?",
  },
  {
    key: "cirurgia_compromete_atividade",
    label:
      "9. Você já se submeteu a algum tipo de cirurgia, que comprometa de alguma forma a atividade física?",
  },
  {
    key: "outra_razao_compromete_saude",
    label:
      "10. Sabe de alguma outra razão pela qual a atividade física possa eventualmente comprometer sua saúde?",
  },
];

const PERFIL_INSTRUTOR = "Instrutor";

function ErrorBox({ message }: { message: string }) {
  return (
    <div className="flex items-start gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
      <span>{message}</span>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs text-content-faint">{label}</div>
      <div className="text-content">{value}</div>
    </div>
  );
}

export default function PendingRegistrations() {
  const qc = useQueryClient();
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [rejectTarget, setRejectTarget] = useState<PendingRegistration | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [rejectError, setRejectError] = useState<string | null>(null);
  const [actionErrors, setActionErrors] = useState<Record<string, string>>({});
  const [loadingAtestadoId, setLoadingAtestadoId] = useState<string | null>(null);
  // O perfil não vem do formulário público — o admin escolhe aqui, no momento
  // da aprovação: aluno (Civil ou Militar) ou Instrutor (prescreve as fichas
  // de treino e não agenda horário).
  const [perfilEscolhido, setPerfilEscolhido] = useState<Record<string, string>>({});
  // Aprovar como instrutor dá acesso de equipe (dados dos alunos, fichas) —
  // pede confirmação antes.
  const [instrutorTarget, setInstrutorTarget] = useState<PendingRegistration | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["pending-registrations"],
    queryFn: () => api<PendingRegistration[]>("/admin/cadastros/pendentes"),
  });

  const approve = useMutation({
    // `perfil` vem do seletor: "Civil"/"Militar" (aluno) ou "Instrutor".
    mutationFn: ({ studentId, perfil }: { studentId: string; perfil: string }) =>
      api(`/admin/cadastros/${studentId}/aprovar`, {
        method: "POST",
        body: JSON.stringify(
          perfil === PERFIL_INSTRUTOR ? { perfil: "instrutor" } : { perfil: "aluno", studentType: perfil }
        ),
      }),
    onSuccess: (_data, { studentId }) => {
      qc.invalidateQueries({ queryKey: ["pending-registrations"] });
      setInstrutorTarget(null);
      setActionErrors((prev) => {
        const { [studentId]: _removed, ...rest } = prev;
        return rest;
      });
    },
    onError: (err: any, { studentId }) => {
      setInstrutorTarget(null);
      setActionErrors((prev) => ({ ...prev, [studentId]: mensagemDeErro(err, "Não foi possível aprovar.") }));
    },
  });

  function onApprove(r: PendingRegistration, perfil: string) {
    if (perfil === PERFIL_INSTRUTOR) setInstrutorTarget(r);
    else approve.mutate({ studentId: r.studentId, perfil });
  }

  const reject = useMutation({
    mutationFn: ({ studentId, motivo }: { studentId: string; motivo: string }) =>
      api(`/admin/cadastros/${studentId}/rejeitar`, {
        method: "POST",
        body: JSON.stringify({ motivo }),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["pending-registrations"] });
      setRejectTarget(null);
      setRejectReason("");
      setRejectError(null);
    },
    onError: (err: any) => setRejectError(mensagemDeErro(err, "Não foi possível recusar.")),
  });

  function openReject(r: PendingRegistration) {
    setRejectTarget(r);
    setRejectReason("");
    setRejectError(null);
  }
  function closeReject() {
    if (reject.isPending) return;
    setRejectTarget(null);
  }
  function submitReject() {
    if (!rejectTarget) return;
    if (!rejectReason.trim()) {
      setRejectError("Informe o motivo da recusa.");
      return;
    }
    reject.mutate({ studentId: rejectTarget.studentId, motivo: rejectReason.trim() });
  }

  async function viewAtestado(r: PendingRegistration) {
    setActionErrors((prev) => {
      const { [r.studentId]: _removed, ...rest } = prev;
      return rest;
    });
    setLoadingAtestadoId(r.studentId);
    try {
      const blob = await downloadMedia(r.atestadoArquivoId);
      const url = URL.createObjectURL(blob);
      window.open(url, "_blank", "noopener,noreferrer");
      setTimeout(() => URL.revokeObjectURL(url), 60_000);
    } catch (err: any) {
      setActionErrors((prev) => ({
        ...prev,
        [r.studentId]: mensagemDeErro(err, "Não foi possível abrir o atestado."),
      }));
    } finally {
      setLoadingAtestadoId(null);
    }
  }

  const rows = data || [];

  return (
    <div>
      <PageHeader
        title="Cadastros Pendentes"
        subtitle={data ? `${rows.length} aguardando aprovação` : undefined}
      />

      {isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <Card key={i} className="h-40 animate-pulse" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <Card>
          <div className="flex flex-col items-center gap-2 px-4 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-alt text-content-faint">
              <ClipboardCheck className="h-6 w-6" />
            </div>
            <p className="font-medium text-content">Nenhum cadastro pendente</p>
            <p className="max-w-xs text-sm text-content-soft">
              Assim que alguém se cadastrar pelo formulário público, o pedido aparece aqui para
              aprovação.
            </p>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          {rows.map((r) => {
            const expanded = expandedId === r.studentId;
            const isApprovingThis = approve.isPending && approve.variables?.studentId === r.studentId;
            const isLoadingAtestado = loadingAtestadoId === r.studentId;
            const error = actionErrors[r.studentId];
            const perfil = perfilEscolhido[r.studentId] ?? "";

            return (
              <Card key={r.studentId} className="overflow-hidden">
                <div className="p-5">
                  <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="flex items-start gap-3">
                      <Avatar name={r.fullName} />
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-semibold text-content">{r.fullName}</span>
                        </div>
                        <div className="mt-0.5 text-xs text-content-soft">
                          {r.departmentName} · Cadastrado em {formatDateTime(r.createdAt)}
                        </div>
                      </div>
                    </div>
                    <div className="flex shrink-0 items-center gap-2">
                      <Select
                        aria-label="Perfil"
                        className="h-9 w-40"
                        value={perfil}
                        onChange={(e) =>
                          setPerfilEscolhido((prev) => ({ ...prev, [r.studentId]: e.target.value }))
                        }
                      >
                        <option value="" disabled>
                          Perfil
                        </option>
                        <optgroup label="Aluno">
                          <option value="Civil">Aluno · Civil</option>
                          <option value="Militar">Aluno · Militar</option>
                        </optgroup>
                        <option value={PERFIL_INSTRUTOR}>Instrutor</option>
                      </Select>
                      <Button variant="outline" size="sm" onClick={() => openReject(r)}>
                        Recusar
                      </Button>
                      <Button
                        size="sm"
                        loading={isApprovingThis}
                        disabled={!perfil}
                        onClick={() => onApprove(r, perfil)}
                      >
                        Aprovar
                      </Button>
                    </div>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-x-6 gap-y-3 text-sm sm:grid-cols-3 md:grid-cols-4">
                    <Field label="CPF" value={r.cpf} />
                    <Field label="E-mail" value={r.email} />
                    <Field label="Telefone" value={r.phone} />
                    <Field label="Nascimento" value={formatDate(r.birthDate)} />
                    <Field label="Peso" value={r.weightKg != null ? `${r.weightKg} kg` : "—"} />
                    <Field label="Altura" value={r.heightCm != null ? `${r.heightCm} cm` : "—"} />
                  </div>

                  {r.objetivos?.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {r.objetivos.map((o) => (
                        <Badge key={o} tone="neutral">
                          {o}
                        </Badge>
                      ))}
                    </div>
                  )}

                  <div className="mt-4 flex flex-wrap items-center gap-3 rounded-md border border-line bg-surface-alt/50 px-3 py-2.5 text-sm">
                    <FileText className="h-4 w-4 shrink-0 text-content-soft" />
                    <span className="text-content-soft">
                      Atestado emitido em{" "}
                      <strong className="text-content">{formatDate(r.atestadoEmissaoData)}</strong>{" "}
                      por {r.medicoNome} (CRM {r.medicoCrm}/{r.medicoCrmUf})
                    </span>
                    <Button
                      variant="outline"
                      size="sm"
                      className="ml-auto"
                      disabled={isLoadingAtestado}
                      onClick={() => viewAtestado(r)}
                    >
                      {isLoadingAtestado ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : (
                        <FileText className="h-4 w-4" />
                      )}
                      Ver atestado (PDF)
                    </Button>
                  </div>

                  {error && (
                    <div className="mt-3">
                      <ErrorBox message={error} />
                    </div>
                  )}

                  <button
                    type="button"
                    className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-brand hover:underline"
                    onClick={() => setExpandedId(expanded ? null : r.studentId)}
                  >
                    {expanded ? (
                      <>
                        Ocultar detalhes <ChevronUp className="h-3.5 w-3.5" />
                      </>
                    ) : (
                      <>
                        Ver detalhes (PAR-Q e termos) <ChevronDown className="h-3.5 w-3.5" />
                      </>
                    )}
                  </button>

                  {expanded && (
                    <div className="mt-3 space-y-4 border-t border-line pt-4">
                      <div>
                        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-content-faint">
                          Questionário PAR-Q
                        </p>
                        <ul className="space-y-2 text-sm">
                          {PARQ_QUESTIONS.map(({ key, label }) => {
                            const answeredYes = !!r.parQ?.[key];
                            return (
                              <li key={key} className="flex items-start justify-between gap-3">
                                <span className="text-content-soft">{label}</span>
                                <Badge tone={answeredYes ? "warning" : "success"}>
                                  {answeredYes ? "Sim" : "Não"}
                                </Badge>
                              </li>
                            );
                          })}
                        </ul>
                      </div>
                      <div className="grid gap-2 text-xs text-content-soft sm:grid-cols-2">
                        <div>
                          Termo de responsabilidade aceito em{" "}
                          <strong className="text-content">
                            {formatDateTime(r.termoResponsabilidadeAceitoEm)}
                          </strong>
                        </div>
                        <div>
                          Termo de ciência aceito em{" "}
                          <strong className="text-content">
                            {formatDateTime(r.termoCienciaAceitoEm)}
                          </strong>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Modal
        open={!!instrutorTarget}
        onClose={() => !approve.isPending && setInstrutorTarget(null)}
        title={`Aprovar ${instrutorTarget?.fullName ?? ""} como instrutor?`}
        footer={
          <>
            <Button variant="outline" onClick={() => setInstrutorTarget(null)} disabled={approve.isPending}>
              Cancelar
            </Button>
            <Button
              loading={approve.isPending}
              onClick={() =>
                instrutorTarget &&
                approve.mutate({ studentId: instrutorTarget.studentId, perfil: PERFIL_INSTRUTOR })
              }
            >
              Aprovar como instrutor
            </Button>
          </>
        }
      >
        <div className="space-y-2 text-sm text-content-soft">
          <p>
            O instrutor prescreve as fichas de treino dos alunos, pelo aplicativo e por este painel, e
            passa a ver os dados dos alunos.
          </p>
          <p>
            Ele não agenda horário nem vê as telas de aluno no aplicativo, e a catraca da academia fica
            liberada para ele de forma permanente.
          </p>
        </div>
      </Modal>

      <Modal
        open={!!rejectTarget}
        onClose={closeReject}
        title={`Recusar cadastro${rejectTarget ? ` de ${rejectTarget.fullName}` : ""}`}
        footer={
          <>
            <Button variant="outline" onClick={closeReject} disabled={reject.isPending}>
              Cancelar
            </Button>
            <Button variant="danger" loading={reject.isPending} onClick={submitReject}>
              Confirmar recusa
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <div>
            <Label htmlFor="reject-motivo">Motivo da recusa</Label>
            <Textarea
              id="reject-motivo"
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Esse texto será exibido ao aluno quando ele tentar entrar."
              autoFocus
            />
          </div>
          {rejectError && <ErrorBox message={rejectError} />}
        </div>
      </Modal>
    </div>
  );
}
