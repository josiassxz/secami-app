package br.gov.goias.secami.common;

/** Utilitário de CPF: normalização (só dígitos), formatação e mascaramento (LGPD). */
public final class Cpf {

    private Cpf() {}

    /** Remove tudo que não é dígito. Retorna null se entrada nula/vazia. */
    public static String normalize(String raw) {
        if (raw == null) return null;
        String digits = raw.replaceAll("\\D", "");
        return digits.isEmpty() ? null : digits;
    }

    /** Formata 11 dígitos como 000.000.000-00 (ou devolve como está se não tiver 11). */
    public static String format(String digits) {
        if (digits == null || digits.length() != 11) return digits;
        return digits.substring(0, 3) + "." + digits.substring(3, 6) + "."
                + digits.substring(6, 9) + "-" + digits.substring(9);
    }

    /** Mascara para listagens: 000.***.***-00. */
    public static String mask(String digits) {
        if (digits == null || digits.length() != 11) return digits;
        return digits.substring(0, 3) + ".***.***-" + digits.substring(9);
    }

    /**
     * Valida CPF: 11 dígitos, não todos iguais (000.000.000-00, 111.111.111-11 etc.
     * passam o algoritmo mas não são CPFs reais) e dígitos verificadores corretos
     * (módulo 11). Aceita entrada crua (com ou sem máscara) ou já normalizada.
     * SPEC §8.2: "cpf ... validado".
     */
    public static boolean isValid(String raw) {
        String digits = normalize(raw);
        if (digits == null || digits.length() != 11) return false;
        if (digits.chars().distinct().count() == 1) return false;

        int[] d = digits.chars().map(c -> c - '0').toArray();
        return d[9] == checkDigit(d, 9) && d[10] == checkDigit(d, 10);
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
