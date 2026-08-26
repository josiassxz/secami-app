# Política de privacidade — reps

Última atualização: 26/05/2026.

## Quem somos

**reps** é um diário de treino técnico. O app é desenvolvido para uso pessoal, sem fins publicitários e sem coleta de dados sensíveis além do estritamente necessário para funcionar.

## Quais dados coletamos

- **Modo convidado**: só dados locais no seu dispositivo. Nada sai do celular.
- **Com conta**: e-mail, senha (hash), nome opcional, preferências de unidade.
- **Treinos**: rotinas, séries registradas, recordes, sessões de cardio.

Não coletamos: localização, contatos, fotos, redes sociais, dispositivos vinculados.

## Como usamos

- Sincronizar seus treinos entre dispositivos (apenas com conta).
- Calcular sugestões de carga e detectar recordes pessoais.
- Métricas anônimas de uso (PostHog) para entender que features funcionam — sem rastreio de identidade.
- Captura de erros (Sentry) para corrigir bugs — não inclui dados de treino.

## Onde guardamos

- Local: SQLite no dispositivo, criptografado pelo sistema operacional.
- Nuvem (com conta): Supabase (Postgres gerenciado, hospedado em servidores compatíveis com GDPR/LGPD).
- Row-Level Security garante que **só você** acessa seus dados.

## Seus direitos (LGPD)

- **Exportar**: vai em Ajustes → Exportar dados (CSV ou JSON). Funciona sempre.
- **Excluir conta**: Ajustes → Excluir conta. Removemos tudo em até 30 dias.
- **Corrigir**: edite qualquer registro direto no app.
- **Acessar**: a exportação cobre 100% dos dados que temos sobre você.

## Sobre saúde

O reps **não substitui acompanhamento profissional** (fisioterapeuta, médico, educador físico). Sugestões de progressão de carga são apenas sugestões. Em caso de dor ou lesão, pare e procure orientação.

## Contato

Para qualquer dúvida sobre privacidade ou para exercer seus direitos: **suporte@reps.app** (placeholder).
