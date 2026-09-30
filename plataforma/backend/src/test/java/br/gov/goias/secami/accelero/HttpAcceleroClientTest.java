package br.gov.goias.secami.accelero;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * A página da pessoa no Accelero não tem endpoint AJAX dedicado pra dados
 * cadastrais (nome/e-mail/CPF) — só um JSON embutido num {@code <script>}
 * que pré-popula o formulário de edição. {@link HttpAcceleroClient#extrairJsonPessoa}
 * localiza e faz o parse desse bloco por balanceamento de chaves (não regex),
 * porque o próprio JSON tem campos que são JSON serializado como string
 * (ex.: pesMetadata) — uma regex ingênua pararia na primeira "}" de dentro
 * dessas strings escapadas, cortando o objeto no meio.
 */
class HttpAcceleroClientTest {

    private static final ObjectMapper mapper = new ObjectMapper();

    /** Reproduz a estrutura real (HTML em volta + marcador + JSON), com um
     *  campo aninhado (pesMetadata) cujo valor é JSON escapado com chaves —
     *  exatamente o caso que quebraria uma extração por regex simples. */
    private static String htmlComPessoa(String pesEmail) {
        return """
                <html><body>
                <form>...</form>
                <script>
                ; await DataHandler.populate(container, {"uid":"710308349","signature":"Pessoa710308349-abc\\/nonce\\/xyz.20260918","controller":"pessoas","pesID":"710308349","pesNome":"JOSIAS SILVA SIQUEIRA","pesEmail":%s,"pesDocumento":"11144477735","pesDocumentoTipo":"cpf","pesMetadata":"{\\"reentries\\":{\\"123\\":\\"20260918093812\\"}}","pesObservacoes":"linha com \\"aspas\\" e { chave } solta"});
                </script>
                <script>outroTrecho({"naoEhIsso": true});</script>
                </body></html>
                """.formatted(pesEmail);
    }

    @Test
    void extraiEmailNomeECpfDoJsonEmbutido() {
        JsonNode json = HttpAcceleroClient.extrairJsonPessoa(
                htmlComPessoa("\"fulana.silva@goias.gov.br\""), mapper);

        assertThat(json).isNotNull();
        assertThat(json.path("pesID").asText()).isEqualTo("710308349");
        assertThat(json.path("pesNome").asText()).isEqualTo("JOSIAS SILVA SIQUEIRA");
        assertThat(json.path("pesEmail").asText()).isEqualTo("fulana.silva@goias.gov.br");
        assertThat(json.path("pesDocumento").asText()).isEqualTo("11144477735");
    }

    @Test
    void naoParaNaPrimeiraChaveDentroDeUmCampoJsonEscapado() {
        // pesMetadata (JSON serializado como string, com chaves escapadas) e
        // pesObservacoes (chave "solta" dentro de uma string comum) vêm DEPOIS
        // de pesEmail no objeto — só chegam corretos se o parser não tiver
        // encerrado o objeto prematuramente numa chave de dentro de uma string.
        JsonNode json = HttpAcceleroClient.extrairJsonPessoa(htmlComPessoa("null"), mapper);

        assertThat(json).isNotNull();
        assertThat(json.path("pesObservacoes").asText()).contains("chave } solta");
        assertThat(json.path("pesMetadata").asText()).contains("reentries");
    }

    @Test
    void pesEmailNuloNoJsonViraNuloNaoATextoLiteral() {
        JsonNode json = HttpAcceleroClient.extrairJsonPessoa(htmlComPessoa("null"), mapper);

        assertThat(json.path("pesEmail").isNull()).isTrue();
    }

    @Test
    void retornaNuloQuandoMarcadorAusente() {
        JsonNode json = HttpAcceleroClient.extrairJsonPessoa("<html><body>nada aqui</body></html>", mapper);

        assertThat(json).isNull();
    }

    @Test
    void retornaNuloQuandoHtmlENulo() {
        assertThat(HttpAcceleroClient.extrairJsonPessoa(null, mapper)).isNull();
    }

    @Test
    void retornaNuloQuandoJsonMalFormado() {
        String html = "DataHandler.populate(container, {\"pesNome\": \"sem fechar corretamente";

        assertThat(HttpAcceleroClient.extrairJsonPessoa(html, mapper)).isNull();
    }
}
