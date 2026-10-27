import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.14.0";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.14.4/index.ts";

const PROJECT_ID = "couplesync-syncitman";
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";

interface RequestPayload {
  partner_id: string;
  creator_id?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");

  const jwt = await new SignJWT({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: OAUTH_TOKEN_URL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const res = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Failed to obtain Google access token: ${errorText}`);
  }

  const tokenData = await res.json();
  return tokenData.access_token;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Retrieve Firebase service account from secret
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT environment variable is not configured.");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);

    const payload: RequestPayload = await req.json();
    const { partner_id, title, body, data } = payload;

    if (!partner_id || !title) {
      return new Response(JSON.stringify({ error: "Missing required fields: partner_id, title" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. Fetch partner's device tokens
    const { data: tokenRows, error: tokenError } = await supabase
      .from("user_push_tokens")
      .select("token")
      .eq("user_id", partner_id);

    if (tokenError) {
      throw tokenError;
    }

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(
        JSON.stringify({ message: "No active device tokens found for partner.", sent_count: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. Obtain Google FCM OAuth2 access token
    const accessToken = await getAccessToken(serviceAccount);

    // 3. Send FCM message to each token
    let successCount = 0;
    const tokensToRemove: string[] = [];

    for (const row of tokenRows) {
      const fcmPayload = {
        message: {
          token: row.token,
          notification: {
            title,
            body,
          },
          data: data ?? {},
          android: {
            priority: "high",
            notification: {
              channel_id: "couplesync_shared_reminders",
              sound: "default",
              notification_priority: "PRIORITY_MAX",
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
        },
      };

      const fcmRes = await fetch(FCM_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      });

      if (fcmRes.ok) {
        successCount++;
      } else {
        const errBody = await fcmRes.json();
        console.error("FCM Send error for token:", row.token, errBody);
        // If token is invalid or unregistered, clean it up
        const errCode = errBody?.error?.details?.[0]?.errorCode;
        if (errCode === "UNREGISTERED" || fcmRes.status === 404) {
          tokensToRemove.push(row.token);
        }
      }
    }

    // 4. Remove unregistered tokens
    if (tokensToRemove.length > 0) {
      await supabase
        .from("user_push_tokens")
        .delete()
        .in("token", tokensToRemove);
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent_count: successCount,
        total_tokens: tokenRows.length,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (err: unknown) {
    const error = err as Error;
    console.error("Error sending push notification:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
