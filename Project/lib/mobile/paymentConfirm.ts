/**
 * Confirms MoMo / PayPal payments for mobile hotel bookings without relying
 * on webhooks (which cannot reach a local dev server). Signatures and
 * gateway state are always checked server-side.
 */

import { supabaseServerClient as db } from "@/lib/hotel/supabaseServerClient";
import { PaymentService } from "@/lib/checkout/services/payment.service";
import { SettlementService } from "@/lib/checkout/services/settlement.service";
import { PaypalPaymentProvider } from "@/lib/checkout/payments/providers/paypal-provider";

/**
 * MoMo redirect params carry the same signed fields as the IPN, so they go
 * through PaymentService.handleWebhook (signature check, txn update,
 * settlement). Returns the result, or null when params are missing/invalid.
 */
export async function confirmMomoRedirect(params: Record<string, string>) {
  if (!params.orderId || !params.signature) return null;
  try {
    const result = await new PaymentService().handleWebhook("momo", null, {
      ...params,
      amount: Number(params.amount),
      resultCode: Number(params.resultCode),
    });
    return result.status as string;
  } catch (error: any) {
    console.error("[MOBILE_PAYMENT] MoMo redirect rejected", error?.message);
    return null;
  }
}

/**
 * Captures an approved PayPal order and settles its booking. Safe to call
 * repeatedly; an unapproved order simply returns false.
 */
export async function confirmPaypalOrder(orderId: string): Promise<boolean> {
  const { data: txn } = await db
    .from("payment_transactions")
    .select("id,booking_id,status")
    .eq("provider", "paypal")
    .eq("provider_transaction_id", orderId)
    .maybeSingle();
  if (!txn) return false;
  if (txn.status === "success") return true;

  let capture: any;
  try {
    capture = await new PaypalPaymentProvider().captureOrder(orderId);
  } catch {
    return false; // not approved yet, or cancelled
  }
  if (capture?.status !== "COMPLETED") return false;
  const reference = capture.purchase_units?.[0]?.reference_id;
  if (reference && reference !== txn.booking_id) {
    console.error("[MOBILE_PAYMENT] PayPal reference mismatch", orderId);
    return false;
  }
  await db
    .from("payment_transactions")
    .update({
      status: "success",
      webhook_payload: capture,
      updated_at: new Date().toISOString(),
    })
    .eq("id", txn.id);
  await new SettlementService(db).settleBooking(txn.booking_id);
  return true;
}

/** Tries to finish any pending PayPal transaction of a ledger booking. */
export async function refreshLedgerPayment(ledgerBookingId: string) {
  const { data: txns } = await db
    .from("payment_transactions")
    .select("provider,provider_transaction_id,status")
    .eq("booking_id", ledgerBookingId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(3);
  for (const txn of txns || []) {
    if (txn.provider === "paypal" && txn.provider_transaction_id) {
      if (await confirmPaypalOrder(txn.provider_transaction_id)) return;
    }
  }
}
