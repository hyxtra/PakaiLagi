import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchRequestsByItem,
  fetchRequestsByUser,
  createRequest,
  approveRequest,
} from "../services/requestService";
import { DeliveryMethod } from "../types";
import { useAuthStore } from "../store/authStore";

export function useRequestsByItem(itemId: string) {
  return useQuery({
    queryKey: ["requestsByItem", itemId],
    queryFn: () => fetchRequestsByItem(itemId),
    enabled: !!itemId,
  });
}

export function useMyRequests() {
  const profile = useAuthStore((state) => state.Profile);

  return useQuery({
    queryKey: ["myRequests", profile?.Id],
    queryFn: () => fetchRequestsByUser(profile!.Id),
    enabled: !!profile?.Id,
  });
}

export function useCreateRequest() {
  const queryClient = useQueryClient();
  const profile = useAuthStore((state) => state.Profile);

  return useMutation({
    mutationFn: async ({
      itemId,
      deliveryMethod,
    }: {
      itemId: string;
      deliveryMethod: DeliveryMethod;
    }) => {
      return createRequest(profile!.Id, itemId, deliveryMethod);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
      queryClient.invalidateQueries({ queryKey: ["myRequests"] });
    },
  });
}

export function useApproveRequest() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      requestId,
      itemId,
    }: {
      requestId: string;
      itemId: string;
    }) => {
      return approveRequest(requestId, itemId);
    },
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
      queryClient.invalidateQueries({ queryKey: ["myItems"] });
      queryClient.invalidateQueries({
        queryKey: ["requestsByItem", variables.itemId],
      });
    },
  });
}
