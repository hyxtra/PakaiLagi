import React, { useState, useMemo } from "react";
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useNavigation } from "@react-navigation/native";
import { RootStackParamList } from "../navigation/types";
import { Card } from "../components";
import { useItems } from "../hooks/useItems";
import { CATEGORIES } from "../constants/categories";
import { COLORS } from "../constants/colors";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { Item } from "../types";

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

export default function HomeScreen() {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(
    null
  );

  const { data: items, isLoading, isError, refetch } = useItems();
  const navigation = useNavigation<NavigationProp>();

  const filteredItems = useMemo(() => {
    if (!items) return [];

    let result = items;

    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter((item: Item) =>
        item.Title.toLowerCase().includes(query)
      );
    }

    if (selectedCategory) {
      result = result.filter(
        (item: Item) => item.Category === selectedCategory
      );
    }

    return result;
  }, [items, searchQuery, selectedCategory]);

  function handleCategoryPress(category: string) {
    setSelectedCategory(
      selectedCategory === category ? null : category
    );
  }

  function renderItem({ item }: { item: Item }) {
    return (
      <Card
        Item={item}
        OnPress={() =>
          navigation.navigate("ItemDetail", { ItemId: item.Id })
        }
      />
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>PakaiLagi</Text>
      </View>

      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Cari barang..."
          placeholderTextColor={COLORS.TextMuted}
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
      </View>

      <View style={styles.categoryContainer}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.categoryScroll}
        >
          {CATEGORIES.map((category) => (
            <TouchableOpacity
              key={category}
              style={[
                styles.categoryChip,
                selectedCategory === category &&
                  styles.categoryChipActive,
              ]}
              onPress={() => handleCategoryPress(category)}
            >
              <Text
                style={[
                  styles.categoryChipText,
                  selectedCategory === category &&
                    styles.categoryChipTextActive,
                ]}
              >
                {category}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={COLORS.Primary} />
        </View>
      ) : isError ? (
        <View style={styles.centered}>
          <Text style={styles.errorText}>
            {ERROR_MESSAGES.FetchItemsFailed}
          </Text>
          <TouchableOpacity onPress={() => refetch()}>
            <Text style={styles.retryText}>Coba Lagi</Text>
          </TouchableOpacity>
        </View>
      ) : filteredItems.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyText}>
            Tidak ada barang ditemukan
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredItems}
          keyExtractor={(item) => item.Id}
          renderItem={renderItem}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
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
  searchContainer: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  searchInput: {
    backgroundColor: COLORS.Surface,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: COLORS.TextPrimary,
    borderWidth: 1,
    borderColor: COLORS.Border,
  },
  categoryContainer: {
    paddingBottom: 8,
  },
  categoryScroll: {
    paddingHorizontal: 16,
    gap: 8,
  },
  categoryChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: COLORS.Surface,
    borderWidth: 1,
    borderColor: COLORS.Border,
  },
  categoryChipActive: {
    backgroundColor: COLORS.Primary,
    borderColor: COLORS.Primary,
  },
  categoryChipText: {
    fontSize: 14,
    color: COLORS.TextSecondary,
    fontWeight: "500",
  },
  categoryChipTextActive: {
    color: COLORS.Surface,
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
    marginBottom: 12,
  },
  retryText: {
    fontSize: 16,
    color: COLORS.Primary,
    fontWeight: "600",
  },
  emptyText: {
    fontSize: 16,
    color: COLORS.TextSecondary,
    textAlign: "center",
  },
  listContent: {
    padding: 16,
  },
});
