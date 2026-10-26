package br.gov.goias.secami.academy.configuracao;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Configurações que o admin ajusta pela tela (Config. Horários). */
@Service
public class ConfiguracaoService {

    static final String JANELA_CATRACA = "catraca_janela_horas";
    public static final int JANELA_PADRAO_HORAS = 5;
    public static final int JANELA_MIN_HORAS = 1;
    public static final int JANELA_MAX_HORAS = 12;

    /** Turmas de Lutas: dias (1 = segunda ... 7 = domingo), horário da aula e
     *  folga pra sair depois do fim. A catraca abre 20 min antes do início. */
    public record Lutas(java.util.List<Integer> masculinoDias, java.util.List<Integer> femininoDias,
                        String inicio, String fim, Integer folgaSaidaHoras) {}

    private final ConfiguracaoRepository repo;

    public ConfiguracaoService(ConfiguracaoRepository repo) {
        this.repo = repo;
    }

    /** Horas que a catraca fica liberada pro civil a partir do horário marcado. */
    @Transactional(readOnly = true)
    public int janelaCatracaHoras() {
        return repo.findById(JANELA_CATRACA)
                .map(c -> {
                    try {
                        return Integer.parseInt(c.getValor().trim());
                    } catch (NumberFormatException e) {
                        return JANELA_PADRAO_HORAS;
                    }
                })
                .orElse(JANELA_PADRAO_HORAS);
    }

    @Transactional(readOnly = true)
    public Lutas lutas() {
        return new Lutas(dias(valor("lutas_masculino_dias", "2,4,5")), dias(valor("lutas_feminino_dias", "1,3,5")),
                valor("lutas_inicio", "12:00"), valor("lutas_fim", "13:00"),
                Integer.parseInt(valor("lutas_folga_saida_horas", "2")));
    }

    @Transactional
    public Lutas definirLutas(Lutas l) {
        if (l == null || l.masculinoDias() == null || l.femininoDias() == null) {
            throw new BusinessException("Informe os dias das duas turmas.");
        }
        for (Integer d : concat(l.masculinoDias(), l.femininoDias())) {
            if (d == null || d < 1 || d > 7) throw new BusinessException("Dia da semana inválido.");
        }
        java.time.LocalTime inicio, fim;
        try {
            inicio = java.time.LocalTime.parse(l.inicio());
            fim = java.time.LocalTime.parse(l.fim());
        } catch (Exception e) {
            throw new BusinessException("Informe os horários no formato HH:MM.");
        }
        if (!fim.isAfter(inicio)) throw new BusinessException("O fim da aula precisa ser depois do início.");
        if (l.folgaSaidaHoras() == null || l.folgaSaidaHoras() < 0 || l.folgaSaidaHoras() > 6) {
            throw new BusinessException("A folga para sair deve ser de 0 a 6 horas.");
        }
        gravar("lutas_masculino_dias", juntar(l.masculinoDias()));
        gravar("lutas_feminino_dias", juntar(l.femininoDias()));
        gravar("lutas_inicio", inicio.toString());
        gravar("lutas_fim", fim.toString());
        gravar("lutas_folga_saida_horas", String.valueOf(l.folgaSaidaHoras()));
        return lutas();
    }

    private String valor(String chave, String padrao) {
        return repo.findById(chave).map(Configuracao::getValor).orElse(padrao);
    }

    private void gravar(String chave, String valor) {
        Configuracao c = repo.findById(chave).orElseGet(() -> {
            Configuracao nova = new Configuracao();
            nova.setChave(chave);
            return nova;
        });
        c.setValor(valor);
        repo.save(c);
    }

    private static java.util.List<Integer> dias(String csv) {
        return java.util.Arrays.stream(csv.split(",")).map(String::trim).filter(x -> !x.isEmpty())
                .map(Integer::parseInt).sorted().distinct().toList();
    }

    private static String juntar(java.util.List<Integer> dias) {
        return dias.stream().sorted().distinct().map(String::valueOf).collect(java.util.stream.Collectors.joining(","));
    }

    private static java.util.List<Integer> concat(java.util.List<Integer> a, java.util.List<Integer> b) {
        java.util.List<Integer> r = new java.util.ArrayList<>(a);
        r.addAll(b);
        return r;
    }

    @Transactional
    public int definirJanelaCatracaHoras(Integer horas) {
        if (horas == null || horas < JANELA_MIN_HORAS || horas > JANELA_MAX_HORAS) {
            throw new BusinessException("Informe um tempo entre " + JANELA_MIN_HORAS + " e " + JANELA_MAX_HORAS + " horas.");
        }
        Configuracao c = repo.findById(JANELA_CATRACA).orElseGet(() -> {
            Configuracao nova = new Configuracao();
            nova.setChave(JANELA_CATRACA);
            return nova;
        });
        c.setValor(String.valueOf(horas));
        repo.save(c);
        return horas;
    }
}
