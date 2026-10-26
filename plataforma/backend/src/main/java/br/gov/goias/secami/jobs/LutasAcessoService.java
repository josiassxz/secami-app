package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.configuracao.ConfiguracaoService;
import br.gov.goias.secami.academy.lutas.AcessoLutas;
import br.gov.goias.secami.academy.lutas.AcessoLutasRepository;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.accelero.AcceleroSyncService;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;

/**
 * Perfil Lutas: nos dias da turma (Masculino/Feminino, configuráveis em
 * Config. Horários) libera a catraca no horário da aula sem agendamento — de
 * 20 min antes do início até o fim + a folga pra sair — e retira depois.
 * Roda a cada 15 min: libera quem ainda não tem a do dia (inclusive quem virou
 * Lutas no meio do dia) e retira as vencidas. Datas bloqueadas o dia todo não
 * liberam. Fora disso o aluno de Lutas agenda como civil.
 */
@Service
public class LutasAcessoService {

    private static final Logger log = LoggerFactory.getLogger(LutasAcessoService.class);
    static final long ANTECEDENCIA_MINUTOS = 20;

    public record Resultado(int liberados, int retirados) {}

    private final StudentRepository students;
    private final AcessoLutasRepository acessos;
    private final BlockedDateRepository blockedDates;
    private final ConfiguracaoService configuracoes;
    private final AcceleroSyncService acceleroSync;
    private final ZoneId zone;

    public LutasAcessoService(StudentRepository students, AcessoLutasRepository acessos,
                              BlockedDateRepository blockedDates, ConfiguracaoService configuracoes,
                              AcceleroSyncService acceleroSync, SecamiProperties props) {
        this.students = students;
        this.acessos = acessos;
        this.blockedDates = blockedDates;
        this.configuracoes = configuracoes;
        this.acceleroSync = acceleroSync;
        this.zone = ZoneId.of(props.getTimezone());
    }

    @Scheduled(cron = "0 */15 * * * *", zone = "America/Sao_Paulo")
    public void agendado() {
        Resultado r = executar();
        if (r.liberados() + r.retirados() > 0) {
            log.info("Lutas: {} liberação(ões) da aula, {} retirada(s).", r.liberados(), r.retirados());
        }
    }

    @Transactional
    public Resultado executar() {
        return new Resultado(liberarDoDia(ZonedDateTime.now(zone)), retirarVencidas());
    }

    int liberarDoDia(ZonedDateTime agora) {
        LocalDate hoje = agora.toLocalDate();
        ConfiguracaoService.Lutas cfg = configuracoes.lutas();
        int dia = hoje.getDayOfWeek().getValue();
        boolean masculino = cfg.masculinoDias().contains(dia);
        boolean feminino = cfg.femininoDias().contains(dia);
        if (!masculino && !feminino) return 0;
        boolean diaBloqueado = blockedDates.findByDate(hoje).stream()
                .anyMatch(b -> b.getSlotStart() == null || b.getSlotStart().isBlank());
        if (diaBloqueado) return 0;

        ZonedDateTime inicio = ZonedDateTime.of(hoje, LocalTime.parse(cfg.inicio()), zone).minusMinutes(ANTECEDENCIA_MINUTOS);
        ZonedDateTime fim = ZonedDateTime.of(hoje, LocalTime.parse(cfg.fim()), zone).plusHours(cfg.folgaSaidaHoras());
        if (!agora.isBefore(fim)) return 0;

        List<Student> turma = students.findByDeletedAtIsNullAndStatusCadastroAndStudentType(
                        Student.STATUS_APROVADO, Student.TIPO_LUTAS).stream()
                .filter(s -> (masculino && Student.TURMA_MASCULINO.equals(s.getTurmaLutas()))
                        || (feminino && Student.TURMA_FEMININO.equals(s.getTurmaLutas())))
                .filter(s -> !Student.SITUACAO_BLOQUEADO.equals(s.getSituacao()) && s.isActive())
                .toList();
        int liberados = 0;
        for (Student s : turma) {
            if (acessos.existsByStudentIdAndData(s.getId(), hoje)) continue;
            String vinculo = acceleroSync.liberarJanelaLutas(s, inicio, fim);
            AcessoLutas a = new AcessoLutas();
            a.setStudent(s);
            a.setData(hoje);
            a.setAcceleroVinculoId(vinculo);
            a.setExpiraEm(fim.toOffsetDateTime());
            acessos.save(a);
            if (vinculo != null) liberados++;
        }
        return liberados;
    }

    int retirarVencidas() {
        int retirados = 0;
        for (AcessoLutas a : acessos.findExpiradas(OffsetDateTime.now())) {
            if (acceleroSync.revogarJanelaLutas(a.getStudent(), a.getAcceleroVinculoId())) {
                a.setAcceleroVinculoId(null);
                acessos.save(a);
                retirados++;
            }
        }
        return retirados;
    }
}
