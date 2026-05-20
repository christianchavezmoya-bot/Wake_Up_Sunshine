package com.wakeupsunshine.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL
import java.net.HttpURLConnection

@Serializable
data class CreateInviteRequest(
    val inviteeEmail: String,
    val inviteeLabel: String? = null,
    val message: String? = null
)

@Serializable
data class CreateInviteResponse(
    val success: Boolean = false,
    val inviteId: String? = null,
    val inviteeEmail: String? = null,
    val inviteeLabel: String? = null,
    val status: String? = null,
    val message: String? = null,
    val inviteToken: String? = null,
    val inviteLink: String? = null,
    val httpsLink: String? = null,
    val qrPayload: String? = null,
    val error: String? = null
)

@Serializable
data class AcceptInviteRequest(
    val inviteId: String,
    val inviteToken: String? = null
)

@Serializable
data class AcceptInviteResponse(
    val success: Boolean,
    val status: String? = null,
    val inviteId: String? = null,
    val inviterId: String? = null,
    val message: String? = null,
    val error: String? = null,
    val debugCode: String? = null
)

@Serializable
data class DeclineInviteRequest(
    val inviteId: String,
    val inviteToken: String? = null
)

@Serializable
data class DeclineInviteResponse(
    val success: Boolean,
    val status: String? = null,
    val inviteId: String? = null,
    val message: String? = null,
    val error: String? = null
)

@Serializable
data class SentInvite(
    val id: String,
    val invitee_email: String,
    val status: String,
    val created_at: String,
    val expires_at: String
)

@Serializable
data class ReceivedInvite(
    val id: String,
    val inviter_id: String,
    val inviter_name: String,
    val invite_token: String,
    val message: String? = null,
    val created_at: String
)

@Serializable
data class GetInvitesResponse(
    val success: Boolean,
    val sent: List<SentInvite>? = null,
    val received: List<ReceivedInvite>? = null,
    val error: String? = null
)

// MARK: - Contacts Response (New Standard Shape)
@Serializable
data class ContactItem(
    val id: String,
    val userId: String? = null,
    val email: String = "",
    val displayName: String = "",
    val status: String = "active"
)

@Serializable
data class InviteItem(
    val id: String,
    val inviteeEmail: String? = null,
    val inviteeLabel: String? = null,
    val inviterEmail: String? = null,
    val inviterName: String? = null,
    val inviterId: String? = null,
    val status: String = "pending",
    val createdAt: String = "",
    val inviteToken: String? = null,
    val message: String? = null
)

@Serializable
data class ContactsResponse(
    val success: Boolean = false,
    val peopleICanWake: List<ContactItem> = emptyList(),
    val peopleWhoCanWakeMe: List<ContactItem> = emptyList(),
    val blockedContacts: List<ContactItem> = emptyList(),
    val pendingInvitesSent: List<InviteItem> = emptyList(),
    val pendingInvitesReceived: List<InviteItem> = emptyList(),
    val error: String? = null,
    val message: String? = null
)

object InviteRepository {
    private const val BASE_URL = SupabaseClient.SUPABASE_URL
    private const val ANON_KEY = SupabaseClient.SUPABASE_ANON_KEY
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    
    private suspend fun getAccessToken(): String? = SupabaseClient.getValidSession()?.accessToken
    
    suspend fun createInvite(
        email: String,
        inviteeLabel: String? = null,
        message: String? = null
    ): CreateInviteResponse = withContext(Dispatchers.IO) {
        val url = URL("$BASE_URL/functions/v1/create-invite")
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", ANON_KEY)
            getAccessToken()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            connection.doOutput = true
            
            val requestBody = json.encodeToString(
                CreateInviteRequest.serializer(),
                CreateInviteRequest(email, inviteeLabel, message)
            )
            
            connection.outputStream.use { os ->
                os.write(requestBody.toByteArray(Charsets.UTF_8))
            }
            
            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().readText()
            } else {
                connection.errorStream?.bufferedReader()?.readText() ?: "{}"
            }
            
            DebugLogger.debug("InviteRepository", "Create invite response: $responseBody")
            
            json.decodeFromString(CreateInviteResponse.serializer(), responseBody)
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Create invite error", e)
            CreateInviteResponse(success = false, error = e.message ?: "Network error")
        } finally {
            connection.disconnect()
        }
    }
    
    // Accepts an invite using only a token (from share-link / QR deep link).
    // inviteId is intentionally empty — falsy in JS so the backend uses the token.
    suspend fun acceptInviteByToken(token: String): AcceptInviteResponse =
        acceptInvite(inviteId = "", inviteToken = token)

    suspend fun acceptInvite(inviteId: String, inviteToken: String? = null): AcceptInviteResponse = withContext(Dispatchers.IO) {
        val url = URL("$BASE_URL/functions/v1/accept-invite")
        val connection = url.openConnection() as HttpURLConnection

        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", ANON_KEY)
            getAccessToken()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            connection.doOutput = true

            val requestBody = json.encodeToString(
                AcceptInviteRequest.serializer(),
                AcceptInviteRequest(inviteId = inviteId, inviteToken = inviteToken)
            )
            DebugLogger.debug("InviteRepository", "Accept invite request: $requestBody")

            connection.outputStream.use { os -> os.write(requestBody.toByteArray(Charsets.UTF_8)) }

            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().readText()
            } else {
                connection.errorStream?.bufferedReader()?.readText() ?: "{}"
            }
            DebugLogger.debug("InviteRepository", "Accept invite response ($responseCode): $responseBody")

            json.decodeFromString(AcceptInviteResponse.serializer(), responseBody)
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Accept invite error", e)
            AcceptInviteResponse(success = false, error = e.message ?: "Network error")
        } finally {
            connection.disconnect()
        }
    }

    suspend fun declineInvite(inviteId: String, inviteToken: String? = null): DeclineInviteResponse = withContext(Dispatchers.IO) {
        val url = URL("$BASE_URL/functions/v1/decline-invite")
        val connection = url.openConnection() as HttpURLConnection

        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", ANON_KEY)
            getAccessToken()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            connection.doOutput = true

            val requestBody = json.encodeToString(
                DeclineInviteRequest.serializer(),
                DeclineInviteRequest(inviteId = inviteId, inviteToken = inviteToken)
            )
            DebugLogger.debug("InviteRepository", "Decline invite request: $requestBody")

            connection.outputStream.use { os -> os.write(requestBody.toByteArray(Charsets.UTF_8)) }

            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().readText()
            } else {
                connection.errorStream?.bufferedReader()?.readText() ?: "{}"
            }
            DebugLogger.debug("InviteRepository", "Decline invite response ($responseCode): $responseBody")

            json.decodeFromString(DeclineInviteResponse.serializer(), responseBody)
        } catch (e: Exception) {
            DeclineInviteResponse(success = false, error = e.message ?: "Network error")
        } finally {
            connection.disconnect()
        }
    }
    
    suspend fun getInvites(type: String = "all"): GetInvitesResponse = withContext(Dispatchers.IO) {
        val url = URL("$BASE_URL/functions/v1/get-invites?type=$type")
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            connection.requestMethod = "GET"
            connection.setRequestProperty("apikey", ANON_KEY)
            getAccessToken()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            
            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().readText()
            } else {
                connection.errorStream?.bufferedReader()?.readText() ?: "{}"
            }
            
            json.decodeFromString(GetInvitesResponse.serializer(), responseBody)
        } catch (e: Exception) {
            GetInvitesResponse(success = false, error = e.message ?: "Network error")
        } finally {
            connection.disconnect()
        }
    }
    
    // Deletes the wake_permission between me and them.
    // iAmGranter=true  → I granted them permission (I can always delete via RLS)
    // iAmGranter=false → They granted me permission (RLS may block; best-effort)
    suspend fun removeContact(myId: String, theirId: String, iAmGranter: Boolean): Boolean = withContext(Dispatchers.IO) {
        val token = getAccessToken() ?: return@withContext false
        val granterId = if (iAmGranter) myId else theirId
        val trusteeId = if (iAmGranter) theirId else myId
        val url = URL("$BASE_URL/rest/v1/wake_permissions?granter_id=eq.$granterId&trustee_id=eq.$trusteeId")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "DELETE"
            connection.setRequestProperty("apikey", ANON_KEY)
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Prefer", "return=minimal")
            val code = connection.responseCode
            DebugLogger.debug("InviteRepository", "removeContact response: $code")
            code in 200..299
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Remove contact error", e)
            false
        } finally {
            connection.disconnect()
        }
    }

    // Sets contact_invites.status = 'cancelled' for a sent invite I own.
    suspend fun cancelSentInvite(inviteId: String, myId: String): Boolean = withContext(Dispatchers.IO) {
        val token = getAccessToken() ?: return@withContext false
        val url = URL("$BASE_URL/rest/v1/contact_invites?id=eq.$inviteId&inviter_id=eq.$myId")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "PATCH"
            connection.setRequestProperty("apikey", ANON_KEY)
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            connection.doOutput = true
            connection.outputStream.use { it.write("""{"status":"cancelled"}""".toByteArray()) }
            val code = connection.responseCode
            DebugLogger.debug("InviteRepository", "cancelSentInvite response: $code")
            code in 200..299
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Cancel invite error", e)
            false
        } finally {
            connection.disconnect()
        }
    }

    suspend fun updateWakePermissionStatus(myId: String, theirId: String, status: String): Boolean = withContext(Dispatchers.IO) {
        val token = getAccessToken() ?: return@withContext false
        val url = URL("$BASE_URL/rest/v1/wake_permissions?granter_id=eq.$myId&trustee_id=eq.$theirId")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "PATCH"
            connection.setRequestProperty("apikey", ANON_KEY)
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            connection.doOutput = true
            connection.outputStream.use { it.write("""{"status":"$status"}""".toByteArray()) }
            val code = connection.responseCode
            DebugLogger.debug("InviteRepository", "updateWakePermissionStatus($status) response: $code")
            code in 200..299
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Update wake permission status error", e)
            false
        } finally {
            connection.disconnect()
        }
    }

    // MARK: - Get Contacts (New Standard Shape)
    suspend fun getContacts(): ContactsResponse = withContext(Dispatchers.IO) {
        val url = URL("$BASE_URL/functions/v1/get-contacts")
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            connection.requestMethod = "GET"
            connection.setRequestProperty("apikey", ANON_KEY)
            getAccessToken()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            
            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().readText()
            } else {
                connection.errorStream?.bufferedReader()?.readText() ?: "{}"
            }
            
            DebugLogger.debug("InviteRepository", "Get contacts response: $responseBody")
            
            json.decodeFromString(ContactsResponse.serializer(), responseBody)
        } catch (e: Exception) {
            android.util.Log.e("InviteRepository", "Get contacts error", e)
            ContactsResponse(success = false, error = e.message ?: "Network error")
        } finally {
            connection.disconnect()
        }
    }
}
