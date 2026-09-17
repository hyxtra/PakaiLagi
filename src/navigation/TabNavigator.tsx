import React from "react";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { TabParamList } from "./types";
import { COLORS } from "../constants/colors";
import HomeScreen from "../screens/HomeScreen";
import PostItemScreen from "../screens/PostItemScreen";
import ActivityScreen from "../screens/ActivityScreen";
import ProfileScreen from "../screens/ProfileScreen";

const Tab = createBottomTabNavigator<TabParamList>();

export default function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: COLORS.Primary,
        tabBarInactiveTintColor: COLORS.TextMuted,
        tabBarStyle: {
          backgroundColor: COLORS.Surface,
          borderTopColor: COLORS.Border,
        },
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{ tabBarLabel: "Beranda" }}
      />
      <Tab.Screen
        name="PostItem"
        component={PostItemScreen}
        options={{ tabBarLabel: "Bagikan" }}
      />
      <Tab.Screen
        name="Activity"
        component={ActivityScreen}
        options={{ tabBarLabel: "Aktivitas" }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{ tabBarLabel: "Profil" }}
      />
    </Tab.Navigator>
  );
}
