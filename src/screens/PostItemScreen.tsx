import React, { useState } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  Image,
  StyleSheet,
  Alert,
} from "react-native";
import * as ImagePicker from "expo-image-picker";
import { Button, InputField } from "../components";
import { useCreateItem } from "../hooks/useItems";
import { CATEGORIES } from "../constants/categories";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { COLORS } from "../constants/colors";

export default function PostItemScreen() {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [errors, setErrors] = useState<{
    Title?: string;
    Description?: string;
    Category?: string;
    Image?: string;
  }>({});

  const createItemMutation = useCreateItem();

  async function handlePickImage() {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsEditing: true,
      aspect: [4, 3],
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setImageUri(result.assets[0].uri);
    }
  }

  function validate(): boolean {
    const newErrors: {
      Title?: string;
      Description?: string;
      Category?: string;
      Image?: string;
    } = {};

    if (!title.trim()) {
      newErrors.Title = ERROR_MESSAGES.TitleRequired;
    }
    if (!description.trim()) {
      newErrors.Description = ERROR_MESSAGES.DescriptionRequired;
    }
    if (!category) {
      newErrors.Category = ERROR_MESSAGES.CategoryRequired;
    }
    if (!imageUri) {
      newErrors.Image = ERROR_MESSAGES.ImageRequired;
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;

    createItemMutation.mutate(
      {
        dto: {
          Title: title.trim(),
          Description: description.trim(),
          Category: category,
          ImageUrl: "",
        },
        imageFile: {
          uri: imageUri!,
          type: "image/jpeg",
          name: `item_${Date.now()}.jpg`,
        },
      },
      {
        onSuccess: () => {
          Alert.alert("Berhasil", "Barang berhasil dibagikan!");
          setTitle("");
          setDescription("");
          setCategory("");
          setImageUri(null);
        },
        onError: () => {
          Alert.alert("Gagal", ERROR_MESSAGES.CreateItemFailed);
        },
      }
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Bagikan Barang</Text>
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <TouchableOpacity
          style={styles.imagePicker}
          onPress={handlePickImage}
        >
          {imageUri ? (
            <Image
              source={{ uri: imageUri }}
              style={styles.imagePreview}
            />
          ) : (
            <View style={styles.imagePlaceholder}>
              <Text style={styles.imagePlaceholderIcon}>📷</Text>
              <Text style={styles.imagePlaceholderText}>
                Tambahkan Foto
              </Text>
            </View>
          )}
        </TouchableOpacity>
        {errors.Image ? (
          <Text style={styles.imageError}>{errors.Image}</Text>
        ) : null}

        <InputField
          Label="Judul Barang"
          value={title}
          onChangeText={setTitle}
          placeholder="Contoh: Buku Pemrograman"
          ErrorMessage={errors.Title}
        />

        <Text style={styles.categoryLabel}>Kategori</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.categoryScroll}
        >
          {CATEGORIES.map((cat) => (
            <TouchableOpacity
              key={cat}
              style={[
                styles.categoryChip,
                category === cat && styles.categoryChipActive,
              ]}
              onPress={() => setCategory(cat)}
            >
              <Text
                style={[
                  styles.categoryChipText,
                  category === cat && styles.categoryChipTextActive,
                ]}
              >
                {cat}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
        {errors.Category ? (
          <Text style={styles.categoryError}>
            {errors.Category}
          </Text>
        ) : null}

        <InputField
          Label="Deskripsi"
          value={description}
          onChangeText={setDescription}
          placeholder="Jelaskan kondisi barang"
          multiline
          numberOfLines={4}
          textAlignVertical="top"
          ErrorMessage={errors.Description}
        />

        <Button
          Title="Bagikan Barang"
          OnPress={handleSubmit}
          IsLoading={createItemMutation.isPending}
          Style={{ marginTop: 8 }}
        />
      </ScrollView>
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
  scrollContent: {
    padding: 16,
  },
  imagePicker: {
    width: "100%",
    height: 200,
    borderRadius: 16,
    overflow: "hidden",
    marginBottom: 8,
    borderWidth: 1,
    borderColor: COLORS.Border,
    borderStyle: "dashed",
  },
  imagePreview: {
    width: "100%",
    height: "100%",
  },
  imagePlaceholder: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: COLORS.Surface,
  },
  imagePlaceholderIcon: {
    fontSize: 40,
    marginBottom: 8,
  },
  imagePlaceholderText: {
    fontSize: 16,
    color: COLORS.TextSecondary,
  },
  imageError: {
    fontSize: 12,
    color: COLORS.Error,
    marginBottom: 12,
  },
  categoryLabel: {
    fontSize: 14,
    fontWeight: "500",
    color: COLORS.TextPrimary,
    marginBottom: 6,
  },
  categoryScroll: {
    marginBottom: 4,
  },
  categoryChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: COLORS.Surface,
    borderWidth: 1,
    borderColor: COLORS.Border,
    marginRight: 8,
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
  categoryError: {
    fontSize: 12,
    color: COLORS.Error,
    marginTop: 4,
    marginBottom: 12,
  },
});
