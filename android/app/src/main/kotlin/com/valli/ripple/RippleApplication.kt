package com.valli.ripple

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class RippleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
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
