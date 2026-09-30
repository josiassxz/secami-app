package br.gov.goias.secami.auth.ldap;

/** DC inacessível/timeout — diferente de "credencial inválida". */
public class LdapUnavailableException extends RuntimeException {
    public LdapUnavailableException(String message, Throwable cause) { super(message, cause); }
}
