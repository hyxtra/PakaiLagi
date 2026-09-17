import React from "react";
import {
  View,
  Text,
  Image,
  StyleSheet,
  Alert,
} from "react-native";
import { Button } from "../components";
import { useLogout } from "../hooks/useAuth";
import { useAuthStore } from "../store/authStore";
import { COLORS } from "../constants/colors";
import { formatDate } from "../utils/formatDate";

export default function ProfileScreen() {
  const profile = useAuthStore((state) => state.Profile);
  const logoutMutation = useLogout();

  function handleLogout() {
    Alert.alert("Keluar", "Apakah Anda yakin ingin keluar?", [
      { text: "Batal", style: "cancel" },
      {
        text: "Keluar",
        style: "destructive",
        onPress: () => logoutMutation.mutate(),
      },
    ]);
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Profil</Text>
      </View>

      <View style={styles.profileSection}>
        <View style={styles.avatarContainer}>
          {profile?.AvatarUrl ? (
            <Image
              source={{ uri: profile.AvatarUrl }}
              style={styles.avatar}
            />
          ) : (
            <View style={styles.avatarPlaceholder}>
              <Text style={styles.avatarInitial}>
                {profile?.FullName?.charAt(0)?.toUpperCase() ?? "?"}
              </Text>
            </View>
          )}
        </View>

        <Text style={styles.fullName}>
          {profile?.FullName ?? "-"}
        </Text>

        <View style={styles.infoCard}>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Nomor Telepon</Text>
            <Text style={styles.infoValue}>
              {profile?.PhoneNumber ?? "Belum diatur"}
            </Text>
          </View>
          <View style={styles.divider} />
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Bergabung Sejak</Text>
            <Text style={styles.infoValue}>
              {profile?.CreatedAt
                ? formatDate(profile.CreatedAt)
                : "-"}
            </Text>
          </View>
        </View>
      </View>

      <View style={styles.footer}>
        <Button
          Title="Keluar"
          OnPress={handleLogout}
          Variant="outline"
          IsLoading={logoutMutation.isPending}
        />
      </View>
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
  profileSection: {
    alignItems: "center",
    paddingTop: 32,
    paddingHorizontal: 24,
  },
  avatarContainer: {
    marginBottom: 16,
  },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  avatarPlaceholder: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: COLORS.Primary,
    justifyContent: "center",
    alignItems: "center",
  },
  avatarInitial: {
    fontSize: 40,
    fontWeight: "700",
    color: COLORS.Surface,
  },
  fullName: {
    fontSize: 22,
    fontWeight: "700",
    color: COLORS.TextPrimary,
    marginBottom: 24,
  },
  infoCard: {
    width: "100%",
    backgroundColor: COLORS.Surface,
    borderRadius: 16,
    padding: 20,
    elevation: 1,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
  },
  infoRow: {
    paddingVertical: 8,
  },
  infoLabel: {
    fontSize: 13,
    color: COLORS.TextMuted,
    marginBottom: 4,
  },
  infoValue: {
    fontSize: 16,
    color: COLORS.TextPrimary,
    fontWeight: "500",
  },
  divider: {
    height: 1,
    backgroundColor: COLORS.Border,
    marginVertical: 4,
  },
  footer: {
    padding: 24,
    marginTop: "auto",
  },
});
