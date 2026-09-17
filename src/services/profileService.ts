import { supabase } from "./supabase";
import { Profile } from "../types";

export async function fetchProfile(userId: string): Promise<Profile> {
  const { data, error } = await supabase
    .from("Profile")
    .select("*")
    .eq("Id", userId)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as Profile;
}

export async function updateProfile(
  userId: string,
  updates: Partial<Pick<Profile, "FullName" | "PhoneNumber" | "AvatarUrl">>
): Promise<Profile> {
  const { data, error } = await supabase
    .from("Profile")
    .update(updates)
    .eq("Id", userId)
    .select()
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as Profile;
}
