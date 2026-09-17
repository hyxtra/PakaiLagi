import { useMutation } from "@tanstack/react-query";
import { updateProfile } from "../services/profileService";
import { Profile } from "../types";
import { useAuthStore } from "../store/authStore";

export function useUpdateProfile() {
  const setProfile = useAuthStore((state) => state.setProfile);
  const profile = useAuthStore((state) => state.Profile);

  return useMutation({
    mutationFn: async (
      updates: Partial<Pick<Profile, "FullName" | "PhoneNumber" | "AvatarUrl">>
    ) => {
      return updateProfile(profile!.Id, updates);
    },
    onSuccess: (updatedProfile) => {
      setProfile(updatedProfile);
    },
  });
}
