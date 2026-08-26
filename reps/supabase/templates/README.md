# Confirmação de e-mail — página de agradecimento + template

Fluxo: e-mail → Supabase valida o token em `/auth/v1/verify` (confirma o
e-mail) → redireciona para `redirect_to` = a **página de agradecimento**
(`auth-callback.html`).

> **Por que não é servida pelo Supabase?** O Supabase força `text/plain` +
> `nosniff` em HTML no domínio `supabase.co` (anti-phishing) — vale para
> Edge Functions E Storage. Então HTML não renderiza no navegador a partir
> do supabase.co. A página estática vive no **Vercel**
> (`https://web-cubos.vercel.app/auth-callback`). Tudo o mais (auth, e-mail
> via hook, banco) continua no Supabase.

- **Desktop**: a página faz `POST /auth/v1/verify` com o `token_hash` no
  clique → confirma → "Tudo certo!".
- **Mobile**: tenta abrir o app nativo (`reps://auth-callback?token_hash=...`),
  que confirma via `DeepLinkListener`. Sem app, "continuar no navegador".

> **Anti-prefetch:** o link do e-mail aponta pra ESTA página com `token_hash`,
> NÃO pro `/auth/v1/verify` direto. Scanners de e-mail (Gmail, antivírus) fazem
> GET no link pra escanear; se o link fosse o `/verify`, esse GET consumiria o
> token de uso único e o clique real do usuário daria `otp_expired`. Como o link
> é a página estática (e a verificação é um POST via JS no clique), o prefetch
> não consome — só o clique humano confirma.

## 1. Deploy da página (Vercel)

Arquivo: [../auth-page/auth-callback.html](../auth-page/auth-callback.html).
Deploy como `index.html` num projeto Vercel estático (rewrite all → index):

```bash
D=$(mktemp -d); cp supabase/auth-page/auth-callback.html "$D/index.html"
printf '{"rewrites":[{"source":"/(.*)","destination":"/index.html"}]}' > "$D/vercel.json"
cd "$D" && vercel link --yes --project web --scope cubos && vercel deploy --prod --yes
```

URL: `https://web-cubos.vercel.app/auth-callback`.
Garanta que o **Deployment Protection (Vercel Authentication)** esteja
**Disabled** no projeto, senão cai num login da Vercel.

## 2. Setar no app

No `.env` (já feito):

```
AUTH_REDIRECT_URL=https://web-cubos.vercel.app/auth-callback
```

`emailRedirectTo` no signup/troca-de-e-mail/reset usa esse valor.

## 3. Allow-list no Supabase

Dashboard > **Authentication > URL Configuration > Redirect URLs**, adicione:

- `https://web-cubos.vercel.app/auth-callback`
- `reps://auth-callback` (mantém o deep link nativo)

Sem isso o Supabase recusa o `redirect_to` e cai na Site URL.

## 4. E-mail bonito (Send Email Hook)

Os e-mails de auth saem por um **Send Email Hook**, não pelo sender padrão
(capado e sem template custom no free). A função
[../functions/send-email/index.ts](../functions/send-email/index.ts) verifica a
assinatura, monta o link `/auth/v1/verify?...` e envia o HTML da marca REPS via
**Resend**.

Setup:

1. Deploy: `npx supabase functions deploy send-email --project-ref shxphqrnlkhyjxkzrtpd --no-verify-jwt`
2. Dashboard > **Auth > Hooks > Send Email Hook** → Enable, HTTPS, URI =
   `https://shxphqrnlkhyjxkzrtpd.supabase.co/functions/v1/send-email` → copia o
   secret gerado.
3. Secrets da função:
   `supabase secrets set RESEND_API_KEY=... SEND_EMAIL_HOOK_SECRET=v1,whsec_... RESEND_FROM="reps <...>"`

> `RESEND_FROM=onboarding@resend.dev` só entrega pro e-mail dono da conta
> Resend. Pra beta/prod: verificar um domínio na Resend.

## 5. Testar

1. Página no ar + allow-list ok + `AUTH_REDIRECT_URL` setado + hook ligado.
2. Criar conta nova → abrir o e-mail no desktop → clicar.
3. Esperado: cai na página, vê "Tudo certo! / Cadastro confirmado".
4. No celular: tenta abrir o app; sem app, mostra a página web.
