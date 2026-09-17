import React, { useState } from "react";
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from "react-native";
import { Button } from "../components";
import { useCreateRequest } from "../hooks/useRequests";
import { DeliveryMethod } from "../types";
import { ERROR_MESSAGES } from "../constants/errorMessages";
import { COLORS } from "../constants/colors";

interface RequestModalProps {
  Visible: boolean;
  ItemId: string;
  OnClose: () => void;
  OnSuccess: () => void;
}

const DELIVERY_OPTIONS: {
  Value: DeliveryMethod;
  Label: string;
  Description: string;
}[] = [
  {
    Value: DeliveryMethod.AMBIL_LANGSUNG,
    Label: "Ambil Langsung",
    Description: "Saya akan mengambil barang di lokasi pemilik",
  },
  {
    Value: DeliveryMethod.BERTEMU,
    Label: "Bertemu",
    Description: "Bertemu di titik yang disepakati bersama",
  },
  {
    Value: DeliveryMethod.KURIR,
    Label: "Kurir",
    Description: "Kirim melalui jasa pengiriman",
  },
];

export default function RequestModal({
  Visible,
  ItemId,
  OnClose,
  OnSuccess,
}: RequestModalProps) {
  const [selectedMethod, setSelectedMethod] =
    useState<DeliveryMethod | null>(null);

  const createRequestMutation = useCreateRequest();

  function handleConfirm() {
    if (!selectedMethod) {
      Alert.alert("Perhatian", ERROR_MESSAGES.DeliveryMethodRequired);
      return;
    }

    createRequestMutation.mutate(
      { itemId: ItemId, deliveryMethod: selectedMethod },
      {
        onSuccess: () => {
          Alert.alert("Berhasil", "Pengajuan berhasil dikirim!");
          setSelectedMethod(null);
          OnSuccess();
        },
        onError: () => {
          Alert.alert("Gagal", ERROR_MESSAGES.CreateRequestFailed);
        },
      }
    );
  }

  function handleClose() {
    setSelectedMethod(null);
    OnClose();
  }

  return (
    <Modal
      visible={Visible}
      animationType="slide"
      transparent
      onRequestClose={handleClose}
    >
      <View style={styles.overlay}>
        <View style={styles.modal}>
          <Text style={styles.title}>Metode Pengambilan</Text>
          <Text style={styles.subtitle}>
            Pilih cara Anda ingin mengambil barang ini
          </Text>

          {DELIVERY_OPTIONS.map((option) => (
            <TouchableOpacity
              key={option.Value}
              style={[
                styles.option,
                selectedMethod === option.Value &&
                  styles.optionSelected,
              ]}
              onPress={() => setSelectedMethod(option.Value)}
            >
              <View style={styles.radio}>
                {selectedMethod === option.Value ? (
                  <View style={styles.radioFilled} />
                ) : null}
              </View>
              <View style={styles.optionContent}>
                <Text style={styles.optionLabel}>
                  {option.Label}
                </Text>
                <Text style={styles.optionDescription}>
                  {option.Description}
                </Text>
              </View>
            </TouchableOpacity>
          ))}

          <View style={styles.actions}>
            <Button
              Title="Konfirmasi"
              OnPress={handleConfirm}
              IsLoading={createRequestMutation.isPending}
              Disabled={!selectedMethod}
            />
            <Button
              Title="Batal"
              OnPress={handleClose}
              Variant="outline"
              Style={{ marginTop: 10 }}
            />
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: COLORS.Overlay,
    justifyContent: "flex-end",
  },
  modal: {
    backgroundColor: COLORS.Surface,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 24,
    paddingBottom: 36,
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
    color: COLORS.TextPrimary,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: COLORS.TextSecondary,
    marginBottom: 20,
  },
  option: {
    flexDirection: "row",
    alignItems: "center",
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.Border,
    marginBottom: 10,
  },
  optionSelected: {
    borderColor: COLORS.Primary,
    backgroundColor: COLORS.Primary + "08",
  },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: COLORS.Border,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 14,
  },
  radioFilled: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: COLORS.Primary,
  },
  optionContent: {
    flex: 1,
  },
  optionLabel: {
    fontSize: 16,
    fontWeight: "600",
    color: COLORS.TextPrimary,
    marginBottom: 2,
  },
  optionDescription: {
    fontSize: 13,
    color: COLORS.TextSecondary,
  },
  actions: {
    marginTop: 16,
  },
});
