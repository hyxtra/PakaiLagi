import React, { useState } from "react";
import {
  View,
  Text,
  Image,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from "react-native";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "../navigation/types";
import { Button } from "../components";
import { useItemById } from "../hooks/useItems";
import { useCompleteHandover } from "../hooks/useItems";
import { useAuthStore } from "../store/authStore";
import { COLORS } from "../constants/colors";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { formatDate } from "../utils/formatDate";
import { ItemStatus } from "../types";
import RequestModal from "./RequestModal";

type Props = NativeStackScreenProps<RootStackParamList, "ItemDetail">;

export default function ItemDetailScreen({ route, navigation }: Props) {
  const { ItemId } = route.params;
  const [isModalVisible, setIsModalVisible] = useState(false);

  const profile = useAuthStore((state) => state.Profile);
  const { data: item, isLoading, isError } = useItemById(ItemId);
  const completeHandoverMutation = useCompleteHandover();

  const isOwner = profile?.Id === item?.OwnerId;

  function handleCompleteHandover() {
    Alert.alert(
      "Serah Terima",
      "Apakah barang sudah diserahkan?",
      [
        { text: "Batal", style: "cancel" },
        {
          text: "Ya, Selesai",
          onPress: () => {
            completeHandoverMutation.mutate(ItemId, {
              onSuccess: () => {
                Alert.alert(
                  "Berhasil",
                  "Serah terima telah selesai!"
                );
                navigation.goBack();
              },
              onError: () => {
                Alert.alert(
                  "Gagal",
                  ERROR_MESSAGES.CompleteHandoverFailed
                );
              },
            });
          },
        },
      ]
    );
  }

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.Primary} />
      </View>
    );
  }

  if (isError || !item) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>
          {ERROR_MESSAGES.FetchItemDetailFailed}
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView>
        <Image
          source={{ uri: item.ImageUrl }}
          style={styles.image}
          resizeMode="cover"
        />

        <View style={styles.content}>
          <View style={styles.categoryBadge}>
            <Text style={styles.categoryText}>{item.Category}</Text>
          </View>

          <Text style={styles.title}>{item.Title}</Text>

          <View style={styles.ownerRow}>
            {item.Owner?.AvatarUrl ? (
              <Image
                source={{ uri: item.Owner.AvatarUrl }}
                style={styles.ownerAvatar}
              />
            ) : (
              <View style={styles.ownerAvatarPlaceholder}>
                <Text style={styles.ownerInitial}>
                  {item.Owner?.FullName?.charAt(0)?.toUpperCase() ??
                    "?"}
                </Text>
              </View>
            )}
            <View>
              <Text style={styles.ownerLabel}>Dibagikan oleh</Text>
              <Text style={styles.ownerName}>
                {item.Owner?.FullName ?? "-"}
              </Text>
            </View>
          </View>

          <Text style={styles.sectionTitle}>Deskripsi</Text>
          <Text style={styles.description}>{item.Description}</Text>

          <Text style={styles.dateText}>
            Dibagikan pada {formatDate(item.CreatedAt)}
          </Text>
        </View>
      </ScrollView>

      {!isOwner && item.Status === ItemStatus.AVAILABLE ? (
        <View style={styles.footer}>
          <Button
            Title="Ajukan Pengambilan"
            OnPress={() => setIsModalVisible(true)}
          />
        </View>
      ) : null}

      {isOwner && item.Status === ItemStatus.RESERVED ? (
        <View style={styles.footer}>
          <Button
            Title="Selesai Serah Terima"
            OnPress={handleCompleteHandover}
            Variant="secondary"
            IsLoading={completeHandoverMutation.isPending}
          />
        </View>
      ) : null}

      <RequestModal
        Visible={isModalVisible}
        ItemId={ItemId}
        OnClose={() => setIsModalVisible(false)}
        OnSuccess={() => {
          setIsModalVisible(false);
          navigation.goBack();
        }}
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
  errorText: {
    fontSize: 16,
    color: COLORS.Error,
    textAlign: "center",
  },
  image: {
    width: "100%",
    height: 300,
  },
  content: {
    padding: 20,
  },
  categoryBadge: {
    alignSelf: "flex-start",
    backgroundColor: COLORS.Primary + "15",
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 8,
    marginBottom: 12,
  },
  categoryText: {
    fontSize: 13,
    color: COLORS.Primary,
    fontWeight: "500",
  },
  title: {
    fontSize: 24,
    fontWeight: "700",
    color: COLORS.TextPrimary,
    marginBottom: 16,
  },
  ownerRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: COLORS.Surface,
    padding: 12,
    borderRadius: 12,
    marginBottom: 20,
    elevation: 1,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
  },
  ownerAvatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginRight: 12,
  },
  ownerAvatarPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: COLORS.Primary,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  ownerInitial: {
    fontSize: 18,
    fontWeight: "700",
    color: COLORS.Surface,
  },
  ownerLabel: {
    fontSize: 12,
    color: COLORS.TextMuted,
    marginBottom: 2,
  },
  ownerName: {
    fontSize: 16,
    fontWeight: "600",
    color: COLORS.TextPrimary,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: COLORS.TextPrimary,
    marginBottom: 8,
  },
  description: {
    fontSize: 15,
    color: COLORS.TextSecondary,
    lineHeight: 22,
    marginBottom: 16,
  },
  dateText: {
    fontSize: 13,
    color: COLORS.TextMuted,
  },
  footer: {
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: COLORS.Border,
    backgroundColor: COLORS.Surface,
  },
});
