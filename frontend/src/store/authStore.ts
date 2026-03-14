import { create } from "zustand";
import { persist } from "zustand/middleware";

interface AuthState {
  token: string | null;
  sessionId: string | null;
  username: string | null;
  avatarId: number | null;
  emailVerified: boolean | null;
  email: string | null; // held temporarily during register flow, cleared after
  _hasHydrated: boolean;
  setHasHydrated: (v: boolean) => void;
  setEmail: (email: string) => void;
  clearEmail: () => void;
  setAuth: (token: string, sessionId: string) => void;
  setProfile: (username: string, avatarId: number) => void;
  setAvatarId: (id: number) => void;
  setEmailVerified: (verified: boolean) => void;
  clear: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      sessionId: null,
      username: null,
      avatarId: null,
      emailVerified: null,
      email: null,
      _hasHydrated: false,

      setHasHydrated: (v) => set({ _hasHydrated: v }),
      setEmail: (email) => set({ email }),
      clearEmail: () => set({ email: null }),

      setAuth: (token, sessionId) => set({ token, sessionId }),

      setProfile: (username, avatarId) =>
        set({ username, avatarId }),

      setAvatarId: (id) => set({ avatarId: id }),

      setEmailVerified: (verified) => set({ emailVerified: verified }),

      clear: () =>
        set({
          token: null,
          sessionId: null,
          username: null,
          avatarId: null,
          emailVerified: null,
          email: null,
        }),
    }),
    {
      name: "Ventigo-auth",
      // Only persist token + profile - not email (sensitive)
      partialize: (state) => ({
        token: state.token,
        sessionId: state.sessionId,
        username: state.username,
        avatarId: state.avatarId,
        emailVerified: state.emailVerified,
      }),
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
    }
  )
);
