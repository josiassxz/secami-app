package br.gov.goias.secami.auth.ldap;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/** Acesso ao diretório (AD): busca o usuário e confere a senha. Interface
 *  separada da implementação JNDI pra dar pra testar o vínculo/regras sem
 *  depender de rede até o DC. */
public interface LdapDirectory {

    /** @param identificador sAMAccountName, ou e-mail/UPN (se tiver "@").
     *  @throws LdapUnavailableException se o AD estiver inacessível. */
    LdapAuthResult authenticate(String identificador, String senha);

    /** Busca em lote, no AD, as contas ativas cujo CPF (campo configurado, texto
     *  livre) é um dos informados. A chave do mapa é o CPF só com dígitos; mais
     *  de uma conta na lista = CPF ambíguo (quem chama decide o que fazer).
     *  CPFs sem conta no AD simplesmente não aparecem no mapa.
     *  @throws LdapUnavailableException se o AD estiver inacessível. */
    Map<String, List<LdapUser>> buscarPorCpfs(Collection<String> cpfs);
}
