package com.wakeupsunshine.data

import android.content.Context

object NicknameStore {
    private const val PREFS = "nicknames"

    fun get(context: Context, email: String): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("nick_$email", null)
            ?.takeIf { it.isNotBlank() }

    fun set(context: Context, email: String, nickname: String?) {
        val trimmed = nickname?.trim()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (trimmed.isNullOrBlank()) prefs.remove("nick_$email") else prefs.putString("nick_$email", trimmed)
        prefs.apply()
    }
}
