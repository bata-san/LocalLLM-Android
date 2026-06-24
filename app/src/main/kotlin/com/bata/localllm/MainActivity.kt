package com.bata.localllm

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.bata.localllm.navigation.AppNavigation
import com.bata.localllm.ui.theme.LocalLLMTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LocalLLMTheme {
                AppNavigation()
            }
        }
    }
}
