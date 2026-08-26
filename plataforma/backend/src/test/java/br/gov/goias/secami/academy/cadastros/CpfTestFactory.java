package br.gov.goias.secami.academy.cadastros;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * Gera CPFs válidos (dígitos verificadores corretos, módulo 11) e únicos
 * dentro da JVM de teste, para não colidir com a constraint
 * {@code student.cpf UNIQUE} entre casos de teste. Implementação
 * independente da de {@link br.gov.goias.secami.common.Cpf#isValid}, para
 * servir de verificação cruzada nos testes de validação.
 */
public final class CpfTestFactory {

    private static final AtomicInteger COUNTER = new AtomicInteger(1);

    private CpfTestFactory() {}

    /** Próximo CPF válido da sequência, só dígitos (11 caracteres). */
    public static String next() {
        int n = COUNTER.getAndIncrement();
        // Base de 9 dígitos, sempre com dígitos não todos iguais.
        String base = String.format("1%08d", n);
        int[] d = new int[11];
        for (int i = 0; i < 9; i++) d[i] = base.charAt(i) - '0';
        d[9] = checkDigit(d, 9);
        d[10] = checkDigit(d, 10);

        StringBuilder sb = new StringBuilder(11);
        for (int digit : d) sb.append(digit);
        return sb.toString();
    }

    private static int checkDigit(int[] d, int length) {
        int sum = 0;
        int weight = length + 1;
        for (int i = 0; i < length; i++) {
            sum += d[i] * weight--;
        }
        int mod = sum % 11;
        return mod < 2 ? 0 : 11 - mod;
    }
}
