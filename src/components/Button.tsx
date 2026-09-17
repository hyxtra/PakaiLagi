import React from "react";
import {
  TouchableOpacity,
  Text,
  ActivityIndicator,
  StyleSheet,
  ViewStyle,
  TextStyle,
} from "react-native";
import { COLORS } from "../constants/colors";

interface ButtonProps {
  Title: string;
  OnPress: () => void;
  Variant?: "primary" | "secondary" | "outline";
  IsLoading?: boolean;
  Disabled?: boolean;
  Style?: ViewStyle;
}

export default function Button({
  Title,
  OnPress,
  Variant = "primary",
  IsLoading = false,
  Disabled = false,
  Style,
}: ButtonProps) {
  const isDisabled = Disabled || IsLoading;

  const buttonStyle: ViewStyle[] = [
    styles.base,
    Variant === "primary" && styles.primary,
    Variant === "secondary" && styles.secondary,
    Variant === "outline" && styles.outline,
    isDisabled && styles.disabled,
    Style as ViewStyle,
  ].filter(Boolean) as ViewStyle[];

  const textStyle: TextStyle[] = [
    styles.text,
    Variant === "outline" && styles.outlineText,
    isDisabled && styles.disabledText,
  ].filter(Boolean) as TextStyle[];

  return (
    <TouchableOpacity
      style={buttonStyle}
      onPress={OnPress}
      disabled={isDisabled}
      activeOpacity={0.7}
    >
      {IsLoading ? (
        <ActivityIndicator
          color={Variant === "outline" ? COLORS.Primary : COLORS.Surface}
          size="small"
        />
      ) : (
        <Text style={textStyle}>{Title}</Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  base: {
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
    minHeight: 50,
  },
  primary: {
    backgroundColor: COLORS.Primary,
  },
  secondary: {
    backgroundColor: COLORS.Secondary,
  },
  outline: {
    backgroundColor: "transparent",
    borderWidth: 1.5,
    borderColor: COLORS.Primary,
  },
  disabled: {
    opacity: 0.5,
  },
  text: {
    color: COLORS.Surface,
    fontSize: 16,
    fontWeight: "600",
  },
  outlineText: {
    color: COLORS.Primary,
  },
  disabledText: {
    color: COLORS.TextMuted,
  },
});
