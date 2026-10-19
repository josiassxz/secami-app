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
