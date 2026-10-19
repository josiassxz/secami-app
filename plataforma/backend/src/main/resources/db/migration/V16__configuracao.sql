-- Configurações ajustáveis pelo admin (chave/valor). Primeira: quanto tempo
-- a catraca fica liberada pro civil a partir do horário marcado.
CREATE TABLE configuracao (
    chave         text PRIMARY KEY,
    valor         text NOT NULL,
    atualizado_em timestamptz NOT NULL DEFAULT now()
);
INSERT INTO configuracao (chave, valor) VALUES ('catraca_janela_horas', '5');
