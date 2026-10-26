package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.auth.AuthProvider;
import br.gov.goias.secami.common.EmailInstitucional;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Login com a conta do governo (AD): a senha é conferida no AD, mas quem
 * entra é sempre um {@code app_user} que JÁ existe (cadastro público ou criado
 * pelo admin) — o AD prova a identidade, não cria conta. Roda depois do
 * {@link br.gov.goias.secami.auth.LocalAuthProvider}: senha local continua
 * valendo, e a do governo é a alternativa.
 *
 * <p>Vínculo AD → conta local, em ordem: objectGUID já vinculado; sAMAccountName
 * já vinculado; e-mail (mail/UPN) igual ao da conta; e-mail igual ao de contato
 * do aluno (com o primeiro nome batendo); CPF (guardado no AD, campo
 * {@code description}) igual ao do aluno — este último só se o primeiro nome
 * também bater, pra um CPF digitado errado no AD nunca entregar a conta de
 * outra pessoa. Vinculada uma vez, passa a valer o objectGUID.
 */
@Component
@Order(2)
@ConditionalOnProperty(name = "secami.ldap.enabled", havingValue = "true")
public class LdapAuthProvider implements AuthProvider {

    private static final Logger log = LoggerFactory.getLogger(LdapAuthProvider.class);

    private final LdapDirectory directory;
    private final AppUserRepository users;
    private final StudentRepository students;
    private final LoginThrottle throttle;

    public LdapAuthProvider(LdapDirectory directory, AppUserRepository users,
                             StudentRepository students, SecamiProperties props) {
        this.directory = directory;
        this.users = users;
        this.students = students;
        SecamiProperties.Ldap cfg = props.getLdap();
        this.throttle = new LoginThrottle(cfg.getMaxFailedAttempts(), Duration.ofMinutes(cfg.getLockoutMinutes()));
    }

    @Override
    public Optional<UUID> authenticate(String identificador, String senha) {
        if (identificador == null || identificador.isBlank() || senha == null || senha.isBlank()) {
            return Optional.empty();
        }
        if (throttle.bloqueado(identificador)) {
            throw new BusinessException("Muitas tentativas com a conta do governo. Aguarde "
                    + throttle.minutosRestantes(identificador) + " minuto(s) e tente de novo.");
        }

        LdapAuthResult resultado;
        try {
            resultado = directory.authenticate(identificador, senha);
        } catch (LdapUnavailableException e) {
            log.error("Login LDAP indisponível pra '{}': {}", identificador, e.getMessage(), e);
            throw new BusinessException(
                    "Não foi possível validar sua conta do governo agora. Tente de novo em instantes.");
        }

        return switch (resultado.status()) {
            case NAO_ENCONTRADO -> Optional.empty();
            case SENHA_INVALIDA -> {
                throttle.registrarFalha(identificador);
                yield Optional.empty();
            }
            case AUTENTICADO -> {
                throttle.limpar(identificador);
                yield Optional.of(vincular(resultado.user()).getId());
            }
        };
    }

    private AppUser vincular(LdapUser ad) {
        AppUser user = acharContaLocal(ad).orElseThrow(() -> {
            log.info("LDAP: '{}' autenticou no AD mas não tem conta local vinculável.", ad.samAccountName());
            return new BusinessException("Suas credenciais do governo estão corretas, mas não encontramos uma conta "
                    + "da academia vinculada a você. Faça o cadastro pelo aplicativo ou procure a administração.");
        });
        if (ad.guid() != null && user.getLdapGuid() != null && !ad.guid().equals(user.getLdapGuid())) {
            throw new BusinessException(
                    "Esta conta da academia já está vinculada a outra identidade do governo. Procure a administração.");
        }
        boolean mudou = false;
        if (user.getLdapGuid() == null && ad.guid() != null) {
            user.setLdapGuid(ad.guid());
            mudou = true;
        }
        if (user.getSamAccountName() == null && ad.samAccountName() != null) {
            user.setSamAccountName(ad.samAccountName());
            mudou = true;
        }
        if (mudou) {
            users.save(user);
            log.info("LDAP: conta {} vinculada ao AD ({}).", user.getId(), ad.samAccountName());
        }
        atualizarEmailDeContato(user, ad);
        return user;
    }

    /** A cada login pelo AD, o e-mail de contato do aluno (usado nos lembretes)
     *  acompanha o e-mail institucional de lá — só o contato; o e-mail de login
     *  ({@code app_user.email}) não muda. */
    private void atualizarEmailDeContato(AppUser user, LdapUser ad) {
        Optional<String> novo = EmailInstitucional.normalizar(ad.email());
        if (novo.isEmpty()) return;
        students.findByUserId(user.getId()).ifPresent(aluno -> {
            if (!novo.get().equalsIgnoreCase(aluno.getEmail())) {
                aluno.setEmail(novo.get());
                students.save(aluno);
                log.info("LDAP: e-mail de contato do aluno {} atualizado pelo AD.", aluno.getId());
            }
        });
    }

    private Optional<AppUser> acharContaLocal(LdapUser ad) {
        if (ad.guid() != null) {
            Optional<AppUser> porGuid = users.findByLdapGuid(ad.guid());
            if (porGuid.isPresent()) return porGuid;
        }
        if (ad.samAccountName() != null) {
            Optional<AppUser> porSam = users.findBySamAccountNameIgnoreCase(ad.samAccountName());
            if (porSam.isPresent()) return porSam;
        }
        // O mail e o UPN do AD podem ser diferentes — tenta os dois.
        for (String email : ad.emails()) {
            Optional<AppUser> porEmail = users.findByEmailIgnoreCase(email);
            if (porEmail.isPresent()) return porEmail;
        }
        for (String email : ad.emails()) {
            Optional<AppUser> porEmailDeContato = acharPorEmailDeContato(ad, email);
            if (porEmailDeContato.isPresent()) return porEmailDeContato;
        }
        return acharPorCpf(ad);
    }

    /**
     * E-mail do AD igual ao e-mail de CONTATO do aluno — caso dos migrados da
     * base antiga: o login ficou com o e-mail pessoal e o institucional chegou
     * depois (planilha/AD) só no contato. Mesma trava do CPF (primeiro nome tem
     * que bater), e e-mail repetido em mais de um aluno não vincula ninguém.
     */
    private Optional<AppUser> acharPorEmailDeContato(LdapUser ad, String email) {
        List<Student> alunos = students.findByEmailIgnoreCaseAndDeletedAtIsNull(email).stream()
                .filter(s -> s.getUserId() != null)
                .toList();
        if (alunos.size() != 1) {
            if (alunos.size() > 1) {
                log.warn("LDAP: e-mail de '{}' é contato de {} alunos — vínculo por e-mail de contato recusado.",
                        ad.samAccountName(), alunos.size());
            }
            return Optional.empty();
        }
        Student aluno = alunos.get(0);
        if (!mesmoPrimeiroNome(ad.nome(), aluno.getFullName())) {
            log.warn("LDAP: e-mail de '{}' é contato do aluno {}, mas o primeiro nome difere — vínculo recusado.",
                    ad.samAccountName(), aluno.getId());
            return Optional.empty();
        }
        return users.findById(aluno.getUserId());
    }

    private Optional<AppUser> acharPorCpf(LdapUser ad) {
        if (ad.cpf() == null) return Optional.empty();
        Optional<Student> aluno = students.findByCpf(ad.cpf());
        if (aluno.isEmpty() || aluno.get().getUserId() == null) return Optional.empty();
        if (!mesmoPrimeiroNome(ad.nome(), aluno.get().getFullName())) {
            log.warn("LDAP: CPF de '{}' bate com o aluno {}, mas o primeiro nome difere — vínculo recusado.",
                    ad.samAccountName(), aluno.get().getId());
            return Optional.empty();
        }
        return users.findById(aluno.get().getUserId());
    }

    static boolean mesmoPrimeiroNome(String a, String b) {
        String pa = primeiroNome(a);
        return !pa.isEmpty() && pa.equals(primeiroNome(b));
    }

    private static String primeiroNome(String nome) {
        if (nome == null || nome.isBlank()) return "";
        String semAcento = Normalizer.normalize(nome.trim(), Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return semAcento.split("\\s+")[0].toLowerCase();
    }
}
