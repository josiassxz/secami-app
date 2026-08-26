import type { ReactElement } from "react";
import { render } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";

/** QueryClient novo a cada teste, sem retry — evita testes lentos quando um
 *  erro é simulado (por padrão o react-query tenta de novo com backoff). */
export function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
}

/** Helper de render pras telas do admin: injeta QueryClientProvider (pra
 *  useQuery/useMutation funcionarem) e MemoryRouter (pra <Link>/useNavigate). */
export function renderWithProviders(
  ui: ReactElement,
  {
    route = "/",
    queryClient = createTestQueryClient(),
  }: { route?: string; queryClient?: QueryClient } = {}
) {
  return {
    queryClient,
    ...render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[route]}>{ui}</MemoryRouter>
      </QueryClientProvider>
    ),
  };
}
