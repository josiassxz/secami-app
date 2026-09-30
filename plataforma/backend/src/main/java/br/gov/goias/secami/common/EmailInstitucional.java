package br.gov.goias.secami.common;

import java.util.Optional;

/** Regra do e-mail institucional (@goias.gov.br) — em um lugar só. */
public final class EmailInstitucional {

    public static final String DOMINIO = "@goias.gov.br";

    private EmailInstitucional() {}

    /** @return o e-mail normalizado (minúsculas, sem espaços) se for do domínio
     *  institucional; vazio se nulo/vazio/de outro domínio. */
    public static Optional<String> normalizar(String email) {
        if (email == null || email.isBlank()) return Optional.empty();
        String n = email.trim().toLowerCase();
        return n.endsWith(DOMINIO) && n.length() > DOMINIO.length() ? Optional.of(n) : Optional.empty();
    }

    /** E-mail do governo em sentido amplo: @goias.gov.br ou um subdomínio dele
     *  (ex.: @fornecedores.goias.gov.br, dos terceirizados). Usado pra nunca
     *  trocar um e-mail institucional por um pessoal numa atualização em lote. */
    public static boolean ehDoGoverno(String email) {
        if (email == null || email.isBlank()) return false;
        String n = email.trim().toLowerCase();
        int arroba = n.lastIndexOf('@');
        if (arroba <= 0 || arroba == n.length() - 1) return false;
        String dominio = n.substring(arroba + 1);
        return dominio.equals("goias.gov.br") || dominio.endsWith(".goias.gov.br");
    }
}
