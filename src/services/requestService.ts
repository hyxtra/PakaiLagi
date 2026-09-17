import { supabase } from "./supabase";
import {
  ItemRequest,
  RequestStatus,
  DeliveryMethod,
  ItemStatus,
} from "../types";

export async function createRequest(
  requesterId: string,
  itemId: string,
  deliveryMethod: DeliveryMethod
): Promise<ItemRequest> {
  const { data, error } = await supabase
    .from("ItemRequest")
    .insert({
      ItemId: itemId,
      RequesterId: requesterId,
      Status: RequestStatus.PENDING,
      DeliveryMethod: deliveryMethod,
    })
    .select()
    .single();

  if (error) {
    throw new Error(error.message);
  }

  const { error: updateError } = await supabase
    .from("Item")
    .update({ Status: ItemStatus.REQUESTED })
    .eq("Id", itemId);

  if (updateError) {
    throw new Error(updateError.message);
  }

  return data as ItemRequest;
}

export async function approveRequest(
  requestId: string,
  itemId: string
): Promise<void> {
  const { error: acceptError } = await supabase
    .from("ItemRequest")
    .update({ Status: RequestStatus.ACCEPTED })
    .eq("Id", requestId);

  if (acceptError) {
    throw new Error(acceptError.message);
  }

  const { error: rejectError } = await supabase
    .from("ItemRequest")
    .update({ Status: RequestStatus.REJECTED })
    .eq("ItemId", itemId)
    .neq("Id", requestId)
    .eq("Status", RequestStatus.PENDING);

  if (rejectError) {
    throw new Error(rejectError.message);
  }

  const { error: itemError } = await supabase
    .from("Item")
    .update({ Status: ItemStatus.RESERVED })
    .eq("Id", itemId);

  if (itemError) {
    throw new Error(itemError.message);
  }
}

export async function fetchRequestsByItem(
  itemId: string
): Promise<(ItemRequest & { Requester: { FullName: string; AvatarUrl: string | null } })[]> {
  const { data, error } = await supabase
    .from("ItemRequest")
    .select("*, Requester:Profile!RequesterId(FullName, AvatarUrl)")
    .eq("ItemId", itemId)
    .order("CreatedAt", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return data as (ItemRequest & { Requester: { FullName: string; AvatarUrl: string | null } })[];
}

export async function fetchRequestsByUser(
  userId: string
): Promise<(ItemRequest & { Item: { Title: string; ImageUrl: string; Status: ItemStatus } })[]> {
  const { data, error } = await supabase
    .from("ItemRequest")
    .select("*, Item!ItemId(Title, ImageUrl, Status)")
    .eq("RequesterId", userId)
    .order("CreatedAt", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return data as (ItemRequest & {
    Item: { Title: string; ImageUrl: string; Status: ItemStatus };
  })[];
}
