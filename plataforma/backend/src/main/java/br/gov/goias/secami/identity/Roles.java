package br.gov.goias.secami.identity;

import java.util.Set;

/** Papéis do RBAC (SPEC §3.1). Armazenados em minúsculas em user_role. */
public final class Roles {

    public static final String ADMIN = "admin";
    public static final String GERENTE = "gerente";
    public static final String RECEPCAO = "recepcao";
    /** Perfil "Instrutor" na interface (app e admin): prescreve fichas de treino. */
    public static final String PROFESSOR = "professor";
    public static final String ALUNO = "aluno";

    public static final Set<String> ALL = Set.of(ADMIN, GERENTE, RECEPCAO, PROFESSOR, ALUNO);

    private Roles() {}
}
