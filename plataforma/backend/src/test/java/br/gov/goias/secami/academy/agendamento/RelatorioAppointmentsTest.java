package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Tela de Relatórios do admin: GET /appointments, /appointments/summary e
 *  /appointments/export. Regressão: sem filtro de busca (o caso padrão da
 *  tela) o parâmetro nulo chegava ao Postgres como bytea e as três rotas
 *  davam 500; o resumo ainda usava uma coluna inexistente ("data"). */
class RelatorioAppointmentsTest extends SchedulingTestSupport {

    private String periodo() {
        return "from=" + hoje() + "&to=" + hoje();
    }

    private boolean contem(JsonNode page, Appointment appt) {
        for (JsonNode n : page.get("content")) {
            if (n.get("id").asText().equals(appt.getId().toString())) return true;
        }
        return false;
    }

    @Test
    void listaSemFiltros() throws Exception {
        Appointment appt = seedAppointment(civil(), hoje(), "08:00", Appointment.AGENDADO);
        String token = loginAs("admin");

        JsonNode page = readJson(mockMvc.perform(authed(get("/appointments?" + periodo()), token))
                .andExpect(status().isOk()));
        assertTrue(contem(page, appt));
    }

    @Test
    void listaSoComFiltroDeStatus() throws Exception {
        Appointment agendado = seedAppointment(civil(), hoje(), "09:00", Appointment.AGENDADO);
        Appointment faltou = seedAppointment(civil(), hoje(), "09:00", Appointment.FALTOU);
        String token = loginAs("recepcao");

        JsonNode page = readJson(mockMvc.perform(authed(
                get("/appointments?" + periodo() + "&status=faltou"), token))
                .andExpect(status().isOk()));
        assertTrue(contem(page, faltou));
        assertFalse(contem(page, agendado));
    }

    @Test
    void listaComBuscaPorNome() throws Exception {
        // Nome único: o banco de teste acumula "Aluno Teste N" de execuções
        // anteriores, e um prefixo repetido empurraria o alvo pra fora da página.
        Student s = civil();
        s.setFullName("Busca Relatorio " + UUID.randomUUID());
        s = studentRepository.save(s);
        Appointment appt = seedAppointment(s, hoje(), "10:00", Appointment.AGENDADO);
        Appointment outro = seedAppointment(civil(), hoje(), "10:00", Appointment.AGENDADO);
        String token = loginAs("admin");
        // .param() em vez de montar a query na mão: o MockMvc não decodifica
        // "+" como espaço. Maiúsculas conferem que a busca ignora caixa.
        JsonNode page = readJson(mockMvc.perform(authed(
                get("/appointments?" + periodo()).param("q", s.getFullName().toUpperCase()), token))
                .andExpect(status().isOk()));
        assertTrue(contem(page, appt));
        assertFalse(contem(page, outro));
    }

    @Test
    void resumoSemFiltros() throws Exception {
        seedAppointment(civil(), hoje(), "11:00", Appointment.AGENDADO);
        seedAppointment(civil(), hoje(), "11:00", Appointment.FALTOU);
        String token = loginAs("admin");

        JsonNode resumo = readJson(mockMvc.perform(authed(get("/appointments/summary?" + periodo()), token))
                .andExpect(status().isOk()));
        assertTrue(resumo.get("agendado").asLong() >= 1);
        assertTrue(resumo.get("faltou").asLong() >= 1);
    }

    @Test
    void resumoComStatusEBusca() throws Exception {
        Student s = civil();
        seedAppointment(s, hoje(), "12:00", Appointment.FALTOU);
        seedAppointment(civil(), hoje(), "12:00", Appointment.FALTOU);
        String token = loginAs("gerente");
        JsonNode resumo = readJson(mockMvc.perform(authed(
                get("/appointments/summary?" + periodo() + "&status=faltou").param("q", s.getCpf()), token))
                .andExpect(status().isOk()));
        assertEquals(1, resumo.get("faltou").asLong());
        assertEquals(0, resumo.get("agendado").asLong());
    }

    @Test
    void exportaExcelSemFiltros() throws Exception {
        seedAppointment(civil(), hoje(), "13:00", Appointment.AGENDADO);
        String token = loginAs("admin");

        byte[] xlsx = mockMvc.perform(authed(get("/appointments/export?" + periodo()), token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsByteArray();
        // .xlsx é um zip: começa com a assinatura "PK".
        assertTrue(xlsx.length > 100);
        assertEquals('P', xlsx[0]);
        assertEquals('K', xlsx[1]);
    }
}
