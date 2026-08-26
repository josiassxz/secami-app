// Edge Function: Send Email Hook do Supabase Auth.
// O Supabase chama esta função em vez de mandar o e-mail pelo sender padrão.
// Aqui renderizamos o HTML da marca REPS e enviamos via Resend (free tier).
// Deploy: --no-verify-jwt (a autenticação é a assinatura do webhook).
//
// Secrets necessários (supabase secrets set):
//   SEND_EMAIL_HOOK_SECRET  -> gerado ao ativar o hook no dashboard (v1,whsec_…)
//   RESEND_API_KEY          -> chave da Resend (https://resend.com)
//   RESEND_FROM             -> remetente verificado, ex: "reps <nao-responda@seu-dominio>"
//                              (sem domínio próprio use onboarding@resend.dev — só envia
//                               pro e-mail dono da conta Resend, serve pra teste)

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const FONT =
  "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

interface Copy {
  subject: string;
  title: string;
  body: string;
  cta: string;
}

// Texto por tipo de e-mail que o Supabase dispara.
function copyFor(action: string): Copy {
  switch (action) {
    case "signup":
      return {
        subject: "Confirme seu e-mail — reps",
        title: "Falta um<br>passo.",
        body:
          "Voc&ecirc; criou conta no <strong style=\"color:#fff;\">reps</strong>. " +
          "Pra come&ccedil;ar a treinar com seu hist&oacute;rico salvo na nuvem, " +
          "confirme seu e-mail no bot&atilde;o abaixo.",
        cta: "CONFIRMAR MEU E-MAIL",
      };
    case "recovery":
      return {
        subject: "Redefinir senha — reps",
        title: "Nova<br>senha.",
        body:
          "Pediram pra redefinir a senha da sua conta reps. Se foi voc&ecirc;, " +
          "clique abaixo. Se n&atilde;o foi, ignore este e-mail.",
        cta: "REDEFINIR SENHA",
      };
    case "email_change":
      return {
        subject: "Confirme seu novo e-mail — reps",
        title: "Troca de<br>e-mail.",
        body:
          "Confirme este novo endere&ccedil;o pra concluir a troca de e-mail " +
          "da sua conta reps.",
        cta: "CONFIRMAR NOVO E-MAIL",
      };
    case "magiclink":
      return {
        subject: "Seu link de acesso — reps",
        title: "Entrar no<br>reps.",
        body: "Seu link de acesso ao reps. Clique pra entrar.",
        cta: "ENTRAR",
      };
    case "invite":
      return {
        subject: "Você foi convidado — reps",
        title: "Bem-vindo<br>ao reps.",
        body: "Voc&ecirc; foi convidado pro reps. Clique pra criar sua conta.",
        cta: "ACEITAR CONVITE",
      };
    default:
      return {
        subject: "reps",
        title: "reps",
        body: "Confirme a ação no botão abaixo.",
        cta: "CONTINUAR",
      };
  }
}

function renderHtml(c: Copy, url: string): string {
  return `<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${c.subject}</title></head>
<body style="margin:0;padding:0;background:#0a0a0b;font-family:${FONT};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0a0b;padding:32px 16px;"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#141416;border:1px solid #26262b;border-radius:16px;overflow:hidden;">
<tr><td style="padding:40px 36px 8px 36px;">
<p style="margin:0;letter-spacing:6px;font-size:13px;font-weight:700;color:#8a8a93;">R E P S</p>
<h1 style="margin:18px 0 0 0;font-size:40px;line-height:1.05;font-weight:800;color:#fff;">${c.title}</h1>
</td></tr>
<tr><td style="padding:18px 36px 0 36px;">
<p style="margin:0;font-size:16px;line-height:1.55;color:#c7c7cf;">${c.body}</p>
</td></tr>
<tr><td align="center" style="padding:32px 36px 8px 36px;">
<a href="${url}" style="display:inline-block;width:100%;box-sizing:border-box;text-align:center;background:#fff;color:#0a0a0b;font-size:15px;font-weight:800;letter-spacing:1px;text-decoration:none;padding:16px 24px;border-radius:10px;">${c.cta}</a>
</td></tr>
<tr><td style="padding:12px 36px 0 36px;">
<p style="margin:0;font-size:13px;line-height:1.5;color:#8a8a93;">O link expira em 24 horas. Se j&aacute; passou, &eacute; s&oacute; pedir um novo pelo app.</p>
</td></tr>
<tr><td style="padding:24px 36px 0 36px;">
<p style="margin:0 0 6px 0;font-size:11px;font-weight:700;letter-spacing:1px;color:#6b6b73;">N&Atilde;O FUNCIONA O BOT&Atilde;O? COPIE A URL:</p>
<p style="margin:0;font-size:12px;line-height:1.5;word-break:break-all;"><a href="${url}" style="color:#7aa2ff;text-decoration:none;">${url}</a></p>
</td></tr>
<tr><td style="padding:28px 36px 36px 36px;">
<p style="margin:0;font-size:12px;line-height:1.5;color:#6b6b73;">N&atilde;o reconhece este e-mail? Ignore &mdash; nada acontece sem clicar neste link.</p>
</td></tr>
</table>
<p style="margin:24px 0 0 0;font-size:11px;letter-spacing:1px;color:#6b6b73;">REPS &middot; DI&Aacute;RIO DE TREINO T&Eacute;CNICO &middot; SEM FIRULA</p>
</td></tr></table></body></html>`;
}

Deno.serve(async (req: Request) => {
  const hookSecret = Deno.env.get("SEND_EMAIL_HOOK_SECRET");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM") ?? "reps <onboarding@resend.dev>";

  if (!hookSecret || !resendKey) {
    return new Response(
      JSON.stringify({ error: "Função sem secrets configurados." }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }

  const raw = await req.text();
  let payload: {
    user: { email: string };
    email_data: {
      token_hash: string;
      redirect_to: string;
      email_action_type: string;
    };
  };
  try {
    // Verifica a assinatura do webhook (standard webhooks). Lança se inválida.
    const wh = new Webhook(hookSecret.replace("v1,whsec_", ""));
    payload = wh.verify(raw, {
      "webhook-id": req.headers.get("webhook-id")!,
      "webhook-timestamp": req.headers.get("webhook-timestamp")!,
      "webhook-signature": req.headers.get("webhook-signature")!,
    }) as typeof payload;
  } catch (_e) {
    return new Response(JSON.stringify({ error: "Assinatura inválida." }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }

  const { user, email_data } = payload;
  const { token_hash, redirect_to, email_action_type } = email_data;

  // Link aponta DIRETO pra nossa pagina, levando o token_hash. A pagina
  // verifica via POST no clique do usuario. Scanners de e-mail so fazem GET
  // (prefetch) e nao rodam JS — entao NAO consomem o token (evita o
  // `otp_expired` quando o usuario clica depois do scanner). Antes o link
  // ia pro /auth/v1/verify, que era consumido no primeiro acesso.
  const sep = redirect_to.includes("?") ? "&" : "?";
  const confirmUrl =
    `${redirect_to}${sep}token_hash=${encodeURIComponent(token_hash)}` +
    `&type=${encodeURIComponent(email_action_type)}`;

  const c = copyFor(email_action_type);
  const html = renderHtml(c, confirmUrl);

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [user.email],
      subject: c.subject,
      html,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    return new Response(JSON.stringify({ error: detail }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }

  return new Response("{}", {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
