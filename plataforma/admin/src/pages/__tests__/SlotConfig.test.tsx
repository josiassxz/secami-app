import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import SlotConfig from "@/pages/SlotConfig";
import { api } from "@/lib/api";
import { ApiError } from "@/lib/erros";
import { toast } from "@/lib/toast";
import { renderWithProviders } from "./render-with-providers";

vi.mock("@/lib/api", () => ({ api: vi.fn() }));
vi.mock("@/lib/toast", () => ({ toast: vi.fn() }));
const apiMock = vi.mocked(api);
const toastMock = vi.mocked(toast);

const SLOTS = [
  { id: "s1", slotStart: "06:00", slotEnd: "07:00", maxCapacity: 40, civilRestricted: false, blocked: false },
  { id: "s2", slotStart: "12:00", slotEnd: "13:00", maxCapacity: 40, civilRestricted: false, blocked: false },
];

function setupApi(onDelete: () => Promise<unknown> = async () => undefined) {
  const deletes: string[] = [];
  apiMock.mockImplementation(async (path: string, opts?: any) => {
    if (opts?.method === "DELETE") {
      deletes.push(path);
      return onDelete();
    }
    return SLOTS;
  });
  return deletes;
}

afterEach(() => {
  apiMock.mockReset();
  toastMock.mockReset();
});

describe("Config. Horários - excluir", () => {
  it("tem uma lixeira ao lado do lápis em cada horário", async () => {
    setupApi();
    renderWithProviders(<SlotConfig />);
    expect(await screen.findByRole("button", { name: "Editar horário 06:00–07:00" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Excluir horário 06:00–07:00" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Excluir horário 12:00–13:00" })).toBeInTheDocument();
  });

  it("só exclui depois de confirmar", async () => {
    const deletes = setupApi();
    renderWithProviders(<SlotConfig />);
    fireEvent.click(await screen.findByRole("button", { name: "Excluir horário 06:00–07:00" }));
    const d = screen.getByRole("dialog");
    expect(within(d).getByText(/Excluir o horário 06:00–07:00\?/)).toBeInTheDocument();
    expect(deletes).toHaveLength(0);

    fireEvent.click(within(d).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(deletes).toEqual(["/slot-configs/s1"]));
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("success", "Horário 06:00–07:00 excluído."));
  });

  it("cancelar não exclui", async () => {
    const deletes = setupApi();
    renderWithProviders(<SlotConfig />);
    fireEvent.click(await screen.findByRole("button", { name: "Excluir horário 12:00–13:00" }));
    fireEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Cancelar" }));
    await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
    expect(deletes).toHaveLength(0);
  });

  it("mostra a mensagem do servidor quando o horário ainda tem agendamentos", async () => {
    const msg = "O horário 12:00 ainda tem 3 agendamentos ativos de hoje em diante.";
    setupApi(async () => { throw new ApiError(409, msg); });
    renderWithProviders(<SlotConfig />);
    fireEvent.click(await screen.findByRole("button", { name: "Excluir horário 12:00–13:00" }));
    fireEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(toastMock).toHaveBeenCalledWith("error", msg));
  });
});
