import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { Button, Input, Label } from "@/components/ui";
import { AlertCircle } from "lucide-react";
import { mensagemDeErro } from "@/lib/erros";

export default function Login() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await signIn(email, password);
      navigate("/");
    } catch (err: any) {
      setError(mensagemDeErro(err, "Não foi possível entrar."));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-base px-4 py-12">
      {/* Glow decorativo — só tokens de cor existentes, em baixa opacidade, pra dar
          profundidade sem virar decoração chamativa (princípio §1.2 do design system). */}
      <div className="pointer-events-none absolute -left-24 -top-24 h-72 w-72 rounded-full bg-brand-container/60 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-32 -right-16 h-80 w-80 rounded-full bg-lime-container/50 blur-3xl" />

      <div className="relative w-full max-w-[380px]">
        {/* Elemento dominante da tela: identidade institucional (§1 hierarquia em 3s) */}
        <div className="mb-10 flex flex-col items-center text-center">
          <img
            src="/logo-casa-militar.png"
            alt="Casa Militar de Goiás"
            className="mb-4 h-20 w-20 object-contain"
          />
          <h1 className="text-2xl font-bold text-content">Administração SECAMI</h1>
          <p className="mt-1 text-sm text-content-soft">Academia da Casa Militar · Goiás</p>
        </div>

        <form
          onSubmit={handleSubmit}
          className="space-y-5 rounded-lg border border-line bg-surface p-6 shadow-1"
        >
          <div>
            <Label htmlFor="user">E-mail ou usuário</Label>
            <Input
              id="user"
              type="text"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="usuario.rede ou seu.email@goias.gov.br"
              autoFocus
              autoComplete="username"
              autoCapitalize="none"
              spellCheck={false}
            />
          </div>
          <div>
            <Label htmlFor="pass">Senha</Label>
            <Input
              id="pass"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="current-password"
            />
          </div>

          {error && (
            <div
              role="alert"
              className="flex items-center gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger"
            >
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <Button type="submit" className="w-full" loading={loading}>
            Entrar
          </Button>
        </form>

        <p className="mt-6 text-center text-xs leading-relaxed text-content-faint">
          Entre com seu usuário e senha do governo (ou e-mail e senha do cadastro). Problemas de acesso? Fale com a TI/infraestrutura.
        </p>
      </div>
    </div>
  );
}
