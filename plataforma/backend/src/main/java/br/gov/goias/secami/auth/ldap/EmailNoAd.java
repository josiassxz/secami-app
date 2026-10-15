package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Confere no AD o e-mail que o admin grava no cadastro do aluno: o e-mail de
 * contato é o que liga o login pelo governo à conta da academia (ver
 * {@link LdapAuthProvider}), então só vale se existir no AD e for da mesma
 * pessoa (mesma trava do primeiro nome). Sem AD configurado
 * ({@code secami.ldap.enabled=false}) não confere nada.
 */
@Component
public class EmailNoAd {

    private final ObjectProvider<LdapDirectory> directory;

    public EmailNoAd(ObjectProvider<LdapDirectory> directory) {
        this.directory = directory;
    }

    /** @return o e-mail normalizado (minúsculas, sem espaços).
     *  @throws BusinessException se não existir no AD, for de outra pessoa ou o AD estiver fora. */
    public String conferir(String email, String nomeDoAluno) {
        String normalizado = email.trim().toLowerCase();
        LdapDirectory ad = directory.getIfAvailable();
        if (ad == null) return normalizado;

        Optional<LdapUser> conta;
        try {
            conta = ad.buscarPorEmail(normalizado);
        } catch (LdapUnavailableException e) {
            throw new BusinessException("Não foi possível validar o e-mail no AD agora. Tente de novo em instantes.");
        }
        LdapUser usuario = conta.orElseThrow(() -> new BusinessException(
                "Não foi possível alterar o e-mail porque esse usuário não existe no AD."));
        if (!LdapAuthProvider.mesmoPrimeiroNome(usuario.nome(), nomeDoAluno)) {
            throw new BusinessException("Não foi possível alterar o e-mail: no AD ele pertence a "
                    + usuario.nome() + ".");
        }
        return normalizado;
    }
}
