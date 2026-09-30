package br.gov.goias.secami.accelero;

import br.gov.goias.secami.config.SecamiProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AcceleroConfig {

    /** Sempre registrado (construção é leve, sem I/O) — {@link AcceleroSyncService}
     *  decide se chama ou não com base em {@code secami.accelero.enabled}. */
    @Bean
    public AcceleroClient acceleroClient(SecamiProperties props) {
        return new HttpAcceleroClient(props.getAccelero());
    }
}
