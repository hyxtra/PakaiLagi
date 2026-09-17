import React from "react";
import {
  View,
  Text,
  FlatList,
  Image,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from "react-native";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "../navigation/types";
import { Button } from "../components";
import { useRequestsByItem } from "../hooks/useRequests";
import { useApproveRequest } from "../hooks/useRequests";
import { COLORS } from "../constants/colors";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { formatDate } from "../utils/formatDate";
import { ItemRequest, RequestStatus } from "../types";

type Props = NativeStackScreenProps<
  RootStackParamList,
  "ManageRequest"
>;

type RequestWithRequester = ItemRequest & {
  Requester: { FullName: string; AvatarUrl: string | null };
};

const DELIVERY_LABELS: Record<string, string> = {
  AMBIL_LANGSUNG: "Ambil Langsung",
  BERTEMU: "Bertemu",
  KURIR: "Kurir",
};

const STATUS_LABELS: Record<
  string,
  { Label: string; Color: string }
> = {
  PENDING: { Label: "Menunggu", Color: COLORS.Warning },
  ACCEPTED: { Label: "Diterima", Color: COLORS.Success },
  REJECTED: { Label: "Ditolak", Color: COLORS.Error },
};

export default function ManageRequestScreen({
  route,
}: Props) {
  const { ItemId } = route.params;
  const {
    data: requests,
    isLoading,
  } = useRequestsByItem(ItemId);
  const approveMutation = useApproveRequest();

  function handleApprove(requestId: string) {
    Alert.alert(
      "Terima Pengajuan",
      "Pengajuan lain akan otomatis ditolak. Lanjutkan?",
      [
        { text: "Batal", style: "cancel" },
        {
          text: "Terima",
          onPress: () => {
            approveMutation.mutate(
              { requestId, itemId: ItemId },
              {
                onError: () => {
                  Alert.alert(
                    "Gagal",
                    ERROR_MESSAGES.ApproveRequestFailed
                  );
                },
              }
            );
          },
        },
      ]
    );
  }

  function renderRequest({
    item,
  }: {
    item: RequestWithRequester;
  }) {
    const statusInfo = STATUS_LABELS[item.Status] ?? {
      Label: item.Status,
      Color: COLORS.TextMuted,
    };

    return (
      <View style={styles.requestCard}>
        <View style={styles.requesterRow}>
          {item.Requester?.AvatarUrl ? (
            <Image
              source={{ uri: item.Requester.AvatarUrl }}
              style={styles.avatar}
            />
          ) : (
            <View style={styles.avatarPlaceholder}>
              <Text style={styles.avatarInitial}>
                {item.Requester?.FullName?.charAt(0)?.toUpperCase() ??
                  "?"}
              </Text>
            </View>
          )}
          <View style={styles.requesterInfo}>
            <Text style={styles.requesterName}>
              {item.Requester?.FullName ?? "-"}
            </Text>
            <Text style={styles.requestDate}>
              {formatDate(item.CreatedAt)}
            </Text>
          </View>
          <View
            style={[
              styles.statusBadge,
              { backgroundColor: statusInfo.Color + "20" },
            ]}
          >
            <Text
              style={[
                styles.statusText,
                { color: statusInfo.Color },
              ]}
            >
              {statusInfo.Label}
            </Text>
          </View>
        </View>

        <View style={styles.deliveryRow}>
          <Text style={styles.deliveryLabel}>
            Metode Pengambilan:
          </Text>
          <Text style={styles.deliveryValue}>
            {DELIVERY_LABELS[item.DeliveryMethod] ??
              item.DeliveryMethod}
          </Text>
        </View>

        {item.Status === RequestStatus.PENDING ? (
          <View style={styles.actions}>
            <Button
              Title="Terima"
              OnPress={() => handleApprove(item.Id)}
              IsLoading={approveMutation.isPending}
              Style={{ flex: 1, marginRight: 8 }}
            />
            <Button
              Title="Tolak"
              OnPress={() => handleApprove(item.Id)}
              Variant="outline"
              Style={{ flex: 1, marginLeft: 8 }}
            />
          </View>
        ) : null}
      </View>
    );
  }

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.Primary} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={
          (requests as RequestWithRequester[] | undefined) ?? []
        }
        keyExtractor={(item) => item.Id}
        renderItem={renderRequest}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.centered}>
            <Text style={styles.emptyText}>
              Belum ada pengajuan untuk barang ini
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.Background,
  },
  centered: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  emptyText: {
    fontSize: 16,
    color: COLORS.TextSecondary,
  },
  listContent: {
    padding: 16,
    flexGrow: 1,
  },
  requestCard: {
    backgroundColor: COLORS.Surface,
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    elevation: 1,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
  },
  requesterRow: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 12,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginRight: 12,
  },
  avatarPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: COLORS.Primary,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  avatarInitial: {
    fontSize: 18,
    fontWeight: "700",
    color: COLORS.Surface,
  },
  requesterInfo: {
    flex: 1,
  },
  requesterName: {
    fontSize: 16,
    fontWeight: "600",
    color: COLORS.TextPrimary,
    marginBottom: 2,
  },
  requestDate: {
    fontSize: 12,
    color: COLORS.TextMuted,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
  },
  statusText: {
    fontSize: 12,
    fontWeight: "600",
  },
  deliveryRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: COLORS.Background,
    padding: 10,
    borderRadius: 8,
    marginBottom: 12,
  },
  deliveryLabel: {
    fontSize: 13,
    color: COLORS.TextMuted,
    marginRight: 6,
  },
  deliveryValue: {
    fontSize: 14,
    fontWeight: "500",
    color: COLORS.TextPrimary,
  },
  actions: {
    flexDirection: "row",
  },
});
