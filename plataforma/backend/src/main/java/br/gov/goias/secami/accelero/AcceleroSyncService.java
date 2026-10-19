package br.gov.goias.secami.accelero;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentDtos;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import br.gov.goias.secami.accelero.AcceleroDtos.EventoAcesso;
import br.gov.goias.secami.accelero.AcceleroDtos.IdentificadorVinculado;
import br.gov.goias.secami.accelero.AcceleroDtos.PaginaEventos;
import br.gov.goias.secami.accelero.AcceleroDtos.PessoaEncontrada;
import br.gov.goias.secami.accelero.AcceleroRelatorioDtos.Passagem;
import br.gov.goias.secami.accelero.AcceleroRelatorioDtos.RelatorioAcessos;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Regra de negócio da integração com o Accelero (catracas da academia),
 * disparada ao aprovar um cadastro (SPEC: aluno aprovado ganha acesso físico
 * à academia) — ver {@link #aoAprovar}. Toda chamada ao Accelero aqui é
 * best-effort: uma falha de rede/sessão NUNCA pode derrubar a aprovação de
 * um cadastro, só fica registrada em log pra o admin resolver depois (via
 * {@link #ressincronizar} ou a sincronização em lote).
 *
 * <p>Regra: existe uma única categoria (1213819408) que libera entrada e
 * saída juntas. Militar recebe ela vitalícia na aprovação. Civil não recebe
 * nada na aprovação — a categoria é liberada de forma dinâmica a cada
 * agendamento confirmado (ver {@link #aoAgendar}), de 20min antes do horário
 * marcado, sempre por uma janela fixa de 2h a partir do início marcado
 * (treino + banho) — e revogada se o agendamento for cancelado (ver
 * {@link #aoCancelar}) ou removida pelo job de limpeza depois que a janela
 * expira, mesmo sem cancelamento (ver {@link #aoExpirarAcesso}).
 *
 * <p>Toda vez que uma categoria é adicionada ou removida, os identificadores
 * da pessoa são desassociados em seguida (ver {@link #ressincronizarPessoa})
 * — isso não apaga a credencial (cartão/rosto), só força a catraca a
 * recarregar o conjunto de categorias atual.
 */
@Service
public class AcceleroSyncService {

    private static final Logger log = LoggerFactory.getLogger(AcceleroSyncService.class);
    private static final String PASSAGEM_REALIZADA = "Passagem efetivamente realizada";
    private static final DateTimeFormatter FORMATO_LOG_EVENTOS =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    // Formato exato exigido pelo Accelero pra lpcDateStart/lpcDateEnd —
    // confirmado com uma chamada real capturada do próprio painel (o
    // comentário do script Python, "dd/MM/yyyy HH:mm", estava errado; usar
    // esse formato causava "Erro pes-661" em toda chamada com datas).
    private static final DateTimeFormatter FORMATO_ACCELERO = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    /** Prefixo da área (areDescricao) dos leitores da academia ("ACADEMIA EXT"/
     *  "ACADEMIA INT") — usado pra confirmarPresenca não confundir com outras
     *  áreas do prédio (Atalaia, Secretariado etc.) que a mesma pessoa também
     *  pode acessar (ex.: funcionário com acesso mais amplo). */
    private static final String AREA_ACADEMIA = "ACADEMIA";
    /** Libera o acesso 20min antes do horário marcado, pro caso de o aluno chegar cedo. */
    private static final long MARGEM_ANTECEDENCIA_MINUTOS = 20;
    /** Janela total liberada a partir do INÍCIO marcado (não do fim do slot) —
     *  cobre treino + banho etc., sempre fixa, independente da duração do slot. */
    private static final long JANELA_ACESSO_HORAS = 2;

    private final AcceleroClient client;
    private final SecamiProperties.Accelero config;
    private final StudentRepository students;
    private final AppointmentRepository appointments;
    private final ZoneId zone;

    public AcceleroSyncService(AcceleroClient client, SecamiProperties props,
                                StudentRepository students, AppointmentRepository appointments) {
        this.client = client;
        this.config = props.getAccelero();
        this.students = students;
        this.appointments = appointments;
        this.zone = ZoneId.of(props.getTimezone());
    }

    // ---------- gatilho da aprovação ----------

    /** Chamado por RegistrationService.aprovar() logo após ativar o usuário.
     *  Nunca lança — falha aqui não pode impedir a aprovação do cadastro. */
    @Transactional
    public void aoAprovar(Student student) {
        if (!config.isEnabled()) return;
        try {
            boolean ok = sincronizarUm(student);
            if (!ok) {
                log.warn("Aluno {} aprovado, mas não foi possível liberar a catraca agora "
                        + "(pessoa não encontrada no Accelero pelo CPF) — repetir depois via "
                        + "ressincronização manual.", student.getId());
            }
        } catch (Exception e) {
            log.warn("Falha ao sincronizar aluno {} com o Accelero na aprovação: {}",
                    student.getId(), e.getMessage());
        }
    }

    /**
     * Chamado por StudentService.update() quando o admin muda o tipo entre
     * acesso vitalício (Militar/Instrutor) e Civil — a aprovação liberava a
     * catraca, a edição não. Virar Militar/Instrutor libera a categoria
     * vitalícia; voltar a Civil tira a vitalícia e libera por agendamento os
     * horários futuros que ele já tem. Só cadastro aprovado. Nunca lança.
     */
    @Transactional
    public void aoMudarTipo(Student student) {
        if (!config.isEnabled()) return;
        if (!Student.STATUS_APROVADO.equals(student.getStatusCadastro())) return;
        try {
            if (temAcessoVitalicio(student)) {
                if (!sincronizarUm(student)) {
                    log.warn("Aluno {} virou {}, mas não foi possível liberar a catraca agora (pessoa não "
                            + "encontrada no Accelero pelo CPF).", student.getId(), student.getStudentType());
                }
            } else {
                revogarAcessoVitalicio(student);
                ZonedDateTime agora = ZonedDateTime.now(zone);
                for (Appointment a : appointments.findAtivosDoAlunoAPartirDe(student.getId(), agora.toLocalDate())) {
                    ZonedDateTime fimJanela = ZonedDateTime.of(a.getDate(), LocalTime.parse(a.getSlotStart()), zone)
                            .plusHours(JANELA_ACESSO_HORAS);
                    if (a.getAcceleroAcessoVinculoId() == null && fimJanela.isAfter(agora)) {
                        liberarAcessoDoAgendamento(a);
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Falha ao ajustar a catraca no Accelero pra mudança de tipo do aluno {}: {}",
                    student.getId(), e.getMessage(), e);
        }
    }

    /** Tira só a categoria da academia sem data (a vitalícia) — preserva as
     *  liberações de agendamentos e qualquer outra categoria do prédio. */
    private void revogarAcessoVitalicio(Student student) {
        String pessoaId = student.getAcceleroPessoaId();
        if (pessoaId == null) return;
        String categoriaId = config.getCategoriaAcessoId();
        Set<String> deAgendamentos = appointments.findAtivosDoAlunoAPartirDe(student.getId(), LocalDate.now(zone))
                .stream().map(Appointment::getAcceleroAcessoVinculoId)
                .filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        List<CategoriaVinculada> vitalicias = client.listarCategorias(pessoaId).stream()
                .filter(c -> categoriaId.equals(c.pctId()) && !deAgendamentos.contains(c.uid()))
                .toList();
        if (vitalicias.isEmpty()) return;
        for (CategoriaVinculada v : vitalicias) {
            client.excluirCategoria(pessoaId, v.uid());
        }
        ressincronizarPessoa(pessoaId);
        student.setAcceleroLiberadoEm(null);
        students.save(student);
        log.info("Acesso vitalício revogado no Accelero pro aluno {} (virou {}).", student.getId(), student.getStudentType());
    }

    public record ResultadoLiberacao(boolean simulado, int total, List<String> liberados, List<String> jaTinham,
                                     List<String> naoEncontrados, List<String> ambiguos, List<String> invalidos,
                                     List<String> erros) {}

    /**
     * Libera a categoria vitalícia da academia direto no Accelero, por CPF —
     * pra listas externas (ex.: militares da SECAMI), sem depender de cadastro
     * aqui. Só adiciona pra quem ainda não tem a categoria; idempotente.
     * Cada item do relatório: "CPF mascarado — nome no Accelero".
     */
    public ResultadoLiberacao liberarVitalicioPorCpfs(List<String> cpfs, boolean simular) {
        if (!config.isEnabled()) {
            throw new IllegalStateException("Integração com o Accelero está desligada (secami.accelero.enabled).");
        }
        String categoriaId = config.getCategoriaAcessoId();
        List<String> liberados = new ArrayList<>(), jaTinham = new ArrayList<>(), naoEncontrados = new ArrayList<>(),
                ambiguos = new ArrayList<>(), invalidos = new ArrayList<>(), erros = new ArrayList<>();
        Set<String> vistos = new java.util.LinkedHashSet<>();
        for (String bruto : cpfs) {
            String cpf = br.gov.goias.secami.common.Cpf.normalize(bruto);
            if (cpf == null || !br.gov.goias.secami.common.Cpf.isValid(cpf)) {
                invalidos.add(String.valueOf(bruto));
                continue;
            }
            if (!vistos.add(cpf)) continue;
            String rotulo = br.gov.goias.secami.common.Cpf.mask(cpf);
            try {
                List<PessoaEncontrada> achados = client.pesquisarPessoas(cpf).stream()
                        .filter(p -> p.cpf() == null || cpf.equals(somenteDigitos(p.cpf())))
                        .toList();
                if (achados.isEmpty()) { naoEncontrados.add(rotulo); continue; }
                if (achados.size() > 1) { ambiguos.add(rotulo); continue; }
                PessoaEncontrada pessoa = achados.get(0);
                rotulo = rotulo + " — " + pessoa.nome();
                boolean tem = client.listarCategorias(pessoa.uid()).stream()
                        .anyMatch(c -> categoriaId.equals(c.pctId()));
                if (tem) { jaTinham.add(rotulo); continue; }
                if (!simular) {
                    client.adicionarCategoria(pessoa.uid(), categoriaId, "", "");
                    ressincronizarPessoa(pessoa.uid());
                    log.info("Categoria {} liberada (vitalícia) direto no Accelero pra pessoa {} (lista por CPF).",
                            categoriaId, pessoa.uid());
                }
                liberados.add(rotulo);
            } catch (Exception e) {
                erros.add(rotulo + " — " + e.getMessage());
                log.warn("Falha ao liberar a categoria no Accelero pra {}: {}", rotulo, e.getMessage());
            }
        }
        return new ResultadoLiberacao(simular, vistos.size(), liberados, jaTinham, naoEncontrados, ambiguos,
                invalidos, erros);
    }

    /** Retry manual de um único aluno (ex.: falhou antes, CPF foi corrigido). */
    @Transactional
    public boolean ressincronizar(Student student) {
        if (!config.isEnabled()) {
            throw new IllegalStateException("Integração com o Accelero está desligada (secami.accelero.enabled).");
        }
        return sincronizarUm(student);
    }

    /** Roda em TODOS os aprovados, não só quem nunca foi vinculado — idempotente
     *  (sincronizarUm/liberarAcessoVitalicio só age no que ainda falta), então serve
     *  tanto pra base migrada antes desta integração existir quanto pra reprocessar
     *  quem já tinha pessoa vinculada mas ainda não tem a categoria/regra atual
     *  (ex.: depois de uma mudança de categoria no Accelero, como 1213819408
     *  substituindo as antigas 135315420/1331489832). */
    @Transactional
    public ResumoSincronizacao sincronizarBaseExistente() {
        if (!config.isEnabled()) {
            throw new IllegalStateException("Integração com o Accelero está desligada (secami.accelero.enabled).");
        }
        List<Student> candidatos = students
                .findByStatusCadastroAndDeletedAtIsNullOrderByCreatedAtAsc(Student.STATUS_APROVADO);
        int vinculados = 0, naoEncontrados = 0, erros = 0;
        for (Student s : candidatos) {
            try {
                if (sincronizarUm(s)) vinculados++; else naoEncontrados++;
            } catch (Exception e) {
                erros++;
                log.warn("Falha ao sincronizar aluno {} com o Accelero: {}", s.getId(), e.getMessage());
            }
        }
        log.info("Sincronização em lote com o Accelero: {} candidato(s), {} vinculado(s), "
                + "{} não encontrado(s), {} erro(s).", candidatos.size(), vinculados, naoEncontrados, erros);
        return new ResumoSincronizacao(candidatos.size(), vinculados, naoEncontrados, erros);
    }

    public record ResumoSincronizacao(int candidatos, int vinculados, int naoEncontrados, int erros) {}

    /** Alunos já vinculados ao Accelero (accelero_pessoa_id conhecido): confere
     *  o e-mail cadastrado lá e, se for do domínio @goias.gov.br, atualiza o
     *  nosso — o Accelero costuma ter o e-mail institucional mais atual (a
     *  base migrada trouxe majoritariamente e-mail pessoal). Não altera nada
     *  se o e-mail de lá vier vazio ou não for @goias.gov.br. */
    @Transactional
    public ResumoAtualizacaoEmail atualizarEmailsComAccelero() {
        if (!config.isEnabled()) {
            throw new IllegalStateException("Integração com o Accelero está desligada (secami.accelero.enabled).");
        }
        List<Student> candidatos = students.findByAcceleroPessoaIdIsNotNullAndDeletedAtIsNull();
        int atualizados = 0, semEmailGov = 0, erros = 0;
        for (Student s : candidatos) {
            try {
                if (atualizarEmailComAccelero(s)) atualizados++; else semEmailGov++;
            } catch (Exception e) {
                erros++;
                log.warn("Falha ao atualizar e-mail via Accelero pro aluno {}: {}", s.getId(), e.getMessage(), e);
            }
        }
        log.info("Atualização de e-mails via Accelero: {} candidato(s), {} atualizado(s), "
                + "{} sem e-mail @goias.gov.br lá, {} erro(s).", candidatos.size(), atualizados, semEmailGov, erros);
        return new ResumoAtualizacaoEmail(candidatos.size(), atualizados, semEmailGov, erros);
    }

    public record ResumoAtualizacaoEmail(int candidatos, int atualizados, int semEmailGov, int erros) {}

    private boolean atualizarEmailComAccelero(Student student) {
        AcceleroDtos.PessoaDetalhe detalhe = client.detalharPessoa(student.getAcceleroPessoaId());
        String email = detalhe.email();
        if (email == null || email.isBlank()) return false;
        String normalizado = email.trim().toLowerCase();
        if (!normalizado.endsWith("@goias.gov.br")) return false;
        if (normalizado.equals(student.getEmail())) return false; // já está certo, nada a fazer
        student.setEmail(normalizado);
        students.save(student);
        return true;
    }

    /** @return true se a pessoa foi encontrada/já estava vinculada (categoria conferida). */
    private boolean sincronizarUm(Student student) {
        if (student.getAcceleroPessoaId() == null) {
            String uid = vincularPorCpf(student);
            if (uid == null) return false;
        }
        // Civil não recebe nada na aprovação — o acesso é liberado por
        // agendamento (ver aoAgendar/liberarAcessoDoAgendamento). Instrutor
        // não agenda horário (trabalha na academia), então recebe o acesso
        // vitalício, igual ao Militar.
        if (temAcessoVitalicio(student)) {
            liberarAcessoVitalicio(student);
        }
        return true;
    }

    private static boolean temAcessoVitalicio(Student student) {
        return student.temAcessoPermanente();
    }

    private String vincularPorCpf(Student student) {
        String cpf = student.getCpf();
        if (cpf == null || cpf.isBlank()) {
            log.warn("Aluno {} sem CPF — não é possível vincular ao Accelero.", student.getId());
            return null;
        }
        List<PessoaEncontrada> encontrados = client.pesquisarPessoas(cpf);
        if (encontrados.isEmpty()) {
            log.warn("Nenhuma pessoa encontrada no Accelero para o CPF do aluno {}.", student.getId());
            return null;
        }
        // Confere o CPF devolvido quando o campo existe na resposta; pessoas sem
        // esse campo reconhecido ficam como candidatas mesmo assim (a pesquisa já
        // foi feita pelo CPF exato).
        List<PessoaEncontrada> conferidos = encontrados.stream()
                .filter(p -> p.cpf() == null || cpf.equals(somenteDigitos(p.cpf())))
                .toList();
        List<PessoaEncontrada> candidatos = conferidos.isEmpty() ? encontrados : conferidos;
        if (candidatos.size() > 1) {
            log.warn("Mais de uma pessoa no Accelero corresponde ao CPF do aluno {} — "
                    + "vinculação manual necessária.", student.getId());
            return null;
        }
        String uid = candidatos.get(0).uid();
        if (uid == null || uid.isBlank()) {
            log.warn("Pessoa encontrada no Accelero para o aluno {} sem UID na resposta.", student.getId());
            return null;
        }
        student.setAcceleroPessoaId(uid);
        students.save(student);
        return uid;
    }

    private void liberarAcessoVitalicio(Student student) {
        String pessoaId = student.getAcceleroPessoaId();
        String categoriaId = config.getCategoriaAcessoId();

        boolean jaVinculada = client.listarCategorias(pessoaId).stream()
                .map(CategoriaVinculada::pctId)
                .anyMatch(categoriaId::equals);
        if (!jaVinculada) {
            client.adicionarCategoria(pessoaId, categoriaId, "", ""); // datas vazias = vitalícia
            ressincronizarPessoa(pessoaId);
            log.info("Categoria {} liberada (vitalícia) pro aluno {} no Accelero.", categoriaId, student.getId());
        }
        student.setAcceleroLiberadoEm(OffsetDateTime.now());
        students.save(student);
    }

    private static String somenteDigitos(String s) {
        return s == null ? null : s.replaceAll("\\D", "");
    }

    /** Chamado sempre depois de adicionar/excluir uma categoria — desassocia
     *  os identificadores (cartão/biometria) da pessoa pra forçar a catraca a
     *  ressincronizar as categorias liberadas. NÃO apaga a credencial em si,
     *  só "belisca" a associação existente pra recarregar as permissões
     *  atuais (confirmado com o cliente — sem isso a catraca física pode
     *  continuar usando o conjunto de categorias antigo em cache). */
    private void ressincronizarPessoa(String pessoaId) {
        for (IdentificadorVinculado identificador : client.listarIdentificadores(pessoaId)) {
            client.desassociarIdentificador(pessoaId, identificador.uid(), identificador.carHabilitado());
        }
    }

    // ---------- acesso dinâmico por agendamento (Civil) ----------

    /** Chamado por SchedulingService ao criar um agendamento (auto ou force-book).
     *  Militar já tem acesso vitalício — não faz nada. Nunca lança. */
    @Transactional
    public void aoAgendar(Appointment appointment) {
        if (!config.isEnabled()) return;
        Student student = appointment.getStudent();
        if (temAcessoVitalicio(student)) return;
        try {
            liberarAcessoDoAgendamento(appointment);
        } catch (Exception e) {
            log.warn("Falha ao liberar acesso dinâmico no Accelero pro agendamento {}: {}",
                    appointment.getId(), e.getMessage(), e);
        }
    }

    /** Chamado por SchedulingService ao cancelar um agendamento — revoga o
     *  acesso liberado (se houver). Nunca lança. */
    @Transactional
    public void aoCancelar(Appointment appointment) {
        if (!config.isEnabled()) return;
        try {
            revogarAcessoDoAgendamento(appointment, "revogado (agendamento cancelado)");
        } catch (Exception e) {
            log.warn("Falha ao revogar acesso dinâmico no Accelero pro agendamento {}: {}",
                    appointment.getId(), e.getMessage(), e);
        }
    }

    /** Chamado pelo job de limpeza (AcceleroExpiracaoService) — remove o
     *  acesso dinâmico do civil depois que a janela liberada expirou, mesmo
     *  sem cancelamento (o agendamento simplesmente aconteceu e passou).
     *  Nunca lança. */
    @Transactional
    public void aoExpirarAcesso(Appointment appointment) {
        if (!config.isEnabled()) return;
        try {
            revogarAcessoDoAgendamento(appointment, "removido (janela expirada)");
        } catch (Exception e) {
            log.warn("Falha ao remover acesso expirado no Accelero pro agendamento {}: {}",
                    appointment.getId(), e.getMessage(), e);
        }
    }

    private void revogarAcessoDoAgendamento(Appointment appointment, String motivoLog) {
        String vinculoId = appointment.getAcceleroAcessoVinculoId();
        String pessoaId = appointment.getStudent().getAcceleroPessoaId();
        if (vinculoId == null || pessoaId == null) return;
        client.excluirCategoria(pessoaId, vinculoId);
        ressincronizarPessoa(pessoaId);
        appointment.setAcceleroAcessoVinculoId(null);
        appointment.setAcceleroAcessoExpiraEm(null);
        appointments.save(appointment);
        log.info("Acesso no Accelero {} pro agendamento {}.", motivoLog, appointment.getId());
    }

    /** Chamado por StudentService.delete() (admin cancela/desativa o aluno) —
     *  revoga TODAS as categorias vinculadas à pessoa no Accelero (acesso
     *  vitalício se Militar, qualquer janela de acesso dinâmica ainda ativa
     *  se Civil) — tira o acesso físico por completo. Best-effort, nunca
     *  impede a exclusão do aluno no nosso sistema. */
    @Transactional
    public void aoExcluirAluno(Student student) {
        if (!config.isEnabled()) return;
        String pessoaId = student.getAcceleroPessoaId();
        if (pessoaId == null) return;
        try {
            List<CategoriaVinculada> vinculos = client.listarCategorias(pessoaId);
            for (CategoriaVinculada v : vinculos) {
                client.excluirCategoria(pessoaId, v.uid());
            }
            ressincronizarPessoa(pessoaId);
            log.info("Acesso no Accelero revogado por completo pro aluno {} ({} categoria(s)).",
                    student.getId(), vinculos.size());
        } catch (Exception e) {
            log.warn("Falha ao revogar acesso no Accelero pro aluno {}: {}",
                    student.getId(), e.getMessage(), e);
        }
    }

    private void liberarAcessoDoAgendamento(Appointment appointment) {
        Student student = appointment.getStudent();
        if (student.getAcceleroPessoaId() == null && vincularPorCpf(student) == null) {
            log.warn("Agendamento {} sem pessoa vinculada no Accelero — acesso dinâmico não liberado.",
                    appointment.getId());
            return;
        }
        String pessoaId = student.getAcceleroPessoaId();
        String categoriaId = config.getCategoriaAcessoId();

        // Janela sempre a partir do INÍCIO marcado, não do fim do slot: 20min
        // antes (chegar cedo) até 2h depois (treino + banho), fixo,
        // independente de quanto dura o horário reservado.
        ZonedDateTime inicioMarcado = ZonedDateTime.of(appointment.getDate(),
                LocalTime.parse(appointment.getSlotStart()), zone);
        ZonedDateTime inicio = inicioMarcado.minusMinutes(MARGEM_ANTECEDENCIA_MINUTOS);
        ZonedDateTime fim = inicioMarcado.plusHours(JANELA_ACESSO_HORAS);

        // adicionarCategoria não devolve o UID do vínculo criado — snapshot
        // antes/depois pra identificar a linha nova (precisa pra poder
        // revogar exatamente essa liberação se o agendamento for cancelado
        // ou quando a janela expirar).
        Set<String> vinculosAntes = client.listarCategorias(pessoaId).stream()
                .map(CategoriaVinculada::uid).collect(Collectors.toSet());

        client.adicionarCategoria(pessoaId, categoriaId,
                inicio.format(FORMATO_ACCELERO), fim.format(FORMATO_ACCELERO));
        ressincronizarPessoa(pessoaId);

        String novoVinculo = client.listarCategorias(pessoaId).stream()
                .filter(c -> !vinculosAntes.contains(c.uid()) && categoriaId.equals(c.pctId()))
                .map(CategoriaVinculada::uid)
                .findFirst()
                .orElse(null);
        if (novoVinculo == null) {
            log.warn("Acesso liberado no Accelero pro agendamento {}, mas não foi possível identificar "
                    + "o vínculo criado — revogação automática no cancelamento/expiração não vai funcionar "
                    + "pra este agendamento específico.", appointment.getId());
        } else {
            log.info("Acesso liberado no Accelero pro agendamento {} ({} às {}).",
                    appointment.getId(), appointment.getDate(), appointment.getSlotStart());
        }
        appointment.setAcceleroAcessoVinculoId(novoVinculo);
        appointment.setAcceleroAcessoExpiraEm(novoVinculo == null ? null : fim.toOffsetDateTime());
        appointments.save(appointment);
    }

    // ---------- relatório de entrada/saída/faltas ----------

    /** Agendamentos (com status, incluindo "faltou") lado a lado com as
     *  passagens reais na catraca no período — pro aluno e pro admin. */
    public RelatorioAcessos relatorioAcessos(Student student, LocalDate dataInicial, LocalDate dataFinal) {
        List<AppointmentDtos.Response> agendamentos = appointments.findByStudent(student.getId()).stream()
                .filter(a -> !a.getDate().isBefore(dataInicial) && !a.getDate().isAfter(dataFinal))
                .map(AppointmentDtos.Response::from)
                .toList();

        boolean vinculado = student.getAcceleroPessoaId() != null;
        List<Passagem> passagens = vinculado
                ? buscarPassagens(student.getAcceleroPessoaId(), dataInicial, dataFinal)
                : List.of();

        return new RelatorioAcessos(agendamentos, passagens, vinculado);
    }

    private List<Passagem> buscarPassagens(String pessoaId, LocalDate dataInicial, LocalDate dataFinal) {
        String inicioStr = dataInicial.atStartOfDay().format(FORMATO_LOG_EVENTOS);
        String fimStr = dataFinal.atTime(LocalTime.of(23, 59, 59)).format(FORMATO_LOG_EVENTOS);
        List<EventoAcesso> todos = buscarTodosOsEventos(pessoaId, inicioStr, fimStr);

        return todos.stream()
                .filter(e -> e.descricao() != null && PASSAGEM_REALIZADA.equalsIgnoreCase(e.descricao().trim()))
                .map(e -> new Passagem(e.dataHora(), classificarDirecao(e), e.controlador(), e.area()))
                .toList();
    }

    private List<EventoAcesso> buscarTodosOsEventos(String pessoaId, String inicioStr, String fimStr) {
        List<EventoAcesso> todos = new ArrayList<>();
        int pagina = 1;
        int totalPaginas;
        do {
            PaginaEventos p = client.listarLogEventos(pessoaId, inicioStr, fimStr, pagina);
            todos.addAll(p.eventos());
            totalPaginas = p.totalPaginas();
            pagina++;
        } while (pagina <= totalPaginas);
        return todos;
    }

    // ---------- confirmação de presença real (job periódico) ----------

    /** Chamado pelo job de confirmação de presença (AcceleroPresencaService,
     *  a cada 30min) — consulta o log de eventos reais da catraca dentro da
     *  janela liberada do agendamento (20min antes até 2h depois do início)
     *  pra confirmar se o aluno realmente entrou e/ou saiu, além do
     *  check-in autodeclarado. Idempotente: só preenche o que ainda está
     *  em branco. Nunca lança. @return true se algo foi confirmado agora. */
    @Transactional
    public boolean confirmarPresenca(Appointment appointment) {
        if (!config.isEnabled()) return false;
        String pessoaId = appointment.getStudent().getAcceleroPessoaId();
        if (pessoaId == null) return false;
        try {
            ZonedDateTime inicioMarcado = ZonedDateTime.of(appointment.getDate(),
                    LocalTime.parse(appointment.getSlotStart()), zone);
            ZonedDateTime inicioJanela = inicioMarcado.minusMinutes(MARGEM_ANTECEDENCIA_MINUTOS);
            ZonedDateTime fimJanela = inicioMarcado.plusHours(JANELA_ACESSO_HORAS);
            if (ZonedDateTime.now(zone).isBefore(inicioJanela)) return false; // ainda nem começou

            List<EventoAcesso> eventos = buscarTodosOsEventos(pessoaId,
                    inicioJanela.format(FORMATO_ACCELERO), fimJanela.format(FORMATO_ACCELERO));

            OffsetDateTime primeiraEntrada = null;
            List<OffsetDateTime> saidas = new ArrayList<>();
            for (EventoAcesso e : eventos) {
                if (e.descricao() == null || !PASSAGEM_REALIZADA.equalsIgnoreCase(e.descricao().trim())) continue;
                // Sem isso, um evento de OUTRA área do prédio (o aluno pode ter
                // acesso mais amplo, ex.: funcionário) dentro da mesma janela de
                // horário seria confundido com entrada/saída da academia —
                // confirmado com dados reais (Atalaia/Secretariado no meio da
                // janela de um agendamento de academia).
                if (e.area() == null || !e.area().trim().toUpperCase().startsWith(AREA_ACADEMIA)) continue;
                OffsetDateTime quando = parseDataHora(e.dataHora());
                if (quando == null) continue;
                String direcao = classificarDirecao(e);
                if ("entrada".equals(direcao) && (primeiraEntrada == null || quando.isBefore(primeiraEntrada))) {
                    primeiraEntrada = quando;
                } else if ("saida".equals(direcao)) {
                    saidas.add(quando);
                }
            }
            // Saída só conta depois da entrada — caso real: num teste da catraca
            // a saída veio 4s antes da entrada e o relatório mostrava "11:20 – 11:20".
            OffsetDateTime referencia = appointment.getEntradaConfirmadaEm() != null
                    ? appointment.getEntradaConfirmadaEm() : primeiraEntrada;
            OffsetDateTime primeiraSaida = referencia == null ? null : saidas.stream()
                    .filter(s -> s.isAfter(referencia))
                    .min(OffsetDateTime::compareTo)
                    .orElse(null);

            boolean mudou = false;
            if (appointment.getEntradaConfirmadaEm() == null && primeiraEntrada != null) {
                appointment.setEntradaConfirmadaEm(primeiraEntrada);
                mudou = true;
            }
            if (appointment.getSaidaConfirmadaEm() == null && primeiraSaida != null) {
                appointment.setSaidaConfirmadaEm(primeiraSaida);
                mudou = true;
            }
            if (mudou) {
                appointments.save(appointment);
                log.info("Presença confirmada pela catraca pro agendamento {} (entrada={}, saída={}).",
                        appointment.getId(), appointment.getEntradaConfirmadaEm(), appointment.getSaidaConfirmadaEm());
            }
            return mudou;
        } catch (Exception e) {
            log.warn("Falha ao confirmar presença via Accelero pro agendamento {}: {}",
                    appointment.getId(), e.getMessage(), e);
            return false;
        }
    }

    private OffsetDateTime parseDataHora(String texto) {
        if (texto == null || texto.isBlank()) return null;
        try {
            return java.time.LocalDateTime.parse(texto, FORMATO_LOG_EVENTOS).atZone(zone).toOffsetDateTime();
        } catch (Exception e) {
            return null;
        }
    }

    /** Confirmado com eventos reais do Accelero: a direção mora no campo área
     *  (areDescricao), não no controlador — é um padrão geral do prédio
     *  (não só da academia): toda área tem uma leitura "X EXT" (entrando
     *  naquela área, vindo de fora) e uma "X INT" (saindo daquela área,
     *  voltando pra fora). Ex.: "ACADEMIA EXT"/"ACADEMIA INT",
     *  "ATALAIA EXT"/"ATALAIA INT". O controlador (conDescricao) costuma
     *  ser só o nome genérico do dispositivo (ex.: "ACADEMIA" pros dois
     *  sentidos) e não é confiável pra classificar direção. */
    private static String classificarDirecao(EventoAcesso e) {
        String area = e.area() == null ? "" : e.area().trim().toUpperCase();
        if (area.endsWith("EXT")) return "entrada";
        if (area.endsWith("INT")) return "saida";
        return "outro";
    }
}
