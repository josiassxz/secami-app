package br.gov.goias.secami.accelero;

/** Erro de comunicação com o Accelero (rede, login, resposta inesperada). */
public class AcceleroException extends RuntimeException {
    public AcceleroException(String message) {
        super(message);
    }

    public AcceleroException(String message, Throwable cause) {
        super(message, cause);
    }
}
