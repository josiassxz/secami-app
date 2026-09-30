package br.gov.goias.secami.auth.ldap;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Limita tentativas de login no AD por identificador. Sem isso, qualquer um
 * poderia errar a senha de propósito, via nosso endpoint de login, na conta
 * real de um servidor até estourar o limite de bloqueio do AD (negação de
 * serviço contra contas do governo). Só conta falha de senha de usuário que
 * EXISTE no AD — identificador inexistente nunca chega a tentar bind.
 * Em memória (1 instância do backend); reinicia zerado, o que é aceitável.
 */
public class LoginThrottle {

    private static final int LIMITE_DE_CHAVES = 5000;

    private final int maxFalhas;
    private final Duration janela;
    private final Clock clock;
    private final Map<String, Deque<Instant>> falhas = new ConcurrentHashMap<>();

    public LoginThrottle(int maxFalhas, Duration janela) {
        this(maxFalhas, janela, Clock.systemDefaultZone());
    }

    LoginThrottle(int maxFalhas, Duration janela, Clock clock) {
        this.maxFalhas = maxFalhas;
        this.janela = janela;
        this.clock = clock;
    }

    public boolean bloqueado(String chave) {
        Deque<Instant> q = falhas.get(normalizar(chave));
        if (q == null) return false;
        synchronized (q) {
            podarExpiradas(q);
            return q.size() >= maxFalhas;
        }
    }

    public void registrarFalha(String chave) {
        if (falhas.size() > LIMITE_DE_CHAVES) limparExpiradas();
        Deque<Instant> q = falhas.computeIfAbsent(normalizar(chave), k -> new ArrayDeque<>());
        synchronized (q) {
            podarExpiradas(q);
            q.addLast(clock.instant());
        }
    }

    public void limpar(String chave) {
        falhas.remove(normalizar(chave));
    }

    /** Minutos até liberar (pra mensagem ao usuário), no mínimo 1. */
    public long minutosRestantes(String chave) {
        Deque<Instant> q = falhas.get(normalizar(chave));
        if (q == null) return 0;
        synchronized (q) {
            podarExpiradas(q);
            if (q.size() < maxFalhas) return 0;
            Duration restante = Duration.between(clock.instant(), q.peekFirst().plus(janela));
            return Math.max(1, restante.toMinutes() + 1);
        }
    }

    private void podarExpiradas(Deque<Instant> q) {
        Instant limite = clock.instant().minus(janela);
        while (!q.isEmpty() && q.peekFirst().isBefore(limite)) q.removeFirst();
    }

    private void limparExpiradas() {
        falhas.entrySet().removeIf(e -> {
            synchronized (e.getValue()) {
                podarExpiradas(e.getValue());
                return e.getValue().isEmpty();
            }
        });
    }

    private static String normalizar(String chave) {
        return chave == null ? "" : chave.trim().toLowerCase();
    }
}
