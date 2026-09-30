package br.gov.goias.secami.accelero;

import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import br.gov.goias.secami.accelero.AcceleroDtos.IdentificadorVinculado;
import br.gov.goias.secami.accelero.AcceleroDtos.PaginaEventos;
import br.gov.goias.secami.accelero.AcceleroDtos.PessoaEncontrada;

import java.util.List;

/**
 * Cliente da API do Accelero (sistema que gerencia as catracas da academia).
 * Porta em Java do cliente Python usado hoje em {@code accelero/accelero.py}
 * — mesma sessão (cookie PHPSESSID) + signature raspado da página da pessoa.
 */
public interface AcceleroClient {

    /** Pesquisa rápida de pessoas por CPF, nome, placa etc. */
    List<PessoaEncontrada> pesquisarPessoas(String filtro);

    /** Categorias já vinculadas à pessoa (pra checar antes de duplicar). */
    List<CategoriaVinculada> listarCategorias(String pessoaId);

    /** Vincula uma categoria à pessoa. {@code inicio}/{@code fim} vazios = vitalícia
     *  (sem data de expiração); formato esperado "yyyy-MM-dd HH:mm:ss". */
    void adicionarCategoria(String pessoaId, String categoriaId, String inicio, String fim);

    /** Remove um vínculo de categoria — {@code vinculoUid} é o UID da linha
     *  retornada por {@link #listarCategorias}, NÃO o id do tipo de categoria. */
    void excluirCategoria(String pessoaId, String vinculoUid);

    /** Identificadores (cartão/biometria) vinculados à pessoa. */
    List<IdentificadorVinculado> listarIdentificadores(String pessoaId);

    /** Desassocia um identificador — não apaga a credencial em si, só força a
     *  catraca a ressincronizar as categorias liberadas pra essa pessoa
     *  (chamar depois de {@link #adicionarCategoria}/{@link #excluirCategoria}). */
    void desassociarIdentificador(String pessoaId, String vinculoUid, Integer carHabilitado);

    /** Log de eventos (acessos) da pessoa. Datas "AAAA-MM-DD HH:mm:ss" (vazias = sem filtro). */
    PaginaEventos listarLogEventos(String pessoaId, String dataInicial, String dataFinal, int page);

    /** Dados cadastrais da pessoa (nome, e-mail, CPF) — raspados do JSON que a
     *  própria página da pessoa embute pra pré-popular o formulário de edição
     *  (não tem endpoint AJAX dedicado pra isso, só a página completa). */
    AcceleroDtos.PessoaDetalhe detalharPessoa(String pessoaId);
}
