# Contact Invite Flow

## Current Behavior (In-App Pending Invite Only)

When a user creates an invite:

1. **Backend creates a pending invite record** in the `contact_invites` table
2. **No email is sent** - the invite is stored in the database only
3. **The invited person sees the invite** when they log in with the matching email address
4. **Success message shown**: "Invite created. The person will see it when they log in with this email."

### How Invites Work

1. User A enters User B's email address
2. Backend creates: `contact_invites` record with status `pending`
3. User B logs into the app with that email
4. User B sees the pending invite in their Contacts screen
5. User B accepts or declines the invite
6. If accepted, both users can now wake each other

### Share Options

After creating an invite, users can share via:
- **Share Link** - Opens native share sheet with invite link
- **QR Code** - Generates scannable QR code with invite link

These are for manual sharing (iMessage, WhatsApp, etc.) - no automatic email is sent.

---

## Future Behavior (Real Email Delivery)

To implement real email delivery, an email provider must be configured.

### Required Setup

1. **Choose an email provider:**
   - [Resend](https://resend.com) (Recommended - generous free tier)
   - [SendGrid](https://sendgrid.com)
   - [Mailgun](https://mailgun.com)
   - [Postmark](https://postmarkapp.com)

2. **Store API key in Supabase secrets:**
   ```bash
   supabase secrets set EMAIL_PROVIDER=resend
   supabase secrets set RESEND_API_KEY=re_xxxxx
   ```

3. **Create Edge Function `send-invite-email`:**
   ```typescript
   // backend/supabase/functions/send-invite-email/index.ts
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
   
   serve(async (req) => {
     const { inviteeEmail, inviterName, inviteLink } = await req.json()
     
     const response = await fetch("https://api.resend.com/emails", {
       method: "POST",
       headers: {
         "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
         "Content-Type": "application/json",
       },
       body: JSON.stringify({
         from: "Wake Up Sunshine <noreply@wakeupsunshine.app>",
         to: inviteeEmail,
         subject: `${inviterName} wants to wake you up!`,
         html: `
           <h1>You've been invited!</h1>
           <p>${inviterName} wants to be able to send you wake alerts.</p>
           <a href="${inviteLink}">Accept Invite</a>
         `,
       }),
     })
     
     return new Response(JSON.stringify({ success: response.ok }))
   })
   ```

4. **Update `create-invite` function** to call `send-invite-email` after creating the invite

5. **Update success message** to: "Email invite sent to {email}"

### Implementation Checklist

- [ ] Sign up for Resend/SendGrid account
- [ ] Verify domain (for deliverability)
- [ ] Add API key to Supabase secrets
- [ ] Create `send-invite-email` Edge Function
- [ ] Update `create-invite` to trigger email
- [ ] Update UI success message
- [ ] Add email template with branding
- [ ] Test email delivery
- [ ] Handle bounces and unsubscribes

---

## UI Messaging

### Current (No Email Provider)
- Button: "Create Invite"
- Success: "Invite created. The person will see it when they log in with this email."
- Pending status: "Pending — waiting for user to accept in the app"

### After Email Provider Setup
- Button: "Send Invite"
- Success: "Email invite sent to {email}"
- Pending status: "Pending — waiting for response"

---

## Database Schema

```sql
contact_invites (
  id UUID PRIMARY KEY,
  inviter_id UUID REFERENCES auth.users,
  invitee_email TEXT,
  invite_token TEXT UNIQUE,
  status TEXT DEFAULT 'pending', -- pending, accepted, declined
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
)
```

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `create-invite` | Creates pending invite record |
| `accept-invite` | Accepts invite, creates contact relationship |
| `decline-invite` | Declines invite |
| `get-contacts` | Returns contacts and pending invites |
| `send-invite-email` | (Future) Sends email notification |