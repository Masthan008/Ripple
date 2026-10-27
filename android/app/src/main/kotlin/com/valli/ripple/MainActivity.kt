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
        val aliases = listOf("Default", "Abyss", "Gold", "Glitch", "Forest", "Sunset")
        val targetAlias = aliases.firstOrNull { it.equals(iconName, ignoreCase = true) } ?: "Default"

        // Step 1: Enable the target alias FIRST so there is never a moment without an active launcher
        val targetComponent = ComponentName(packageName, "$packageName.MainActivity$targetAlias")
        pm.setComponentEnabledSetting(
            targetComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        // Step 2: Disable all other aliases safely
        for (alias in aliases) {
            if (!alias.equals(targetAlias, ignoreCase = true)) {
                val componentName = ComponentName(packageName, "$packageName.MainActivity$alias")
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }
    }

    private fun getCurrentActiveIcon(): String {
        val pm = packageManager
        val packageName = packageName

        val icons = listOf("Abyss", "Gold", "Glitch", "Forest", "Sunset")
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
