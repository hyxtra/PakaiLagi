import React from "react";
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TextInputProps,
} from "react-native";
import { COLORS } from "../constants/colors";

interface InputFieldProps extends TextInputProps {
  Label: string;
  ErrorMessage?: string;
}

export default function InputField({
  Label,
  ErrorMessage,
  ...rest
}: InputFieldProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.label}>{Label}</Text>
      <TextInput
        style={[
          styles.input,
          ErrorMessage ? styles.inputError : null,
        ]}
        placeholderTextColor={COLORS.TextMuted}
        {...rest}
      />
      {ErrorMessage ? (
        <Text style={styles.error}>{ErrorMessage}</Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: 16,
  },
  label: {
    fontSize: 14,
    fontWeight: "500",
    color: COLORS.TextPrimary,
    marginBottom: 6,
  },
  input: {
    backgroundColor: COLORS.Surface,
    borderWidth: 1,
    borderColor: COLORS.Border,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: COLORS.TextPrimary,
  },
  inputError: {
    borderColor: COLORS.Error,
  },
  error: {
    fontSize: 12,
    color: COLORS.Error,
    marginTop: 4,
  },
});
