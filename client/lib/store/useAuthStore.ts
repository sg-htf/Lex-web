import { create } from "zustand";
interface AuthState { userId: string | null; email: string | null; roles: string[]; isAuthenticated: boolean; setUser: (u: { userId: string; email: string; roles: string[] }) => void; clearUser: () => void; }
export const useAuthStore = create<AuthState>(set => ({ userId: null, email: null, roles: [], isAuthenticated: false, setUser: ({ userId, email, roles }) => set({ userId, email, roles, isAuthenticated: true }), clearUser: () => set({ userId: null, email: null, roles: [], isAuthenticated: false }) }));
