// Edge Function: send-push-notification
// Persists notification to database and delivers push notification via FCM v1.
// Handles automatic token deactivation when FCM reports unregistered tokens.
// Gracefully degrades if FIREBASE_SERVICE_ACCOUNT is not configured.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PushRequestPayload {
  recipientUserId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, any>;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate caller (Must have valid Supabase session)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAnon = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabaseAnon.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse and validate request
    const payload: PushRequestPayload = await req.json();
    const { recipientUserId, type, title, body, data = {} } = payload;

    if (!recipientUserId || !type || !title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: recipientUserId, type, title, body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 3. Persist notification into database
    const { data: insertedNotification, error: dbError } = await supabaseAdmin
      .from("notifications")
      .insert({
        recipient_user_id: recipientUserId,
        type,
        title,
        body,
        data,
      })
      .select("id")
      .single();

    if (dbError) {
      console.error("Failed to insert notification into DB:", dbError);
    }

    // 4. Retrieve active FCM tokens for recipient
    const { data: deviceTokens, error: tokensError } = await supabaseAdmin
      .from("user_device_tokens")
      .select("id, fcm_token")
      .eq("user_id", recipientUserId)
      .eq("is_active", true);

    if (tokensError) {
      console.error("Error querying device tokens:", tokensError);
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          delivered: false,
          notificationId: insertedNotification?.id,
          reason: "No active device tokens found for recipient",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Check if Firebase Service Account credentials are provided
    if (!FIREBASE_SERVICE_ACCOUNT) {
      console.warn("FIREBASE_SERVICE_ACCOUNT secret not configured. Recorded notification without push dispatch.");
      return new Response(
        JSON.stringify({
          success: true,
          delivered: false,
          notificationId: insertedNotification?.id,
          reason: "firebase_not_configured",
          tokensCount: deviceTokens.length,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Parse Firebase credentials
    let serviceAccount: { client_email: string; private_key: string; project_id: string };
    try {
      serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    } catch (parseErr) {
      console.error("Invalid JSON in FIREBASE_SERVICE_ACCOUNT:", parseErr);
      return new Response(
        JSON.stringify({
          success: true,
          delivered: false,
          error: "Invalid FIREBASE_SERVICE_ACCOUNT configuration",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Convert data values to strings as required by FCM v1 data payload
    const stringifiedData: Record<string, string> = {
      type: String(type),
    };
    for (const [k, v] of Object.entries(data)) {
      stringifiedData[k] = typeof v === "string" ? v : JSON.stringify(v);
    }

    let sentCount = 0;
    let failedCount = 0;
    const staleTokens: string[] = [];

    // Helper to get Google OAuth2 Token
    const accessToken = await getGoogleAccessToken(serviceAccount);
    if (!accessToken) {
      return new Response(
        JSON.stringify({
          success: true,
          delivered: false,
          error: "Failed to generate Google access token",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. Dispatch to each active token
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    for (const tokenRecord of deviceTokens) {
      try {
        const messageBody = {
          message: {
            token: tokenRecord.fcm_token,
            notification: {
              title,
              body,
            },
            data: stringifiedData,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "shramsetu_booking_updates",
                sound: "default",
                default_vibrate_timings: true,
              },
            },
          },
        };

        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(messageBody),
        });

        if (res.ok) {
          sentCount++;
        } else {
          failedCount++;
          const errText = await res.text();
          console.error(`FCM error for token ${tokenRecord.fcm_token.substring(0, 10)}...:`, errText);

          // If token is invalid or unregistered, queue for deactivation
          if (
            errText.includes("UNREGISTERED") ||
            errText.includes("INVALID_ARGUMENT") ||
            errText.includes("registration-token-not-registered")
          ) {
            staleTokens.push(tokenRecord.fcm_token);
          }
        }
      } catch (sendErr) {
        failedCount++;
        console.error("FCM dispatch exception:", sendErr);
      }
    }

    // 8. Automatic Token Cleanup for stale tokens
    if (staleTokens.length > 0) {
      await supabaseAdmin
        .from("user_device_tokens")
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .in("fcm_token", staleTokens);
      console.log(`Deactivated ${staleTokens.length} stale FCM tokens.`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        delivered: sentCount > 0,
        notificationId: insertedNotification?.id,
        sentCount,
        failedCount,
        deactivatedTokens: staleTokens.length,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("send-push-notification top-level error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// Minimal OAuth2 JWT token generator for Google Cloud Service Accounts (Deno-native)
async function getGoogleAccessToken(
  sa: { client_email: string; private_key: string }
): Promise<string | null> {
  try {
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: "RS256", typ: "JWT" };
    const claimSet = {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
    const signingInput = `${encodedHeader}.${encodedClaimSet}`;

    // Import private key and sign
    const pemContents = sa.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/g, "")
      .replace(/-----END PRIVATE KEY-----/g, "")
      .replace(/\s+/g, "");
    const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signatureBuffer = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      new TextEncoder().encode(signingInput)
    );

    const signature = base64UrlEncodeBuffer(signatureBuffer);
    const jwt = `${signingInput}.${signature}`;

    // Exchange JWT for OAuth2 access token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!tokenRes.ok) {
      console.error("OAuth2 exchange failed:", await tokenRes.text());
      return null;
    }

    const tokenData = await tokenRes.json();
    return tokenData.access_token;
  } catch (err) {
    console.error("getGoogleAccessToken error:", err);
    return null;
  }
}

function base64UrlEncode(str: string): string {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlEncodeBuffer(buffer: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}