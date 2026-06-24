package com.bata.localllm.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.bata.localllm.ui.chat.ChatScreen
import com.bata.localllm.ui.models.ModelsScreen
import com.bata.localllm.ui.settings.SettingsScreen

private const val ROUTE_CHAT     = "chat"
private const val ROUTE_MODELS   = "models"
private const val ROUTE_SETTINGS = "settings"

@Composable
fun AppNavigation() {
    val nav = rememberNavController()

    NavHost(navController = nav, startDestination = ROUTE_CHAT) {
        composable(ROUTE_CHAT) {
            ChatScreen(onOpenModels = { nav.navigate(ROUTE_MODELS) })
        }
        composable(ROUTE_MODELS) {
            ModelsScreen(onBack = { nav.popBackStack() })
        }
        composable(ROUTE_SETTINGS) {
            SettingsScreen(onBack = { nav.popBackStack() })
        }
    }
}
