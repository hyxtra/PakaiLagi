import { create } from "zustand";
import { Session } from "@supabase/supabase-js";
import { Profile } from "../types";

interface AuthState {
  Session: Session | null;
  Profile: Profile | null;
  IsLoading: boolean;
  setSession: (session: Session | null) => void;
  setProfile: (profile: Profile | null) => void;
  clearAuth: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  Session: null,
  Profile: null,
  IsLoading: true,
  setSession: (session: Session | null) =>
    set({ Session: session, IsLoading: false }),
  setProfile: (profile: Profile | null) => set({ Profile: profile }),
  clearAuth: () =>
    set({ Session: null, Profile: null, IsLoading: false }),
}));
