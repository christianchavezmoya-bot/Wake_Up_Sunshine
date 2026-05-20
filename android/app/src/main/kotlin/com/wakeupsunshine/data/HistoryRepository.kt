package com.wakeupsunshine.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL
import java.net.HttpURLConnection

@Serializable
data class HistoryItem(
    val id: String,
    val direction: String,           // "sent" | "received"
    val otherUserName: String = "",
    val otherUserEmail: String = "",
    val avatarColor: String = "#FF6B35",
    val alarmSoundId: String? = null,
    val message: String? = null,
    val status: String = "pending",
    val responseAction: String? = null,
    val responseMessage: String? = null,
    val respondedAt: String? = null,
    val snoozeUntil: String? = null,
    val sentAt: String? = null,
    val createdAt: String = ""
)

@Serializable
data class HistoryResponse(
    val success: Boolean = false,
    val history: List<HistoryItem> = emptyList(),
    val page: Int = 1,
    val limit: Int = 50,
    val error: String? = null
)

object HistoryRefreshSignal {
    private val _signal = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val signal: SharedFlow<Unit> = _signal
    fun emit() { _signal.tryEmit(Unit) }
}

object HistoryRepository {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun getHistory(page: Int = 1, limit: Int = 50): HistoryResponse = withContext(Dispatchers.IO) {
        val token = SupabaseClient.getValidSession()?.accessToken
            ?: return@withContext HistoryResponse(success = false, error = "Not authenticated")
        val url = URL("${SupabaseClient.SUPABASE_URL}/functions/v1/get-history?page=$page&limit=$limit")
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.setRequestProperty("apikey", SupabaseClient.SUPABASE_ANON_KEY)
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            if (conn.responseCode == 200) {
                val body = conn.inputStream.bufferedReader().readText()
                json.decodeFromString(HistoryResponse.serializer(), body)
            } else {
                val err = conn.errorStream?.bufferedReader()?.readText() ?: "HTTP ${conn.responseCode}"
                HistoryResponse(success = false, error = err)
            }
        } finally {
            conn.disconnect()
        }
    }
}
