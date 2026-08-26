import { useState } from 'react';
import { base44 } from '@/api/base44Client';
import { Lock, User } from 'lucide-react';

export default function StudentLogin() {
  const [loginType, setLoginType] = useState('email');
  const [email, setEmail] = useState('');
  const [cpf, setCpf] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const maskCPF = (v) => {
    const n = v.replace(/\D/g, '').slice(0, 11);
    if (n.length <= 3) return n;
    if (n.length <= 6) return `${n.slice(0,3)}.${n.slice(3)}`;
    if (n.length <= 9) return `${n.slice(0,3)}.${n.slice(3,6)}.${n.slice(6)}`;
    return `${n.slice(0,3)}.${n.slice(3,6)}.${n.slice(6,9)}-${n.slice(9)}`;
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const payload = loginType === 'email' 
        ? { email, password }
        : { cpf, password };
      const response = await base44.functions.invoke('studentLogin', payload);
      if (response.data.success) {
        localStorage.setItem('studentSession', JSON.stringify({
          student_id: response.data.student_id,
          student_name: response.data.student_name,
          student_type: response.data.student_type,
          user_id: response.data.user_id
        }));
        window.location.href = '/my-workout';
      }
    } catch (err) {
      setError(loginType === 'email' ? 'Email ou senha inválidos' : 'CPF ou senha inválidos');
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-background/80 flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-card border border-border rounded-2xl shadow-xl p-8">
        <div className="flex justify-center mb-6">
          <img
            src="https://media.base44.com/images/public/69c292e80a168be0a1fb9df3/c56ee6484_Logo_secami.jpg"
            alt="Logo"
            className="w-16 h-16 rounded-full object-cover"
          />
        </div>
        
        <h1 className="text-2xl font-bold text-foreground text-center mb-2">Academia Secami</h1>
        <p className="text-muted-foreground text-center text-sm mb-6">Login do Aluno</p>

        <div className="flex gap-2 mb-6 bg-secondary rounded-lg p-1">
          <button
            type="button"
            onClick={() => setLoginType('email')}
            className={`flex-1 py-2 rounded-md text-xs font-medium transition-colors ${
              loginType === 'email'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            Email
          </button>
          <button
            type="button"
            onClick={() => setLoginType('cpf')}
            className={`flex-1 py-2 rounded-md text-xs font-medium transition-colors ${
              loginType === 'cpf'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            CPF
          </button>
        </div>

        <form onSubmit={handleLogin} className="space-y-4">
          {loginType === 'email' && (
            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1">Email</label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="seu@email.com"
                  className="w-full bg-background border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                  disabled={loading}
                />
              </div>
            </div>
          )}
          {loginType === 'cpf' && (
            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1">CPF</label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <input
                  type="text"
                  value={cpf}
                  onChange={e => setCpf(maskCPF(e.target.value))}
                  placeholder="000.000.000-00"
                  maxLength={14}
                  className="w-full bg-background border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                  disabled={loading}
                />
              </div>
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">Senha</label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="Digite sua senha"
                className="w-full bg-background border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                disabled={loading}
              />
            </div>
          </div>

          {error && (
            <div className="bg-destructive/10 border border-destructive/30 rounded-lg p-3 text-xs text-destructive">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading || (loginType === 'email' ? !email || !password : !cpf || !password)}
            className="w-full bg-primary text-primary-foreground py-2.5 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="text-xs text-muted-foreground text-center mt-6">
          Fale com a recepção se não tiver senha
        </p>
      </div>
    </div>
  );
}