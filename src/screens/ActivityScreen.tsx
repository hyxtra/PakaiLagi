import React, { useState } from "react";
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  Image,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import { useNavigation } from "@react-navigation/native";
import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { RootStackParamList } from "../navigation/types";
import { useMyRequests } from "../hooks/useRequests";
import { useMyItems } from "../hooks/useItems";
import { COLORS } from "../constants/colors";
import { formatDate } from "../utils/formatDate";
import { Item, ItemRequest, ItemStatus } from "../types";

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

type RequestWithItem = ItemRequest & {
  Item: { Title: string; ImageUrl: string; Status: ItemStatus };
};

const STATUS_LABELS: Record<string, { Label: string; Color: string }> = {
  PENDING: { Label: "Menunggu", Color: COLORS.Warning },
  ACCEPTED: { Label: "Diterima", Color: COLORS.Success },
  REJECTED: { Label: "Ditolak", Color: COLORS.Error },
  AVAILABLE: { Label: "Tersedia", Color: COLORS.Success },
  REQUESTED: { Label: "Diajukan", Color: COLORS.Warning },
  RESERVED: { Label: "Dipesan", Color: COLORS.Primary },
  COMPLETED: { Label: "Selesai", Color: COLORS.TextMuted },
};

export default function ActivityScreen() {
  const [activeTab, setActiveTab] = useState<
    "requests" | "myItems"
  >("requests");

  const navigation = useNavigation<NavigationProp>();
  const myRequestsQuery = useMyRequests();
  const myItemsQuery = useMyItems();

  function renderRequestItem({
    item,
  }: {
    item: RequestWithItem;
  }) {
    const statusInfo = STATUS_LABELS[item.Status] ?? {
      Label: item.Status,
      Color: COLORS.TextMuted,
    };

    return (
      <View style={styles.itemRow}>
        <Image
          source={{ uri: item.Item.ImageUrl }}
          style={styles.itemImage}
        />
        <View style={styles.itemInfo}>
          <Text style={styles.itemTitle} numberOfLines={1}>
            {item.Item.Title}
          </Text>
          <Text style={styles.itemDate}>
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
    );
  }

  function renderMyItem({ item }: { item: Item }) {
    const statusInfo = STATUS_LABELS[item.Status] ?? {
      Label: item.Status,
      Color: COLORS.TextMuted,
    };

    return (
      <TouchableOpacity
        style={styles.itemRow}
        onPress={() =>
          navigation.navigate("ManageRequest", {
            ItemId: item.Id,
          })
        }
      >
        <Image
          source={{ uri: item.ImageUrl }}
          style={styles.itemImage}
        />
        <View style={styles.itemInfo}>
          <Text style={styles.itemTitle} numberOfLines={1}>
            {item.Title}
          </Text>
          <Text style={styles.itemDate}>
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
      </TouchableOpacity>
    );
  }

  const isLoading =
    activeTab === "requests"
      ? myRequestsQuery.isLoading
      : myItemsQuery.isLoading;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Aktivitas</Text>
      </View>

      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[
            styles.tab,
            activeTab === "requests" && styles.tabActive,
          ]}
          onPress={() => setActiveTab("requests")}
        >
          <Text
            style={[
              styles.tabText,
              activeTab === "requests" && styles.tabTextActive,
            ]}
          >
            Menunggu Persetujuan
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[
            styles.tab,
            activeTab === "myItems" && styles.tabActive,
          ]}
          onPress={() => setActiveTab("myItems")}
        >
          <Text
            style={[
              styles.tabText,
              activeTab === "myItems" && styles.tabTextActive,
            ]}
          >
            Barang Saya
          </Text>
        </TouchableOpacity>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={COLORS.Primary} />
        </View>
      ) : activeTab === "requests" ? (
        <FlatList
          data={
            (myRequestsQuery.data as RequestWithItem[] | undefined) ??
            []
          }
          keyExtractor={(item) => item.Id}
          renderItem={renderRequestItem}
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            <View style={styles.centered}>
              <Text style={styles.emptyText}>
                Belum ada pengajuan
              </Text>
            </View>
          }
        />
      ) : (
        <FlatList
          data={myItemsQuery.data ?? []}
          keyExtractor={(item) => item.Id}
          renderItem={renderMyItem}
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            <View style={styles.centered}>
              <Text style={styles.emptyText}>
                Belum ada barang dibagikan
              </Text>
            </View>
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.Background,
  },
  header: {
    backgroundColor: COLORS.Primary,
    paddingTop: 50,
    paddingBottom: 16,
    paddingHorizontal: 20,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: "800",
    color: COLORS.Surface,
  },
  tabBar: {
    flexDirection: "row",
    backgroundColor: COLORS.Surface,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.Border,
  },
  tab: {
    flex: 1,
    paddingVertical: 14,
    alignItems: "center",
    borderBottomWidth: 2,
    borderBottomColor: "transparent",
  },
  tabActive: {
    borderBottomColor: COLORS.Primary,
  },
  tabText: {
    fontSize: 14,
    fontWeight: "500",
    color: COLORS.TextSecondary,
  },
  tabTextActive: {
    color: COLORS.Primary,
    fontWeight: "600",
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
  itemRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: COLORS.Surface,
    borderRadius: 12,
    padding: 12,
    marginBottom: 10,
    elevation: 1,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
  },
  itemImage: {
    width: 56,
    height: 56,
    borderRadius: 10,
    backgroundColor: COLORS.Border,
  },
  itemInfo: {
    flex: 1,
    marginLeft: 12,
  },
  itemTitle: {
    fontSize: 15,
    fontWeight: "600",
    color: COLORS.TextPrimary,
    marginBottom: 4,
  },
  itemDate: {
    fontSize: 12,
    color: COLORS.TextMuted,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    marginLeft: 8,
  },
  statusText: {
    fontSize: 12,
    fontWeight: "600",
  },
});
