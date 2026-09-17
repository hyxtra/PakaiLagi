import { useEffect } from "react";
import { useMutation } from "@tanstack/react-query";
import { supabase } from "../services/supabase";
import { fetchProfile } from "../services/profileService";
import { useAuthStore } from "../store/authStore";

export function useAuth(): void {
  const setSession = useAuthStore((state) => state.setSession);
  const setProfile = useAuthStore((state) => state.setProfile);
  const clearAuth = useAuthStore((state) => state.clearAuth);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session?.user) {
        fetchProfile(session.user.id).then(setProfile).catch(() => {});
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setSession(session);
        if (session?.user) {
          fetchProfile(session.user.id).then(setProfile).catch(() => {});
        } else {
          clearAuth();
        }
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [setSession, setProfile, clearAuth]);
}

export function useLogin() {
  return useMutation({
    mutationFn: async ({
      email,
      password,
    }: {
      email: string;
      password: string;
    }) => {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
  });
}

export function useRegister() {
  return useMutation({
    mutationFn: async ({
      email,
      password,
      fullName,
    }: {
      email: string;
      password: string;
      fullName: string;
    }) => {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      });

      if (error) {
        throw new Error(error.message);
      }

      if (data.user) {
        const { error: profileError } = await supabase
          .from("Profile")
          .insert({
            Id: data.user.id,
            FullName: fullName,
          });

        if (profileError) {
          throw new Error(profileError.message);
        }
      }

      return data;
    },
  });
}

export function useLogout() {
  const clearAuth = useAuthStore((state) => state.clearAuth);

  return useMutation({
    mutationFn: async () => {
      const { error } = await supabase.auth.signOut();

      if (error) {
        throw new Error(error.message);
      }
    },
    onSuccess: () => {
      clearAuth();
    },
  });
}
