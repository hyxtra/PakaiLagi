import React from "react";
import {
  TouchableOpacity,
  Image,
  Text,
  View,
  StyleSheet,
} from "react-native";
import { Item } from "../types";
import { COLORS } from "../constants/colors";

interface CardProps {
  Item: Item;
  OnPress: () => void;
}

export default function Card({ Item: item, OnPress }: CardProps) {
  return (
    <TouchableOpacity
      style={styles.container}
      onPress={OnPress}
      activeOpacity={0.8}
    >
      <Image
        source={{ uri: item.ImageUrl }}
        style={styles.image}
        resizeMode="cover"
      />
      <View style={styles.content}>
        <Text style={styles.title} numberOfLines={1}>
          {item.Title}
        </Text>
        <View style={styles.categoryBadge}>
          <Text style={styles.categoryText}>{item.Category}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.Surface,
    borderRadius: 16,
    overflow: "hidden",
    marginBottom: 12,
    elevation: 2,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  image: {
    width: "100%",
    height: 180,
  },
  content: {
    padding: 12,
  },
  title: {
    fontSize: 16,
    fontWeight: "600",
    color: COLORS.TextPrimary,
    marginBottom: 6,
  },
  categoryBadge: {
    alignSelf: "flex-start",
    backgroundColor: COLORS.Primary + "15",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
  },
  categoryText: {
    fontSize: 12,
    color: COLORS.Primary,
    fontWeight: "500",
  },
});
