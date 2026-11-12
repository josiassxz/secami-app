package br.gov.goias.secami.academy.punicao;

import br.gov.goias.secami.academy.configuracao.ConfiguracaoService;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Punições dos alunos de Lutas. Regra do ciclo: toda vez que o aluno tem
 * {@code porCiclo} punições CUMPRIDAS (padrão 2), as mais antigas viram
 * CONCLUIDA e saem da lista; o instrutor pode aplicar quantas quiser. Uma
 * cumprida que não fecha ciclo é encerrada sozinha depois de
 * {@code diasParaConcluir} dias (padrão 30).
 */
@Service
public class PunicaoService {

    public record ItemDto(UUID id, String nome, boolean ativo) {}
    public record ItemAplicado(String itemId, String nome) {}
    public record PunicaoDto(UUID id, UUID studentId, String studentName, List<ItemAplicado> itens,
                             String observacao, String status, OffsetDateTime aplicadaEm, String aplicadaPorNome,
                             OffsetDateTime cumpridaEm, String cumpridaPorNome, OffsetDateTime concluidaEm) {}
    public record AlunoLutas(UUID studentId, String fullName, String turmaLutas, long pendentes, long cumpridas) {}
    public record AplicarRequest(UUID studentId, List<UUID> itemIds, String observacao) {}
    public record ItemRequest(String nome, Boolean ativo) {}

    private static final Set<String> EM_ABERTO = Set.of(Punicao.PENDENTE, Punicao.CUMPRIDA);

    private final PunicaoRepository punicoes;
    private final PunicaoItemRepository itens;
    private final StudentRepository students;
    private final AppUserRepository users;
    private final ConfiguracaoService configuracoes;

    public PunicaoService(PunicaoRepository punicoes, PunicaoItemRepository itens, StudentRepository students,
                          AppUserRepository users, ConfiguracaoService configuracoes) {
        this.punicoes = punicoes;
        this.itens = itens;
        this.students = students;
        this.users = users;
        this.configuracoes = configuracoes;
    }

    // ---------- catálogo ----------

    @Transactional(readOnly = true)
    public List<ItemDto> listarItens(boolean todos) {
        return (todos ? itens.findAllByOrderByNomeAsc() : itens.findByAtivoTrueOrderByNomeAsc()).stream()
                .map(i -> new ItemDto(i.getId(), i.getNome(), i.isAtivo())).toList();
    }

    @Transactional
    public ItemDto criarItem(ItemRequest req) {
        PunicaoItem i = new PunicaoItem();
        i.setNome(nomeValido(req));
        return toDto(itens.save(i));
    }

    @Transactional
    public ItemDto editarItem(UUID id, ItemRequest req) {
        PunicaoItem i = itens.findById(id).orElseThrow(() -> new NotFoundException("Item não encontrado."));
        i.setNome(nomeValido(req));
        if (req.ativo() != null) i.setAtivo(req.ativo());
        return toDto(itens.save(i));
    }

    private static String nomeValido(ItemRequest req) {
        String nome = req == null || req.nome() == null ? "" : req.nome().trim();
        if (nome.isEmpty()) throw new BusinessException("Informe o nome da punição.");
        return nome;
    }

    private static ItemDto toDto(PunicaoItem i) {
        return new ItemDto(i.getId(), i.getNome(), i.isAtivo());
    }

    // ---------- alunos ----------

    @Transactional(readOnly = true)
    public List<AlunoLutas> alunos(String q) {
        String termo = q == null ? "" : q.trim().toLowerCase();
        return students.findByDeletedAtIsNullAndStatusCadastroAndStudentType(Student.STATUS_APROVADO, Student.TIPO_LUTAS)
                .stream()
                .filter(s -> termo.isEmpty() || s.getFullName().toLowerCase().contains(termo))
                .sorted(Comparator.comparing(Student::getFullName, String.CASE_INSENSITIVE_ORDER))
                .map(s -> new AlunoLutas(s.getId(), s.getFullName(), s.getTurmaLutas(),
                        punicoes.countByStudentIdAndStatus(s.getId(), Punicao.PENDENTE),
                        punicoes.countByStudentIdAndStatus(s.getId(), Punicao.CUMPRIDA)))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<PunicaoDto> emAberto(UUID studentId) {
        return dtos(punicoes.findByStudentIdAndStatusInOrderByAplicadaEmAsc(studentId, EM_ABERTO));
    }

    @Transactional(readOnly = true)
    public List<PunicaoDto> historico(UUID studentId) {
        return dtos(punicoes.findByStudentIdOrderByAplicadaEmDesc(studentId));
    }

    /** Aluno logado: só as em aberto; quem não é de Lutas recebe lista vazia. */
    @Transactional(readOnly = true)
    public List<PunicaoDto> minhas(UUID userId) {
        return students.findByUserId(userId)
                .filter(s -> Student.TIPO_LUTAS.equals(s.getStudentType()) && s.getDeletedAt() == null)
                .map(s -> emAberto(s.getId()))
                .orElse(List.of());
    }

    // ---------- aplicar / cumprir / excluir ----------

    @Transactional
    public PunicaoDto aplicar(AplicarRequest req, UUID instrutorId) {
        if (req == null || req.studentId() == null) throw new BusinessException("Escolha o aluno.");
        Student s = students.findByIdAndDeletedAtIsNull(req.studentId())
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
        if (!Student.TIPO_LUTAS.equals(s.getStudentType())) {
            throw new BusinessException("Punições são só para alunos do perfil Lutas.");
        }
        if (req.itemIds() == null || req.itemIds().isEmpty()) {
            throw new BusinessException("Escolha pelo menos uma punição.");
        }
        List<Map<String, String>> escolhidos = new ArrayList<>();
        for (UUID itemId : new java.util.LinkedHashSet<>(req.itemIds())) {
            PunicaoItem i = itens.findById(itemId).orElseThrow(() -> new NotFoundException("Punição não encontrada."));
            if (!i.isAtivo()) throw new BusinessException("A punição \"" + i.getNome() + "\" está desativada.");
            Map<String, String> m = new LinkedHashMap<>();
            m.put("itemId", i.getId().toString());
            m.put("nome", i.getNome());
            escolhidos.add(m);
        }
        Punicao p = new Punicao();
        p.setStudent(s);
        p.setItens(escolhidos);
        p.setObservacao(req.observacao() == null || req.observacao().isBlank() ? null : req.observacao().trim());
        p.setAplicadaEm(OffsetDateTime.now());
        p.setAplicadaPor(instrutorId);
        return dtos(List.of(punicoes.save(p))).get(0);
    }

    /** Marca como cumprida e fecha os ciclos completos. @return a lista em aberto do aluno. */
    @Transactional
    public List<PunicaoDto> cumprir(UUID punicaoId, UUID instrutorId) {
        Punicao p = punicoes.findById(punicaoId).orElseThrow(() -> new NotFoundException("Punição não encontrada."));
        if (!Punicao.PENDENTE.equals(p.getStatus())) {
            throw new BusinessException("Esta punição já foi marcada como cumprida.");
        }
        p.setStatus(Punicao.CUMPRIDA);
        p.setCumpridaEm(OffsetDateTime.now());
        p.setCumpridaPor(instrutorId);
        punicoes.save(p);
        UUID studentId = p.getStudent().getId();
        fecharCiclos(studentId);
        return emAberto(studentId);
    }

    @Transactional
    public void excluir(UUID punicaoId) {
        Punicao p = punicoes.findById(punicaoId).orElseThrow(() -> new NotFoundException("Punição não encontrada."));
        if (!Punicao.PENDENTE.equals(p.getStatus())) {
            throw new BusinessException("Só dá para excluir punição pendente.");
        }
        punicoes.delete(p);
    }

    /** A cada {@code porCiclo} cumpridas, encerra as mais antigas. */
    void fecharCiclos(UUID studentId) {
        int porCiclo = configuracoes.punicoes().porCiclo();
        List<Punicao> cumpridas = new ArrayList<>(punicoes
                .findByStudentIdAndStatusInOrderByAplicadaEmAsc(studentId, Set.of(Punicao.CUMPRIDA)));
        cumpridas.sort(Comparator.comparing(Punicao::getCumpridaEm));
        OffsetDateTime agora = OffsetDateTime.now();
        while (cumpridas.size() >= porCiclo) {
            for (int i = 0; i < porCiclo; i++) {
                Punicao c = cumpridas.remove(0);
                c.setStatus(Punicao.CONCLUIDA);
                c.setConcluidaEm(agora);
                punicoes.save(c);
            }
        }
    }

    /** Cumprida que não fechou ciclo: encerra depois do prazo (roda todo dia às 03:00). */
    @Scheduled(cron = "0 0 3 * * *", zone = "America/Sao_Paulo")
    @Transactional
    public int encerrarCumpridasAntigas() {
        int dias = configuracoes.punicoes().diasParaConcluir();
        List<Punicao> antigas = punicoes.findCumpridasAntesDe(OffsetDateTime.now().minusDays(dias));
        OffsetDateTime agora = OffsetDateTime.now();
        for (Punicao p : antigas) {
            p.setStatus(Punicao.CONCLUIDA);
            p.setConcluidaEm(agora);
            punicoes.save(p);
        }
        return antigas.size();
    }

    // ---------- conversão ----------

    private List<PunicaoDto> dtos(List<Punicao> lista) {
        Map<UUID, String> nomes = new HashMap<>();
        for (Punicao p : lista) {
            for (UUID u : new UUID[] {p.getAplicadaPor(), p.getCumpridaPor()}) {
                if (u != null && !nomes.containsKey(u)) {
                    nomes.put(u, users.findById(u).map(AppUser::getNome).orElse(null));
                }
            }
        }
        return lista.stream().map(p -> new PunicaoDto(p.getId(), p.getStudent().getId(), p.getStudent().getFullName(),
                p.getItens().stream().map(m -> new ItemAplicado(m.get("itemId"), m.get("nome"))).toList(),
                p.getObservacao(), p.getStatus(), p.getAplicadaEm(),
                p.getAplicadaPor() == null ? null : nomes.get(p.getAplicadaPor()),
                p.getCumpridaEm(), p.getCumpridaPor() == null ? null : nomes.get(p.getCumpridaPor()),
                p.getConcluidaEm())).toList();
    }
}
