package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.EmailInstitucional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Atualização em lote do e-mail dos alunos a partir de uma lista (CPF,
 * e-mail) — ex.: planilha de respostas em que cada aluno informou o e-mail
 * institucional. O casamento é pelo CPF.
 *
 * <p>Mesma regra das outras fontes (AD, Accelero): só o e-mail de CONTATO do
 * aluno ({@code student.email}, usado nos lembretes) muda — o e-mail de login
 * ({@code app_user.email}) fica como está, pra ninguém ser trancado pra fora.
 *
 * <p>Correções seguras feitas antes de validar: letra acentuada vira a letra
 * sem acento ("joão" → "joao" — caixa postal não tem acento) e ponto sobrando
 * logo depois do "@" é removido.
 *
 * <p>Proteções: CPF inválido e e-mail mal formatado são recusados; domínio
 * que parece erro de digitação de goias.gov.br (ex.: "goiad.gov.br") não é
 * aplicado; e um e-mail do governo já cadastrado nunca é trocado por um de
 * provedor pessoal (gmail etc.).
 */
@Service
public class StudentEmailService {

    private static final Logger log = LoggerFactory.getLogger(StudentEmailService.class);
    private static final Pattern EMAIL =
            Pattern.compile("^[a-z0-9._%+-]+@[a-z0-9-]+(\\.[a-z0-9-]+)+$");
    private static final String DOMINIO_GOV = "goias.gov.br";
    private static final Set<String> PROVEDORES_PESSOAIS = Set.of(
            "gmail.com", "hotmail.com", "outlook.com", "live.com", "yahoo.com", "yahoo.com.br",
            "icloud.com", "bol.com.br", "uol.com.br", "terra.com.br", "msn.com");
    private static final int LIMITE_OCORRENCIAS = 300;

    private final StudentRepository students;

    public StudentEmailService(StudentRepository students) {
        this.students = students;
    }

    public record Item(String cpf, String email) {}

    /** Linha que não foi aplicada (ou foi, em {@code atualizado}) e por quê. CPF mascarado. */
    public record Ocorrencia(String cpf, String email, String situacao) {}

    /**
     * @param recebidos       linhas recebidas
     * @param cpfsDistintos   CPFs distintos (a última linha de cada CPF vale)
     * @param atualizados     e-mail trocado (ou que seria, na simulação)
     * @param jaIguais        já estavam com esse e-mail
     * @param naoEncontrados  CPF válido, mas sem aluno ativo com ele
     * @param cpfInvalidos    CPF que não passa na validação
     * @param emailInvalidos  e-mail vazio ou mal formatado
     * @param suspeitos       domínio parece erro de digitação de goias.gov.br
     * @param mantidos        aluno já tem e-mail do governo e o informado é pessoal
     * @param corrigidos      aproveitados depois de tirar acento/ponto sobrando (já contados
     *                        em atualizados ou jaIguais)
     * @param ocorrencias     detalhe de tudo que NÃO foi aplicado (até {@value #LIMITE_OCORRENCIAS})
     */
    public record Resultado(boolean simulacao, int recebidos, int cpfsDistintos, int atualizados,
                            int jaIguais, int naoEncontrados, int cpfInvalidos, int emailInvalidos,
                            int suspeitos, int mantidos, int corrigidos, List<Ocorrencia> ocorrencias) {}

    @Transactional
    public Resultado atualizarPorCpf(List<Item> itens, boolean simular) {
        // Última linha de cada CPF vale (a pessoa pode ter respondido duas vezes).
        Map<String, String> porCpf = new LinkedHashMap<>();
        int cpfInvalidos = 0;
        List<Ocorrencia> ocorrencias = new ArrayList<>();
        for (Item item : itens) {
            String cpf = normalizarCpf(item.cpf());
            if (!Cpf.isValid(cpf)) {
                cpfInvalidos++;
                registrar(ocorrencias, item.cpf(), item.email(), "CPF inválido");
                continue;
            }
            porCpf.put(cpf, item.email());
        }

        int atualizados = 0, jaIguais = 0, naoEncontrados = 0, emailInvalidos = 0, suspeitos = 0, mantidos = 0,
                corrigidos = 0;
        for (Map.Entry<String, String> e : porCpf.entrySet()) {
            String cpf = e.getKey();
            String informado = e.getValue() == null ? "" : e.getValue().trim().toLowerCase();
            String email = corrigir(informado);
            if (!EMAIL.matcher(email).matches()) {
                emailInvalidos++;
                registrar(ocorrencias, cpf, informado, "e-mail vazio ou mal formatado");
                continue;
            }
            boolean foiCorrigido = !email.equals(informado);
            if (pareceErroDeDigitacao(email)) {
                suspeitos++;
                registrar(ocorrencias, cpf, email, "domínio parece erro de digitação de goias.gov.br");
                continue;
            }
            Student s = students.findByCpf(cpf).filter(a -> a.getDeletedAt() == null).orElse(null);
            if (s == null) {
                naoEncontrados++;
                registrar(ocorrencias, cpf, email, "nenhum aluno com este CPF");
                continue;
            }
            if (email.equalsIgnoreCase(s.getEmail())) {
                jaIguais++;
                if (foiCorrigido) corrigidos++;
                continue;
            }
            if (EmailInstitucional.ehDoGoverno(s.getEmail()) && ehProvedorPessoal(email)) {
                mantidos++;
                registrar(ocorrencias, cpf, email, "mantido o e-mail do governo já cadastrado");
                continue;
            }
            if (!simular) {
                s.setEmail(email);
                students.save(s);
            }
            atualizados++;
            if (foiCorrigido) corrigidos++;
        }
        log.info("E-mails por CPF{}: recebidos={}, cpfsDistintos={}, atualizados={}, jaIguais={}, "
                        + "naoEncontrados={}, cpfInvalidos={}, emailInvalidos={}, suspeitos={}, mantidos={}, "
                        + "corrigidos={}",
                simular ? " (SIMULAÇÃO)" : "", itens.size(), porCpf.size(), atualizados, jaIguais,
                naoEncontrados, cpfInvalidos, emailInvalidos, suspeitos, mantidos, corrigidos);
        return new Resultado(simular, itens.size(), porCpf.size(), atualizados, jaIguais, naoEncontrados,
                cpfInvalidos, emailInvalidos, suspeitos, mantidos, corrigidos, ocorrencias);
    }

    /** Tira acento das letras e ponto(s) logo depois do "@" — erros de digitação
     *  com uma única correção possível. Espaço no meio NÃO é corrigido (poderia
     *  ser "joao.silva" ou "joaosilva"): fica pra conferência manual. */
    static String corrigir(String email) {
        String semAcento = Normalizer.normalize(email, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return semAcento.replaceAll("@\\.+", "@");
    }

    /** Planilha costuma guardar CPF como número e perder os zeros à esquerda. */
    private static String normalizarCpf(String raw) {
        String digitos = Cpf.normalize(raw);
        if (digitos == null) return null;
        if (digitos.length() >= 9 && digitos.length() < 11) {
            digitos = "0".repeat(11 - digitos.length()) + digitos;
        }
        return digitos;
    }

    private static String dominio(String email) {
        return email.substring(email.lastIndexOf('@') + 1);
    }

    private static boolean ehProvedorPessoal(String email) {
        return PROVEDORES_PESSOAIS.contains(dominio(email));
    }

    /** Domínio a até 2 letras de distância de goias.gov.br, sem ser ele (nem um
     *  subdomínio legítimo): "goiad.gov.br", "goias.gov.b", "goais.gov.br"... */
    static boolean pareceErroDeDigitacao(String email) {
        String d = dominio(email);
        if (d.equals(DOMINIO_GOV) || d.endsWith("." + DOMINIO_GOV)) return false;
        return distancia(d, DOMINIO_GOV) <= 2;
    }

    private static int distancia(String a, String b) {
        int[] anterior = new int[b.length() + 1];
        for (int j = 0; j <= b.length(); j++) anterior[j] = j;
        for (int i = 1; i <= a.length(); i++) {
            int[] atual = new int[b.length() + 1];
            atual[0] = i;
            for (int j = 1; j <= b.length(); j++) {
                int custo = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                atual[j] = Math.min(Math.min(atual[j - 1] + 1, anterior[j] + 1), anterior[j - 1] + custo);
            }
            anterior = atual;
        }
        return anterior[b.length()];
    }

    private static void registrar(List<Ocorrencia> ocorrencias, String cpf, String email, String situacao) {
        if (ocorrencias.size() >= LIMITE_OCORRENCIAS) return;
        String digitos = Cpf.normalize(cpf);
        ocorrencias.add(new Ocorrencia(digitos == null ? "" : Cpf.mask(digitos), email, situacao));
    }
}
