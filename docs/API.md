# API Documentation

## Base URL

```
https://your-project.supabase.co/functions/v1
```

## Authentication

All API requests require a Bearer token in the Authorization header:

```
Authorization: Bearer <supabase_auth_token>
```

## Endpoints

### Send Wake Alert

Send a wake alert to a trusted contact.

**POST** `/wake`

**Request Body:**
```json
{
  "targetUserId": "uuid-of-receiver",
  "message": "Wake up! Flight in 2 hours",
  "urgency": "normal"
}
```

**Response:**
```json
{
  "success": true,
  "requestId": "uuid-of-wake-request",
  "status": "delivered"
}
```

**Urgency Levels:**
- `low` - Non-urgent wake
- `normal` - Standard wake (default)
- `high` - Important wake
- `emergency` - Critical emergency

---

### Respond to Wake

Handle a wake alert response (confirm/dismiss/snooze).

**POST** `/wake-response`

**Request Body:**
```json
{
  "requestId": "uuid-of-wake-request",
  "action": "confirm"
}
```

**Actions:**
- `confirm` - User is awake
- `dismiss` - User dismissed the alarm
- `snooze` - User snoozed for 5 minutes

**Response:**
```json
{
  "success": true,
  "status": "confirmed"
}
```

---

### Get Contacts

Fetch trusted contacts (people who can wake you).

**GET** `/get-contacts?search=&page=1&limit=20`

**Query Parameters:**
- `search` - Optional search filter
- `page` - Page number (default: 1)
- `limit` - Items per page (default: 20)

**Response:**
```json
{
  "success": true,
  "contacts": [
    {
      "id": "permission-uuid",
      "userId": "user-uuid",
      "displayName": "Alex Chen",
      "avatarColor": "#667eea",
      "permissionStatus": "active",
      "isOnline": true
    }
  ],
  "page": 1,
  "limit": 20
}
```

---

### Get Wake History

Fetch wake history (sent wake alerts).

**GET** `/get-history?page=1&limit=50`

**Query Parameters:**
- `page` - Page number (default: 1)
- `limit` - Items per page (default: 50)

**Response:**
```json
{
  "success": true,
  "history": [
    {
      "id": "wake-request-uuid",
      "name": "Alex Chen",
      "avatarColor": "#667eea",
      "title": "Woke Alex Chen",
      "message": "Morning shift",
      "timestamp": "2024-01-15T06:30:00Z",
      "status": "confirmed",
      "isIncoming": false
    }
  ],
  "page": 1,
  "limit": 50
}
```

---

### Register Device

Register a device for push notifications.

**POST** `/devices/register`

**Request Body:**
```json
{
  "token": "apns-device-token",
  "deviceType": "iphone",
  "isPrimary": true
}
```

**Device Types:**
- `iphone`
- `ipad`
- `watch`

---

### Send Permission Request

Request permission to wake another user.

**POST** `/permissions`

**Request Body:**
```json
{
  "trusteeId": "user-uuid-to-request"
}
```

**Response:**
```json
{
  "success": true,
  "permissionId": "permission-uuid",
  "status": "pending"
}
```

---

### Approve Permission

Approve a pending permission request.

**PATCH** `/permissions/:id`

**Request Body:**
```json
{
  "status": "active"
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "error": "Error message here"
}
```

**Common Error Codes:**
- `400` - Bad Request (missing parameters)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (permission denied)
- `404` - Not Found
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

## Rate Limits

- **Wake Requests:** 10 per day per contact
- **Cooldown:** 30 minutes between wake requests to same contact
- **Blocked:** After exceeding limits

## Push Notification Payload

```json
{
  "aps": {
    "alert": {
      "title": "Wake Up!",
      "body": "Alex Chen wants to wake you"
    },
    "sound": "critical_alert.caf",
    "interruption-level": "critical",
    "category": "WAKE_ALERT"
  },
  "requestId": "uuid",
  "senderName": "Alex Chen",
  "message": "Morning shift in 30 minutes",
  "urgency": "normal"
}
```

## Webhooks

Coming soon for real-time status updates.