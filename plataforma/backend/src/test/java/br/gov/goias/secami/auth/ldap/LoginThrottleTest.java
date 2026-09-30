package br.gov.goias.secami.auth.ldap;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

class LoginThrottleTest {

    /** Relógio que a gente avança na mão. */
    private static class RelogioFalso extends Clock {
        private Instant agora = Instant.parse("2026-09-21T12:00:00Z");
        void avancar(Duration d) { agora = agora.plus(d); }
        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return agora; }
    }

    @Test
    void bloqueiaSoDepoisDoLimiteDeFalhas() {
        LoginThrottle t = new LoginThrottle(3, Duration.ofMinutes(15), new RelogioFalso());

        t.registrarFalha("josias.ssiqueira");
        t.registrarFalha("josias.ssiqueira");
        assertThat(t.bloqueado("josias.ssiqueira")).isFalse();

        t.registrarFalha("josias.ssiqueira");
        assertThat(t.bloqueado("josias.ssiqueira")).isTrue();
    }

    @Test
    void desbloqueiaQuandoAJanelaPassa() {
        RelogioFalso relogio = new RelogioFalso();
        LoginThrottle t = new LoginThrottle(2, Duration.ofMinutes(15), relogio);
        t.registrarFalha("x");
        t.registrarFalha("x");
        assertThat(t.bloqueado("x")).isTrue();

        relogio.avancar(Duration.ofMinutes(16));

        assertThat(t.bloqueado("x")).isFalse();
    }

    @Test
    void loginBemSucedidoZeraOContador() {
        LoginThrottle t = new LoginThrottle(2, Duration.ofMinutes(15), new RelogioFalso());
        t.registrarFalha("x");
        t.limpar("x");
        t.registrarFalha("x");

        assertThat(t.bloqueado("x")).isFalse();
    }

    @Test
    void identificadorNaoDistingueMaiusculasNemEspacos() {
        LoginThrottle t = new LoginThrottle(2, Duration.ofMinutes(15), new RelogioFalso());
        t.registrarFalha("Fulano@Goias.gov.br");
        t.registrarFalha(" fulano@goias.gov.br ");

        assertThat(t.bloqueado("FULANO@goias.gov.br")).isTrue();
    }

    @Test
    void identificadoresDiferentesNaoSeAfetam() {
        LoginThrottle t = new LoginThrottle(1, Duration.ofMinutes(15), new RelogioFalso());
        t.registrarFalha("a");

        assertThat(t.bloqueado("b")).isFalse();
    }

    @Test
    void informaMinutosRestantesPraMensagem() {
        RelogioFalso relogio = new RelogioFalso();
        LoginThrottle t = new LoginThrottle(1, Duration.ofMinutes(15), relogio);
        t.registrarFalha("x");
        relogio.avancar(Duration.ofMinutes(10));

        assertThat(t.minutosRestantes("x")).isBetween(1L, 6L);
        assertThat(t.minutosRestantes("nunca-errou")).isZero();
    }
}
