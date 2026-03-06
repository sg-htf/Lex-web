import { create } from "zustand";
type S = "disconnected" | "connecting" | "connected" | "reconnecting";
export const useSignalRStore = create<{ status: S; setStatus: (s: S) => void }>(set => ({ status: "disconnected", setStatus: status => set({ status }) }));
