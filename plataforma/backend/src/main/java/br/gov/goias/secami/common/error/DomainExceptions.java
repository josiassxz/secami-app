package br.gov.goias.secami.common.error;

/** Exceções de domínio com semântica HTTP mapeada em {@link GlobalExceptionHandler}. */
public final class DomainExceptions {

    private DomainExceptions() {}

    /** Recurso não encontrado → 404. */
    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) { super(message); }
    }

    /** Violação de regra de negócio → 422. */
    public static class BusinessException extends RuntimeException {
        public BusinessException(String message) { super(message); }
    }

    /** Conflito (duplicidade, estado inválido) → 409. */
    public static class ConflictException extends RuntimeException {
        public ConflictException(String message) { super(message); }
    }

    /** Não autorizado para a ação → 403. */
    public static class ForbiddenException extends RuntimeException {
        public ForbiddenException(String message) { super(message); }
    }
}
