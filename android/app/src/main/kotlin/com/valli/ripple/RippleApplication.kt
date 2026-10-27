package com.valli.ripple

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build

class RippleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ensureLauncherComponentEnabled()
        createNotificationChannels()
    }

    /**
     * Self-healing launcher check.
     * Ensures that if all aliases were disabled from a previous buggy update or state,
     * MainActivityDefault is guaranteed to be restored to ENABLED immediately.
     */
    private fun ensureLauncherComponentEnabled() {
        try {
            val pm = packageManager
            val packageName = packageName
            val aliases = listOf("Default", "Abyss", "Gold", "Glitch", "Forest", "Sunset")

            var hasEnabledLauncher = false
            for (alias in aliases) {
                val comp = ComponentName(packageName, "$packageName.MainActivity$alias")
                val state = pm.getComponentEnabledSetting(comp)
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    hasEnabledLauncher = true
                    break
                }
            }

            if (!hasEnabledLauncher) {
                val defaultComp = ComponentName(packageName, "$packageName.MainActivityDefault")
                pm.setComponentEnabledSetting(
                    defaultComp,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)

        val channels = listOf(
            NotificationChannel(
                "ripple_messages",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat messages from your friends"
            },
            NotificationChannel(
                "ripple_calls",
                "Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming call notifications"
                setShowBadge(true)
            },
            NotificationChannel(
                "ripple_groups",
                "Groups",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Group chat messages"
            },
            NotificationChannel(
                "ripple_social",
                "Social",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Friend requests and reactions"
            }
        )

        manager.createNotificationChannels(channels)
    }
}
