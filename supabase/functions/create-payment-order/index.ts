// Edge Function: create-payment-order
// Creates a Razorpay order server-side and records it in the DB.
// NEVER trusts the client for amount — reads from authoritative booking data.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID")!;
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

    // Create anon client to verify JWT
    const supabaseAnon = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabaseAnon.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse input — only bookingId from client; amount comes from DB
    const { bookingId } = await req.json();
    if (!bookingId) {
      return new Response(JSON.stringify({ error: "bookingId required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Validate booking belongs to authenticated customer and is in payable state
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: booking, error: bookingError } = await supabaseAdmin
      .from("bookings")
      .select("id, customer_id, worker_id, base_amount, labor_allowance, status")
      .eq("id", bookingId)
      .eq("customer_id", user.id)
      .single();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: "Booking not found or unauthorized" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!["pending", "accepted"].includes(booking.status)) {
      return new Response(JSON.stringify({ error: `Booking not payable. Status: ${booking.status}` }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Calculate authoritative amount from DB (server decides, not client)
    const baseAmount = parseFloat(booking.base_amount) || 0;
    const laborAllowance = parseFloat(booking.labor_allowance) || 0;
    const amountRupees = baseAmount + laborAllowance;

    if (amountRupees <= 0 || amountRupees >= 1000000) {
      return new Response(JSON.stringify({ error: "Invalid booking amount" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const amountPaise = Math.round(amountRupees * 100);

    // 5. Check for existing payment (idempotency)
    const { data: existingPayment } = await supabaseAdmin
      .from("payments")
      .select("id, razorpay_order_id, status")
      .eq("booking_id", bookingId)
      .single();

    if (existingPayment?.status === "PAID") {
      return new Response(JSON.stringify({ error: "Booking already paid" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Create Razorpay order (server-side, using secret key)
    const razorpayAuth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const razorpayRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${razorpayAuth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: "INR",
        receipt: `booking_${bookingId.substring(0, 8)}`,
        notes: { bookingId, customerId: user.id },
      }),
    });

    if (!razorpayRes.ok) {
      const errBody = await razorpayRes.text();
      console.error("Razorpay order creation failed:", errBody);
      return new Response(JSON.stringify({ error: "Payment gateway error" }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const razorpayOrder = await razorpayRes.json();

    // 7. Store payment record via SECURITY DEFINER RPC
    const { error: dbError } = await supabaseAdmin.rpc("create_payment_record", {
      p_booking_id: bookingId,
      p_customer_id: user.id,
      p_worker_id: booking.worker_id,
      p_amount: amountRupees,
      p_amount_paise: amountPaise,
      p_razorpay_order_id: razorpayOrder.id,
      p_payment_method: "razorpay",
    });

    if (dbError) {
      console.error("DB payment record error:", dbError);
      return new Response(JSON.stringify({ error: "Failed to record payment order" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 8. Return ONLY what Flutter checkout needs (never return secret key)
    return new Response(
      JSON.stringify({
        orderId: razorpayOrder.id,
        amount: amountPaise,
        currency: "INR",
        keyId: RAZORPAY_KEY_ID,
        bookingId,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("create-payment-order error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
