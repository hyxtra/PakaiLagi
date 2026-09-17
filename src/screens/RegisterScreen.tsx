import React, { useState } from "react";
import {
  View,
  Text,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Alert,
} from "react-native";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "../navigation/types";
import { Button, InputField } from "../components";
import { useRegister } from "../hooks/useAuth";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { COLORS } from "../constants/colors";

type Props = NativeStackScreenProps<RootStackParamList, "Register">;

export default function RegisterScreen({ navigation }: Props) {
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<{
    FullName?: string;
    Email?: string;
    Password?: string;
  }>({});

  const registerMutation = useRegister();

  function validate(): boolean {
    const newErrors: {
      FullName?: string;
      Email?: string;
      Password?: string;
    } = {};

    if (!fullName.trim()) {
      newErrors.FullName = ERROR_MESSAGES.FullNameRequired;
    }
    if (!email.trim()) {
      newErrors.Email = ERROR_MESSAGES.EmailRequired;
    }
    if (!password) {
      newErrors.Password = ERROR_MESSAGES.PasswordRequired;
    } else if (password.length < 6) {
      newErrors.Password = ERROR_MESSAGES.PasswordTooShort;
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  function handleRegister() {
    if (!validate()) return;

    registerMutation.mutate(
      {
        email: email.trim(),
        password,
        fullName: fullName.trim(),
      },
      {
        onError: () => {
          Alert.alert("Gagal Daftar", ERROR_MESSAGES.RegisterFailed);
        },
      }
    );
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : "height"}
    >
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={styles.appName}>PakaiLagi</Text>
          <Text style={styles.subtitle}>Buat akun baru</Text>
        </View>

        <View style={styles.form}>
          <InputField
            Label="Nama Lengkap"
            value={fullName}
            onChangeText={setFullName}
            placeholder="Masukkan nama lengkap"
            autoCapitalize="words"
            ErrorMessage={errors.FullName}
          />

          <InputField
            Label="Email"
            value={email}
            onChangeText={setEmail}
            placeholder="Masukkan email"
            keyboardType="email-address"
            autoCapitalize="none"
            ErrorMessage={errors.Email}
          />

          <InputField
            Label="Kata Sandi"
            value={password}
            onChangeText={setPassword}
            placeholder="Minimal 6 karakter"
            secureTextEntry
            ErrorMessage={errors.Password}
          />

          <Button
            Title="Daftar"
            OnPress={handleRegister}
            IsLoading={registerMutation.isPending}
          />
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Sudah punya akun? </Text>
          <Text
            style={styles.footerLink}
            onPress={() => navigation.goBack()}
          >
            Masuk
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.Background,
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: "center",
    padding: 24,
  },
  header: {
    alignItems: "center",
    marginBottom: 40,
  },
  appName: {
    fontSize: 36,
    fontWeight: "800",
    color: COLORS.Primary,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: COLORS.TextSecondary,
  },
  form: {
    marginBottom: 24,
  },
  footer: {
    flexDirection: "row",
    justifyContent: "center",
  },
  footerText: {
    fontSize: 14,
    color: COLORS.TextSecondary,
  },
  footerLink: {
    fontSize: 14,
    color: COLORS.Primary,
    fontWeight: "600",
  },
});
