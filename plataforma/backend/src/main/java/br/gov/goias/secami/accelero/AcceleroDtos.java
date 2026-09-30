package br.gov.goias.secami.accelero;

import java.util.List;

public final class AcceleroDtos {

    private AcceleroDtos() {}

    /** Resultado da pesquisa rápida de pessoas (`/pessoas/pesquisaRapida`).
     *  Não traz CPF nem e-mail — só uid/nome (confirmado com resposta real). */
    public record PessoaEncontrada(String uid, String nome, String cpf) {}

    /** Dados cadastrais completos da pessoa, raspados do JSON embutido na
     *  página de edição (`/pessoas/{id}`, chave "pes*"). */
    public record PessoaDetalhe(String uid, String nome, String email, String cpf) {}

    /** Uma categoria já vinculada à pessoa (`/pessoas/{id}/categorias`). */
    public record CategoriaVinculada(String uid, String pctId, String descricao) {}

    /** Um identificador (cartão/biometria) vinculado à pessoa (`/pessoas/{id}/identificadores`). */
    public record IdentificadorVinculado(String uid, String descricao, Integer carHabilitado) {}

    /** Um evento do log de acessos da pessoa (`/pessoas/{id}/logeventos`). */
    public record EventoAcesso(
            String dataHora, String controlador, String area, String descricao,
            Integer status, String cartao) {}

    public record PaginaEventos(List<EventoAcesso> eventos, int totalPaginas) {}
}
