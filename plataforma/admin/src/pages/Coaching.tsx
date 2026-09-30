import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Avatar, Button, Card, CardContent, TableSkeleton, Table, TBody, TD, TH, THead, TR } from "@/components/ui";
import { Ticket, Copy, Check, Users } from "lucide-react";

export default function Coaching() {
  const [codigo, setCodigo] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const alunos = useQuery({ queryKey: ["coach-students"], queryFn: () => api(`/coach/students`) });
  const gerar = useMutation({
    mutationFn: () => api(`/coach/invites`, { method: "POST", body: JSON.stringify({}) }),
    onSuccess: (data: any) => setCodigo(data.codigo),
  });

  function copy() {
    if (codigo) {
      navigator.clipboard.writeText(codigo);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }
  }

  return (
    <div>
      <PageHeader title="Coaching" subtitle="Vínculos instrutor ↔ aluno" />

      <Card className="mb-6 overflow-hidden">
        <CardContent className="pt-5">
          <div className="flex flex-wrap items-center gap-4">
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-brand-container text-brand">
              <Ticket className="h-5 w-5" />
            </span>
            <div className="min-w-[200px] flex-1">
              <h3 className="font-semibold text-content">Convidar aluno</h3>
              <p className="text-sm text-content-soft">Gere um código para o aluno resgatar no app e criar o vínculo.</p>
            </div>
            <Button loading={gerar.isPending} onClick={() => gerar.mutate()}>
              <Ticket className="h-4 w-4" /> Gerar convite
            </Button>
          </div>
        </CardContent>
        {codigo && (
          <div className="border-t border-line bg-brand-container/30 px-5 py-5">
            <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-content-soft">
              Código do convite gerado
            </p>
            <div className="flex flex-wrap items-center gap-3">
              <span className="rounded-md border border-dashed border-brand/40 bg-surface px-4 py-2 text-2xl font-bold tracking-[0.3em] text-brand">
                {codigo}
              </span>
              <Button variant="outline" onClick={copy}>
                {copied ? <Check className="h-4 w-4 text-success" /> : <Copy className="h-4 w-4" />}
                {copied ? "Copiado" : "Copiar"}
              </Button>
            </div>
            <p className="mt-2 text-xs text-content-soft">
              Peça para o aluno inserir esse código no app para concluir o vínculo.
            </p>
          </div>
        )}
      </Card>

      <Card>
        <CardContent className="pt-5">
          <div className="mb-3 flex items-center justify-between gap-2">
            <h3 className="font-semibold text-content">Meus alunos</h3>
            {!alunos.isLoading && (alunos.data || []).length > 0 && (
              <span className="text-xs text-content-soft">{alunos.data.length} vinculado{alunos.data.length === 1 ? "" : "s"}</span>
            )}
          </div>
          {alunos.isLoading ? (
            <TableSkeleton rows={4} />
          ) : (
            <Table>
              <THead><TR><TH>Aluno</TH><TH>E-mail</TH><TH>Desde</TH></TR></THead>
              <TBody>
                {(alunos.data || []).map((v: any) => (
                  <TR key={v.id}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar name={v.aluno.nome} />
                        <span className="font-medium">{v.aluno.nome}</span>
                      </div>
                    </TD>
                    <TD className="text-content-soft">{v.aluno.email || "—"}</TD>
                    <TD className="text-content-soft">{formatDate(v.aceitoEm)}</TD>
                  </TR>
                ))}
                {(alunos.data || []).length === 0 && (
                  <TR>
                    <TD colSpan={3} className="py-10 text-center text-content-soft">
                      <div className="flex flex-col items-center gap-2">
                        <Users className="h-8 w-8 text-content-faint" />
                        Nenhum aluno vinculado ainda.
                      </div>
                    </TD>
                  </TR>
                )}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
