package br.gov.goias.secami;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.transaction.annotation.Transactional;

/**
 * Base para testes de integração de ponta a ponta contra a aplicação REAL
 * (Spring context completo + Postgres local {@code secami_test}, ver
 * {@code application-test.yml}) via MockMvc — exercita controller, service,
 * repository e regras de negócio reais, não mocks.
 *
 * <p>{@code @Transactional} na classe: cada método de teste roda dentro de
 * uma transação que sofre rollback ao final — banco sempre volta ao estado
 * anterior, testes não interferem uns nos outros nem com o Flyway/seed
 * inicial (rodados uma vez, fora da transação de cada teste).
 *
 * <p>Uso típico:
 * <pre>{@code
 * String token = loginAs("admin"); // usuários dev semeados por DevDataSeeder
 * mockMvc.perform(authed(get("/students"), token))
 *     .andExpect(status().isOk());
 * }</pre>
 */
@ExtendWith(SpringExtension.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
public abstract class AbstractIntegrationTest {

    /** Senha dev de todos os usuários semeados (DevDataSeeder). */
    protected static final String DEV_PASSWORD = "secami123";

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ObjectMapper objectMapper;

    /**
     * Faz login real via {@code POST /auth/login} contra um dos usuários dev
     * semeados ("admin", "gerente", "recepcao", "professor", "aluno") e
     * devolve o accessToken JWT pronto pra usar em {@link #authed}.
     */
    protected String loginAs(String samAccountName) throws Exception {
        String body = objectMapper.writeValueAsString(new LoginBody(samAccountName, DEV_PASSWORD));
        String response = mockMvc
                .perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return objectMapper.readTree(response).get("accessToken").asText();
    }

    /** Anexa o header {@code Authorization: Bearer <token>} numa request MockMvc. */
    protected static MockHttpServletRequestBuilder authed(
            MockHttpServletRequestBuilder builder, String token) {
        return builder.header("Authorization", "Bearer " + token);
    }

    private record LoginBody(String username, String password) {}
}
