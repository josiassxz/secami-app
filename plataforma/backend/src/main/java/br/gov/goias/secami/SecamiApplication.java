package br.gov.goias.secami;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Aplicação principal da Plataforma SECAMI.
 * API única que serve o app Flutter e o admin React (ver SPEC §4).
 */
@SpringBootApplication
@ConfigurationPropertiesScan
@EnableScheduling
public class SecamiApplication {

    public static void main(String[] args) {
        SpringApplication.run(SecamiApplication.class, args);
    }
}
