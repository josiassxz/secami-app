package br.gov.goias.secami.auth.ldap;

/** Resultado de uma tentativa de login no AD — distingue "não existe no AD"
 *  de "senha errada", já que só o segundo caso conta pro bloqueio (throttle)
 *  e pode bloquear a conta real da pessoa no AD. */
public record LdapAuthResult(Status status, LdapUser user) {

    public enum Status { AUTENTICADO, NAO_ENCONTRADO, SENHA_INVALIDA }

    public static LdapAuthResult autenticado(LdapUser u) { return new LdapAuthResult(Status.AUTENTICADO, u); }
    public static LdapAuthResult naoEncontrado() { return new LdapAuthResult(Status.NAO_ENCONTRADO, null); }
    public static LdapAuthResult senhaInvalida() { return new LdapAuthResult(Status.SENHA_INVALIDA, null); }
}
