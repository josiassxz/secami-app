package br.gov.goias.secami.accelero;

import br.gov.goias.secami.academy.appointment.AppointmentDtos;

import java.util.List;

public final class AcceleroRelatorioDtos {

    private AcceleroRelatorioDtos() {}

    /** Uma passagem real na catraca ("Passagem efetivamente realizada"), com a
     *  direção classificada a partir do controlador/área do evento. */
    public record Passagem(String dataHora, String direcao, String controlador, String area) {}

    /** Agendamentos (com status — inclui "faltou", já calculado pelo AbsenceService)
     *  lado a lado com as passagens reais na catraca, pro aluno e pro admin
     *  conferirem entrada/saída/faltas no mesmo período. */
    public record RelatorioAcessos(
            List<AppointmentDtos.Response> agendamentos,
            List<Passagem> passagens,
            boolean vinculadoAoAccelero) {}
}
