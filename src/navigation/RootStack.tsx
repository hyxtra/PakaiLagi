import React from "react";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { RootStackParamList } from "./types";
import TabNavigator from "./TabNavigator";
import { useAuthStore } from "../store/authStore";
import { COLORS } from "../constants/colors";
import LoginScreen from "../screens/LoginScreen";
import RegisterScreen from "../screens/RegisterScreen";
import ItemDetailScreen from "../screens/ItemDetailScreen";
import ManageRequestScreen from "../screens/ManageRequestScreen";

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootStack() {
  const session = useAuthStore((state) => state.Session);
  const isLoading = useAuthStore((state) => state.IsLoading);

  if (isLoading) {
    return null;
  }

  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: COLORS.Primary },
        headerTintColor: COLORS.Surface,
        headerTitleStyle: { fontWeight: "600" },
        contentStyle: { backgroundColor: COLORS.Background },
      }}
    >
      {session ? (
        <>
          <Stack.Screen
            name="MainTabs"
            component={TabNavigator}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="ItemDetail"
            component={ItemDetailScreen}
            options={{ title: "Detail Barang" }}
          />
          <Stack.Screen
            name="ManageRequest"
            component={ManageRequestScreen}
            options={{ title: "Kelola Pengajuan" }}
          />
        </>
      ) : (
        <>
          <Stack.Screen
            name="Login"
            component={LoginScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="Register"
            component={RegisterScreen}
            options={{ headerShown: false }}
          />
        </>
      )}
    </Stack.Navigator>
  );
}
