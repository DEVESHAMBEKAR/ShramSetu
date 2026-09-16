// Edge Function: verify-payment
// Server-side HMAC-SHA256 verification of Razorpay payment.
// NEVER trusts client callback — always verifies signature cryptographically.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { hmac } from "https://deno.land/x/hmac@v2.0.1/mod.ts";

const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAnon = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabaseAnon.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse Razorpay callback data from client
    const { bookingId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = await req.json();
    if (!bookingId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Verify payment belongs to authenticated customer
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: payment, error: paymentError } = await supabaseAdmin
      .from("payments")
      .select("id, customer_id, status, razorpay_payment_id")
      .eq("booking_id", bookingId)
      .eq("razorpay_order_id", razorpayOrderId)
      .single();

    if (paymentError || !payment) {
      return new Response(JSON.stringify({ error: "Payment record not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (payment.customer_id !== user.id) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. CRITICAL: Server-side HMAC-SHA256 signature verification
    // Razorpay spec: HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, secret)
    const expectedSignature = hmac(
      "sha256",
      RAZORPAY_KEY_SECRET,
      `${razorpayOrderId}|${razorpayPaymentId}`,
      "utf8",
      "hex"
    );

    const isVerified = expectedSignature === razorpaySignature;

    // 5. Update payment record atomically via SECURITY DEFINER RPC
    const { data: result, error: rpcError } = await supabaseAdmin.rpc(
      "record_payment_verification",
      {
        p_booking_id: bookingId,
        p_razorpay_order_id: razorpayOrderId,
        p_razorpay_payment_id: razorpayPaymentId,
        p_razorpay_signature: razorpaySignature,
        p_verified: isVerified,
      }
    );

    if (rpcError) {
      console.error("record_payment_verification RPC error:", rpcError);
      return new Response(JSON.stringify({ error: "DB update failed" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Return verification result (never log signatures in production)
    return new Response(
      JSON.stringify({ success: isVerified, idempotent: result?.idempotent ?? false }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("verify-payment error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
