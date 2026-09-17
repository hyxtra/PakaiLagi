import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchItems,
  fetchItemById,
  fetchItemsByOwner,
  createItem,
  completeHandover,
} from "../services/itemService";
import { CreateItemDto } from "../types";
import { useAuthStore } from "../store/authStore";

export function useItems() {
  return useQuery({
    queryKey: ["items"],
    queryFn: fetchItems,
  });
}

export function useItemById(id: string) {
  return useQuery({
    queryKey: ["item", id],
    queryFn: () => fetchItemById(id),
    enabled: !!id,
  });
}

export function useMyItems() {
  const profile = useAuthStore((state) => state.Profile);

  return useQuery({
    queryKey: ["myItems", profile?.Id],
    queryFn: () => fetchItemsByOwner(profile!.Id),
    enabled: !!profile?.Id,
  });
}

export function useCreateItem() {
  const queryClient = useQueryClient();
  const profile = useAuthStore((state) => state.Profile);

  return useMutation({
    mutationFn: async ({
      dto,
      imageFile,
    }: {
      dto: CreateItemDto;
      imageFile: { uri: string; type: string; name: string };
    }) => {
      return createItem(profile!.Id, dto, imageFile);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
      queryClient.invalidateQueries({ queryKey: ["myItems"] });
    },
  });
}

export function useCompleteHandover() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (itemId: string) => completeHandover(itemId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
      queryClient.invalidateQueries({ queryKey: ["myItems"] });
    },
  });
}
