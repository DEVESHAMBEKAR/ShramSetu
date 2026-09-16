// Edge Function: razorpay-webhook
// Server-to-server webhook from Razorpay for payment event reconciliation.
// Validates X-Razorpay-Signature using RAZORPAY_WEBHOOK_SECRET.
// Idempotent — same payment ID processed twice has no effect.
//
// MANUAL SETUP REQUIRED:
// 1. Deploy this function: supabase functions deploy razorpay-webhook
// 2. Register webhook URL in Razorpay Dashboard:
//    https://dashboard.razorpay.com/app/webhooks
//    URL: https://<your-project>.supabase.co/functions/v1/razorpay-webhook
//    Events: payment.captured, payment.failed
// 3. Set secret in Supabase: supabase secrets set RAZORPAY_WEBHOOK_SECRET=<your-webhook-secret>

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { hmac } from "https://deno.land/x/hmac@v2.0.1/mod.ts";

const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req: Request) => {
  try {
    const rawBody = await req.text();
    const signature = req.headers.get("X-Razorpay-Signature");

    if (!signature) {
      return new Response("Missing signature", { status: 400 });
    }

    // Validate webhook authenticity
    const expectedSig = hmac("sha256", RAZORPAY_WEBHOOK_SECRET, rawBody, "utf8", "hex");
    if (expectedSig !== signature) {
      console.error("Webhook signature mismatch");
      return new Response("Invalid signature", { status: 401 });
    }

    const event = JSON.parse(rawBody);
    const eventType = event.event as string;
    const paymentEntity = event.payload?.payment?.entity;

    if (!paymentEntity) {
      return new Response("OK", { status: 200 });
    }

    const razorpayPaymentId = paymentEntity.id as string;
    const razorpayOrderId = paymentEntity.order_id as string;
    const status = paymentEntity.status as string; // "captured" | "failed"

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Idempotency: check if already processed
    const { data: existing } = await supabase
      .from("payments")
      .select("id, status, razorpay_payment_id")
      .eq("razorpay_order_id", razorpayOrderId)
      .single();

    if (!existing) {
      // No matching order — ignore (may be from another integration)
      return new Response("OK", { status: 200 });
    }

    // Already at terminal state — skip
    if (existing.razorpay_payment_id === razorpayPaymentId &&
        ["PAID", "FAILED"].includes(existing.status)) {
      return new Response("OK", { status: 200 });
    }

    if (eventType === "payment.captured" && status === "captured") {
      await supabase
        .from("payments")
        .update({
          status: "PAID",
          escrow_status: "held",
          razorpay_payment_id: razorpayPaymentId,
          updated_at: new Date().toISOString(),
        })
        .eq("razorpay_order_id", razorpayOrderId);

    } else if (eventType === "payment.failed" || status === "failed") {
      await supabase
        .from("payments")
        .update({
          status: "FAILED",
          updated_at: new Date().toISOString(),
        })
        .eq("razorpay_order_id", razorpayOrderId);
    }

    return new Response("OK", { status: 200 });
  } catch (err) {
    console.error("razorpay-webhook error:", err);
    return new Response("Internal error", { status: 500 });
  }
});
