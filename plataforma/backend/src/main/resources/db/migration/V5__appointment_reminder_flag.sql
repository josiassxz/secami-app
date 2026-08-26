-- Evita reenviar o lembrete por e-mail em execuções vizinhas do cron (a
-- janela de 57-62min é mais larga que o intervalo de 5min entre execuções,
-- então o mesmo agendamento pode cair na janela em mais de um tick).
ALTER TABLE appointment ADD COLUMN lembrete_enviado boolean NOT NULL DEFAULT false;
