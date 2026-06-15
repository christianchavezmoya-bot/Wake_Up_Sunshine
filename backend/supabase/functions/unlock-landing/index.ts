import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Landing page HTML template
function getLandingPage(inviteCode: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wake Me Up - You're Invited!</title>
    <meta name="description" content="You've been invited to Wake Me Up! Download the app and get free lifetime access.">
    
    <!-- Open Graph -->
    <meta property="og:title" content="Wake Me Up - You're Invited!">
    <meta property="og:description" content="You've been invited to Wake Me Up! Download the app and get free lifetime access.">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://wakeupsunshine.app/invite/${inviteCode}">
    
    <!-- iOS Smart App Banner -->
    <meta name="apple-itunes-app" content="app-id=id1234567890">
    
    <!-- Android App Links -->
    <meta name="google-play-app" content="app-id=com.wakeupsunshine">
    
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #FF6B35 0%, #F7931E 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            max-width: 400px;
            width: 100%;
            text-align: center;
        }
        
        .logo {
            width: 120px;
            height: 120px;
            margin: 0 auto 24px;
            background: white;
            border-radius: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        
        .logo svg {
            width: 70px;
            height: 70px;
        }
        
        h1 {
            color: white;
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        
        .subtitle {
            color: rgba(255,255,255,0.9);
            font-size: 18px;
            margin-bottom: 32px;
        }
        
        .invite-card {
            background: rgba(255,255,255,0.2);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 24px;
            margin-bottom: 32px;
        }
        
        .invite-label {
            color: rgba(255,255,255,0.8);
            font-size: 14px;
            margin-bottom: 8px;
        }
        
        .invite-code {
            color: white;
            font-size: 36px;
            font-weight: 700;
            font-family: 'Courier New', monospace;
            letter-spacing: 4px;
        }
        
        .store-buttons {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        
        .store-button {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            background: white;
            color: #1a1a1a;
            text-decoration: none;
            padding: 16px 24px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .store-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0,0,0,0.2);
        }
        
        .store-button svg {
            width: 28px;
            height: 28px;
        }
        
        .info {
            color: rgba(255,255,255,0.8);
            font-size: 14px;
            margin-top: 24px;
            line-height: 1.6;
        }
        
        .deep-link-btn {
            background: transparent;
            border: 2px solid white;
            color: white;
            margin-bottom: 12px;
        }
        
        .deep-link-btn:hover {
            background: rgba(255,255,255,0.1);
        }
        
        @media (max-width: 480px) {
            h1 {
                font-size: 26px;
            }
            
            .invite-code {
                font-size: 28px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="5" fill="#FF6B35"/>
                <path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" stroke="#FF6B35" stroke-width="2" stroke-linecap="round"/>
            </svg>
        </div>
        
        <h1>You're Invited!</h1>
        <p class="subtitle">Get free lifetime access to Wake Me Up</p>
        
        <div class="invite-card">
            <p class="invite-label">Your Invite Code</p>
            <p class="invite-code">${inviteCode}</p>
        </div>
        
        <div class="store-buttons">
            <!-- Deep link button - opens app if installed -->
            <a href="wakeupsunshine://unlock/${inviteCode}" class="store-button deep-link-btn">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/>
                </svg>
                Open in App
            </a>
            
            <!-- App Store Button -->
            <a href="https://apps.apple.com/app/wake-me-up/id1234567890" class="store-button" id="ios-button">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
                Download on App Store
            </a>
            
            <!-- Google Play Button -->
            <a href="https://play.google.com/store/apps/details?id=com.wakeupsunshine" class="store-button" id="android-button">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M3 20.5v-17c0-.83.52-1.5 1.15-1.5.27 0 .53.09.75.27l8.6 7.5c.33.29.5.71.5 1.14 0 .43-.17.85-.5 1.14l-8.6 7.5c-.22.18-.48.27-.75.27-.63 0-1.15-.67-1.15-1.5zm11.5-8.5l5.7-5.7c.4-.4.4-1.04 0-1.44l-.06-.06c-.4-.4-1.04-.4-1.44 0L12.5 11l-6.2-6.2c-.4-.4-1.04-.4-1.44 0l-.06.06c-.4.4-.4 1.04 0 1.44L10.5 12l-5.7 5.7c-.4.4-.4 1.04 0 1.44l.06.06c.4.4 1.04.4 1.44 0l6.2-6.2 6.2 6.2c.4.4 1.04.4 1.44 0l.06-.06c.4-.4.4-1.04 0-1.44L14.5 12z"/>
                </svg>
                Get it on Google Play
            </a>
        </div>
        
            <button class="store-button" id="open-app-button" onclick="openApp()">
                Open in Wake Up Sunshine
            </button>
            
            <p class="info">
                If the app is not installed, use the store buttons below.<br>
                Questions? Contact support@wakeupsunshine.app
            </p>
    </div>
    
    <script>
        // Store the invite code in localStorage for when the app opens
        const inviteCode = '${inviteCode}';
        localStorage.setItem('pendingInviteCode', inviteCode);
        localStorage.setItem('inviteCodeTimestamp', Date.now().toString());
        
        // Detect platform and highlight appropriate button
        const userAgent = navigator.userAgent || navigator.vendor;
        const iosButton = document.getElementById('ios-button');
        const androidButton = document.getElementById('android-button');
        
        if (/android/i.test(userAgent)) {
            androidButton.style.order = '-1';
        } else if (/iPad|iPhone|iPod/.test(userAgent)) {
            iosButton.style.order = '-1';
        }
        
        function openApp() {
            window.location.href = 'wakeupsunshine://invite/${inviteCode}';
        }

        // Try the app first when it is installed, then fall back to the page.
        setTimeout(() => {
            openApp();
        }, 600);
    </script>
</body>
</html>`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/')
    
    // Get invite code from path: /invite/{code}
    let inviteCode = ''
    if (pathParts.length >= 3 && pathParts[1] === 'invite') {
      inviteCode = pathParts[2].toUpperCase()
    }
    
    console.log('[unlock-landing] Invite code:', inviteCode)
    
    // Return HTML landing page
    const html = getLandingPage(inviteCode)
    
    return new Response(html, {
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        ...corsHeaders
      }
    })

  } catch (error) {
    console.error('[unlock-landing] Error:', error)
    
    // Return a basic error page
    return new Response(`
      <!DOCTYPE html>
      <html>
      <head><title>Wake Me Up</title></head>
      <body style="font-family: sans-serif; text-align: center; padding: 40px;">
        <h1>Wake Me Up</h1>
        <p>Something went wrong. Please try again.</p>
      </body>
      </html>
    `, {
      headers: { 'Content-Type': 'text/html' }
    })
  }
})
