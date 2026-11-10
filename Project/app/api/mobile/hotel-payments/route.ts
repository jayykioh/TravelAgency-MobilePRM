/**
 * POST /api/mobile/hotel-payments
 *
 * Flutter hotel checkout with the web's existing gateways (MoMo / PayPal).
 * Creates (or reuses) the pending hotel booking for the signed-in Supabase
 * user, links a unified `bookings` row, and returns the gateway URL from
 * PaymentService.
 *
 * Auth: `Authorization: Bearer <supabase access token>`.
 * Body: { provider: "momo" | "paypal", booking: <buildBookingPayload> }
 *
 * Amount: PAYMENT_TEST_AMOUNT_VND (e.g. 10000) is charged while testing.
 * Without it the route refuses, since the price would come from the client.
 */

import { NextRequest, NextResponse } from "next/server";
import { PaymentService } from "@/lib/checkout/services/payment.service";
import {
  appBaseUrl,
  ensureLedgerBooking,
  ensureUserRow,
  errorResponse,
  findOrCreateHotelBooking,
  HttpError,
  MobilePaymentProvider,
  PAYMENT_PROVIDERS,
  paymentTestAmountVnd,
  pickBookingPayload,
  publicPayment,
  requireSupabaseUser,
} from "@/lib/mobile/hotelPayments";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const amount = paymentTestAmountVnd();
    if (amount === null) {
      throw new HttpError(
        501,
        "Set PAYMENT_TEST_AMOUNT_VND to enable mobile payments (server-side pricing not implemented)",
      );
    }
    const user = await requireSupabaseUser(request);
    const body = await request.json().catch(() => null);
    const provider = body?.provider as MobilePaymentProvider;
    if (!PAYMENT_PROVIDERS.includes(provider)) {
      throw new HttpError(400, "Unsupported provider");
    }
    const payload = pickBookingPayload(body?.booking);

    await ensureUserRow(user, String(payload.guest_email));
    const hotel = await findOrCreateHotelBooking(user.id, payload);
    if (hotel.status === "cancelled") {
      throw new HttpError(409, "Booking was cancelled");
    }
    const ledger = await ensureLedgerBooking(user.id, hotel, amount);
    if (hotel.payment_status === "paid" || ledger.payment_status === "paid") {
      return NextResponse.json({ ok: true, data: publicPayment(hotel, ledger) });
    }

    // No query string: MoMo/PayPal append their own params to this URL.
    const returnUrl = `${appBaseUrl(request)}/api/mobile/hotel-payments/return/${provider}`;
    const intent = await new PaymentService().createPaymentIntent(
      ledger.id,
      provider,
      returnUrl,
    );
    return NextResponse.json({
      ok: true,
      data: publicPayment(hotel, ledger, {
        provider,
        paymentUrl: intent.paymentUrl,
      }),
    });
  } catch (error) {
    return errorResponse(error);
  }
}
