import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { clearTokens, getAccessToken, login as apiLogin, me, type Me } from "./api";

type AuthCtx = {
  user: Me | null;
  loading: boolean;
  signIn: (username: string, password: string) => Promise<void>;
  signOut: () => void;
  hasRole: (...roles: string[]) => boolean;
};

const Ctx = createContext<AuthCtx>(null as any);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      if (getAccessToken()) {
        try {
          setUser(await me());
        } catch {
          clearTokens();
        }
      }
      setLoading(false);
    })();
  }, []);

  // Disparado pelo api.ts quando um refresh de token falha (refresh ausente/
  // expirado/inválido). Sem isso o `user` ficava preso no state antigo e o
  // roteador (App.tsx) nunca mandava de volta pro /login — mesmo com os
  // tokens já limpos do localStorage.
  useEffect(() => {
    function onAuthExpired() {
      setUser(null);
    }
    window.addEventListener("secami:auth-expired", onAuthExpired);
    return () => window.removeEventListener("secami:auth-expired", onAuthExpired);
  }, []);

  async function signIn(username: string, password: string) {
    await apiLogin(username, password);
    setUser(await me());
  }

  function signOut() {
    clearTokens();
    setUser(null);
  }

  function hasRole(...roles: string[]) {
    return !!user && roles.some((r) => user.roles.includes(r));
  }

  return (
    <Ctx.Provider value={{ user, loading, signIn, signOut, hasRole }}>
      {children}
    </Ctx.Provider>
  );
}

export function useAuth() {
  return useContext(Ctx);
}
