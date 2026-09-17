import { supabase } from "./supabase";
import { Item, CreateItemDto, ItemStatus } from "../types";

export async function fetchItems(): Promise<Item[]> {
  const { data, error } = await supabase
    .from("Item")
    .select("*")
    .eq("Status", ItemStatus.AVAILABLE)
    .order("CreatedAt", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return data as Item[];
}

export async function fetchItemById(
  id: string
): Promise<Item & { Owner: { FullName: string; AvatarUrl: string | null } }> {
  const { data, error } = await supabase
    .from("Item")
    .select("*, Owner:Profile!OwnerId(FullName, AvatarUrl)")
    .eq("Id", id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as Item & { Owner: { FullName: string; AvatarUrl: string | null } };
}

export async function createItem(
  ownerId: string,
  dto: CreateItemDto,
  imageFile: { uri: string; type: string; name: string }
): Promise<Item> {
  const fileExtension = imageFile.name.split(".").pop();
  const filePath = `items/${ownerId}/${Date.now()}.${fileExtension}`;

  const { error: uploadError } = await supabase.storage
    .from("item-images")
    .upload(filePath, {
      uri: imageFile.uri,
      type: imageFile.type,
      name: imageFile.name,
    } as unknown as File);

  if (uploadError) {
    throw new Error(uploadError.message);
  }

  const { data: publicUrlData } = supabase.storage
    .from("item-images")
    .getPublicUrl(filePath);

  const { data, error } = await supabase
    .from("Item")
    .insert({
      OwnerId: ownerId,
      Title: dto.Title,
      Description: dto.Description,
      Category: dto.Category,
      Status: ItemStatus.AVAILABLE,
      ImageUrl: publicUrlData.publicUrl,
    })
    .select()
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as Item;
}

export async function completeHandover(itemId: string): Promise<void> {
  const { error } = await supabase
    .from("Item")
    .update({ Status: ItemStatus.COMPLETED })
    .eq("Id", itemId);

  if (error) {
    throw new Error(error.message);
  }
}

export async function fetchItemsByOwner(ownerId: string): Promise<Item[]> {
  const { data, error } = await supabase
    .from("Item")
    .select("*")
    .eq("OwnerId", ownerId)
    .order("CreatedAt", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return data as Item[];
}
