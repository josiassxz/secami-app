import React from 'react';
import { base44 } from '@/api/base44Client';
import { ShieldAlert } from 'lucide-react';

const UserNotRegisteredError = () => {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-background p-4">
      <div className="max-w-md w-full p-8 bg-card rounded-2xl shadow-xl border border-border text-center space-y-5">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-destructive/10">
          <ShieldAlert className="w-8 h-8 text-destructive" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-foreground mb-2">Acesso não autorizado</h1>
          <p className="text-muted-foreground text-sm leading-relaxed">
            Sua conta não está cadastrada neste sistema. Por favor, procure a <strong className="text-foreground">recepção da academia</strong> para solicitar acesso ou verificar seu cadastro.
          </p>
        </div>
        <div className="bg-muted/40 border border-border rounded-xl p-4 text-sm text-muted-foreground text-left space-y-1.5">
          <p className="font-medium text-foreground">O que fazer:</p>
          <ul className="list-disc list-inside space-y-1">
            <li>Certifique-se de estar usando o e-mail correto</li>
            <li>Fale com a recepção para liberar seu acesso</li>
            <li>Tente sair e entrar novamente</li>
          </ul>
        </div>
        <button
          onClick={() => base44.auth.logout('/')}
          className="w-full py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
        >
          Sair e tentar novamente
        </button>
      </div>
    </div>
  );
};

export default UserNotRegisteredError;