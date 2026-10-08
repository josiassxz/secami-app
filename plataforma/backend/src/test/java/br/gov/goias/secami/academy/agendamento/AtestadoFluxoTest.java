package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.atestado.AtestadoDtos;
import br.gov.goias.secami.academy.atestado.AtestadoEnvio;
import br.gov.goias.secami.academy.atestado.AtestadoEnvioRepository;
import br.gov.goias.secami.academy.atestado.AtestadoService;
import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.ResultActions;

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Vencimento do atestado (só civil): situação no app, envio de novo atestado,
 * fila de validação do admin, bloqueio automático e painel.
 */
class AtestadoFluxoTest extends SchedulingTestSupport {

    @Autowired AtestadoService service;
    @Autowired AtestadoEnvioRepository envios;

    private static final byte[] PDF = "%PDF-1.4\n%%EOF".getBytes();

    /** Aluno com login próprio; devolve o "nome curto" pro loginAs. */
    private String alunoLogado(Student s) {
        String sam = "atestado." + UUID.randomUUID().toString().substring(0, 8);
        vinculadoAoUsuario(s, newAlunoUser(sam));
        return sam;
    }

    private Student civilComAtestado(LocalDate data) {
        return comAtestado(civil(), data);
    }

    private ResultActions enviar(String token, String emissao, byte[] arquivo, String contentType) throws Exception {
        String dados = "{\"emissaoData\":\"" + emissao + "\",\"medicoNome\":\"Dra. Ana\",\"medicoCrm\":\"12345\",\"medicoCrmUf\":\"go\"}";
        return mockMvc.perform(multipart("/me/atestado")
                .file(new MockMultipartFile("dados", "", "application/json", dados.getBytes()))
                .file(new MockMultipartFile("arquivo", "atestado.pdf", contentType, arquivo))
                .header("Authorization", "Bearer " + token));
    }

    private JsonNode meuStatus(String token) throws Exception {
        return objectMapper.readTree(mockMvc.perform(authed(get("/me/atestado"), token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    // ---- situação no app ----

    @Test
    void situacao_okVencendoEVencido_comDiasRestantes() throws Exception {
        String ok = loginAs(alunoLogado(civilComAtestado(hoje().minusMonths(2))));
        String vencendo = loginAs(alunoLogado(civilComAtestado(hoje().minusYears(1).plusDays(10))));
        String vencido = loginAs(alunoLogado(civilComAtestado(hoje().minusYears(1).minusDays(1))));

        assertThat(meuStatus(ok).get("situacao").asText()).isEqualTo("OK");
        JsonNode v = meuStatus(vencendo);
        assertThat(v.get("situacao").asText()).isEqualTo("VENCENDO");
        assertThat(v.get("diasRestantes").asLong()).isEqualTo(10);
        assertThat(v.get("bloqueado").asBoolean()).isFalse();
        JsonNode x = meuStatus(vencido);
        assertThat(x.get("situacao").asText()).isEqualTo("VENCIDO");
        assertThat(x.get("bloqueado").asBoolean()).isTrue();
        assertThat(x.get("diasRestantes").asLong()).isEqualTo(-1);
    }

    @Test
    void semDataDoAtestado_usaADataDoCadastroOriginal() throws Exception {
        Student s = civil();
        s.setCadastradoEm(hoje().minusYears(1).plusDays(5));
        studentRepository.save(s);
        JsonNode st = meuStatus(loginAs(alunoLogado(s)));
        assertThat(st.get("base").asText()).isEqualTo("CADASTRO");
        assertThat(st.get("situacao").asText()).isEqualTo("VENCENDO");
        assertThat(st.get("vencimento").asText()).isEqualTo(hoje().plusDays(5).toString());
    }

    @Test
    void militarEInstrutor_naoEntramNaRegra() throws Exception {
        Student militar = comAtestado(militar(), hoje().minusYears(3));
        Student instrutor = comAtestado(civil(), hoje().minusYears(3));
        instrutor.setStudentType(Student.TIPO_INSTRUTOR);
        studentRepository.save(instrutor);

        assertThat(meuStatus(loginAs(alunoLogado(militar))).get("aplicavel").asBoolean()).isFalse();
        JsonNode i = meuStatus(loginAs(alunoLogado(instrutor)));
        assertThat(i.get("aplicavel").asBoolean()).isFalse();
        assertThat(i.has("situacao")).isFalse();
        // Conta sem cadastro de aluno.
        assertThat(meuStatus(loginAs("professor")).get("aplicavel").asBoolean()).isFalse();

        service.aplicarBloqueios();
        assertThat(studentRepository.findById(militar.getId()).orElseThrow().getSituacao()).isEqualTo("ATIVO");
    }

    // ---- envio pelo aluno ----

    @Test
    void enviarNovoAtestado_ficaEmAnaliseEUmPorVez() throws Exception {
        String token = loginAs(alunoLogado(civilComAtestado(hoje().minusYears(1).plusDays(3))));
        enviar(token, hoje().minusDays(2).toString(), PDF, "application/pdf")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDENTE"));

        JsonNode st = meuStatus(token);
        assertThat(st.get("envio").get("status").asText()).isEqualTo("PENDENTE");
        assertThat(st.get("envio").get("emissaoData").asText()).isEqualTo(hoje().minusDays(2).toString());

        enviar(token, hoje().toString(), PDF, "application/pdf").andExpect(status().isConflict());
    }

    @Test
    void enviar_recusaArquivoOuDataInvalidos() throws Exception {
        String token = loginAs(alunoLogado(civilComAtestado(hoje().minusMonths(11))));
        enviar(token, hoje().toString(), "texto".getBytes(), "text/plain")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("PDF")));
        enviar(token, hoje().plusDays(1).toString(), PDF, "application/pdf")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("futuro")));
        enviar(token, hoje().minusYears(1).minusDays(1).toString(), PDF, "application/pdf")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("mais de 1 ano")));
        assertThat(meuStatus(token).has("envio")).isFalse();
    }

    @Test
    void militarNaoEnviaAtestado() throws Exception {
        String token = loginAs(alunoLogado(comAtestado(militar(), hoje())));
        enviar(token, hoje().toString(), PDF, "application/pdf")
                .andExpect(status().isUnprocessableEntity());
    }

    // ---- bloqueio automático + validação ----

    @Test
    void vencido_eBloqueado_cancelaAgendamentosEDepoisDaAprovacaoVoltaAoNormal() throws Exception {
        Student s = civilComAtestado(hoje().minusYears(1).minusDays(2));
        String token = loginAs(alunoLogado(s));
        Appointment futuro = seedAppointment(s, amanha(), "08:00", Appointment.AGENDADO);

        AtestadoDtos.ResultadoBloqueio r = service.aplicarBloqueios();
        assertThat(r.bloqueados()).isGreaterThanOrEqualTo(1);
        Student bloqueado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(bloqueado.getSituacao()).isEqualTo(Student.SITUACAO_BLOQUEADO);
        assertThat(bloqueado.isBloqueioAtestado()).isTrue();
        assertThat(appointmentRepository.findById(futuro.getId()).orElseThrow().getStatus())
                .isEqualTo(Appointment.CANCELADO);

        // Aluno bloqueado não agenda — a mensagem orienta o envio do novo atestado.
        slot("08:00", 10, false, false);
        mockMvc.perform(authed(post("/me/appointments"), token).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"" + amanha() + "\",\"slotStart\":\"08:00\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("Envie um novo atestado")));

        enviar(token, hoje().minusDays(1).toString(), PDF, "application/pdf").andExpect(status().isCreated());
        String admin = loginAs("admin");
        JsonNode fila = objectMapper.readTree(mockMvc.perform(authed(get("/admin/atestados/pendentes"), admin))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        JsonNode item = null;
        for (JsonNode n : fila) if (n.get("studentId").asText().equals(s.getId().toString())) item = n;
        assertThat(item).isNotNull();
        assertThat(item.get("bloqueado").asBoolean()).isTrue();
        assertThat(item.get("medicoCrmUf").asText()).isEqualTo("GO");

        mockMvc.perform(authed(post("/admin/atestados/" + item.get("id").asText() + "/aprovar"), admin))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("APROVADO"));

        Student liberado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(liberado.getSituacao()).isEqualTo(Student.SITUACAO_ATIVO);
        assertThat(liberado.isBloqueioAtestado()).isFalse();
        assertThat(liberado.getAtestadoData()).isEqualTo(hoje().minusDays(1));
        JsonNode st = meuStatus(token);
        assertThat(st.get("situacao").asText()).isEqualTo("OK");
        assertThat(st.has("envio")).isFalse();

        // Analisar de novo o mesmo envio não é permitido.
        mockMvc.perform(authed(post("/admin/atestados/" + item.get("id").asText() + "/aprovar"), admin))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void recusa_mostraOMotivoProAlunoEPermiteReenviar() throws Exception {
        Student s = civilComAtestado(hoje().minusYears(1).plusDays(5));
        String token = loginAs(alunoLogado(s));
        enviar(token, hoje().toString(), PDF, "application/pdf").andExpect(status().isCreated());
        AtestadoEnvio e = envios.findFirstByStudentIdOrderByEnviadoEmDesc(s.getId()).orElseThrow();

        mockMvc.perform(authed(post("/admin/atestados/" + e.getId() + "/recusar"), loginAs("gerente"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"motivo\":\"PDF ilegível\"}"))
                .andExpect(status().isOk());

        JsonNode st = meuStatus(token);
        assertThat(st.get("envio").get("status").asText()).isEqualTo("RECUSADO");
        assertThat(st.get("envio").get("motivoRecusa").asText()).isEqualTo("PDF ilegível");
        enviar(token, hoje().toString(), PDF, "application/pdf").andExpect(status().isCreated());
    }

    @Test
    void bloqueioManualNaoEDesfeitoPeloAtestado_masOAutomaticoSim() {
        Student manual = civilComAtestado(hoje().minusMonths(1));
        manual.setSituacao(Student.SITUACAO_BLOQUEADO);
        studentRepository.save(manual);
        Student automatico = civilComAtestado(hoje().minusMonths(1));
        automatico.setSituacao(Student.SITUACAO_BLOQUEADO);
        automatico.setBloqueioAtestado(true);
        studentRepository.save(automatico);

        service.aplicarBloqueios();

        assertThat(studentRepository.findById(manual.getId()).orElseThrow().getSituacao()).isEqualTo("BLOQUEADO");
        Student a = studentRepository.findById(automatico.getId()).orElseThrow();
        assertThat(a.getSituacao()).isEqualTo("ATIVO");
        assertThat(a.isBloqueioAtestado()).isFalse();
    }

    // ---- painel ----

    @Test
    void painel_listasEResumo_eRbac() throws Exception {
        Student vencendo = civilComAtestado(hoje().minusYears(1).plusDays(7));
        Student vencido = civilComAtestado(hoje().minusYears(1).minusDays(3));
        String recepcao = loginAs("recepcao");

        JsonNode lv = objectMapper.readTree(mockMvc.perform(authed(get("/admin/atestados/alunos?lista=vencendo"), recepcao))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        JsonNode lb = objectMapper.readTree(mockMvc.perform(authed(get("/admin/atestados/alunos?lista=bloqueados"), recepcao))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertThat(contem(lv, vencendo)).isTrue();
        assertThat(contem(lv, vencido)).isFalse();
        assertThat(contem(lb, vencido)).isTrue();
        assertThat(contem(lb, vencendo)).isFalse();

        mockMvc.perform(authed(get("/admin/atestados/resumo"), recepcao))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.vencendo").isNumber())
                .andExpect(jsonPath("$.bloqueados").isNumber())
                .andExpect(jsonPath("$.pendentes").isNumber());

        mockMvc.perform(authed(get("/admin/atestados/pendentes"), recepcao)).andExpect(status().isForbidden());
        mockMvc.perform(authed(get("/admin/atestados/resumo"), loginAs("aluno"))).andExpect(status().isForbidden());
        mockMvc.perform(authed(get("/admin/atestados/alunos?lista=outra"), recepcao))
                .andExpect(status().isUnprocessableEntity());
    }

    private static boolean contem(JsonNode lista, Student s) {
        for (JsonNode n : lista) if (n.get("studentId").asText().equals(s.getId().toString())) return true;
        return false;
    }
}
