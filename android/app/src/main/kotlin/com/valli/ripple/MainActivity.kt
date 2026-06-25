package com.valli.ripple

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.valli.ripple/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "changeIcon") {
                val iconName = call.argument<String>("iconName")
                if (iconName != null) {
                    changeAppIcon(iconName)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "iconName is null", null)
                }
            } else if (call.method == "getCurrentIcon") {
                result.success(getCurrentActiveIcon())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun changeAppIcon(iconName: String) {
        val pm = packageManager
        val packageName = packageName
        
        // Only toggle aliases — NEVER disable MainActivity itself
        // MainActivity must always stay enabled for flutter run/debug to work
        val aliases = listOf("Abyss", "Gold", "Glitch")
        
        if (iconName.equals("Default", ignoreCase = true)) {
            // Default icon: disable all aliases, MainActivity uses its manifest icon
            for (alias in aliases) {
                val componentName = ComponentName(packageName, "$packageName.MainActivity$alias")
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } else {
            // Custom icon: enable the matching alias, disable the rest
            for (alias in aliases) {
                val componentName = ComponentName(packageName, "$packageName.MainActivity$alias")
                val state = if (alias.equals(iconName, ignoreCase = true)) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                pm.setComponentEnabledSetting(
                    componentName,
                    state,
                    PackageManager.DONT_KILL_APP
                )
            }
        }
    }

    private fun getCurrentActiveIcon(): String {
        val pm = packageManager
        val packageName = packageName
        
        val icons = listOf("Abyss", "Gold", "Glitch")
        for (icon in icons) {
            val componentName = ComponentName(packageName, "$packageName.MainActivity$icon")
            val state = pm.getComponentEnabledSetting(componentName)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return icon
            }
        }
        return "Default"
    }
}
