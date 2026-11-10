/**
 * GET /api/mobile/hotel-payments/status?bookingId=<hotel_bookings.id>
 *
 * Returns the payment state of the user's hotel booking. Pending PayPal
 * orders that were approved are captured here, so local dev works without
 * webhooks. (MoMo is confirmed by its signed redirect or IPN.)
 */

import { NextRequest, NextResponse } from "next/server";
import { supabaseServerClient as db } from "@/lib/hotel/supabaseServerClient";
import {
  errorResponse,
  HttpError,
  LedgerBookingRow,
  loadOwnHotelBooking,
  publicPayment,
  requireSupabaseUser,
} from "@/lib/mobile/hotelPayments";
import { refreshLedgerPayment } from "@/lib/mobile/paymentConfirm";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const user = await requireSupabaseUser(request);
    const id = request.nextUrl.searchParams.get("bookingId");
    if (!id) throw new HttpError(400, "Missing bookingId");
    let hotel = await loadOwnHotelBooking(user.id, id);
    if (!hotel.booking_id) {
      return NextResponse.json({ ok: true, data: publicPayment(hotel, null) });
    }
    const readLedger = async () =>
      (
        await db
          .from("bookings")
          .select("id,user_id,status,payment_status,total_amount,currency,booking_code")
          .eq("id", hotel.booking_id!)
          .maybeSingle()
      ).data as LedgerBookingRow | null;

    let ledger = await readLedger();
    if (ledger && ledger.payment_status !== "paid") {
      await refreshLedgerPayment(ledger.id);
      ledger = await readLedger();
      hotel = await loadOwnHotelBooking(user.id, id);
    }
    return NextResponse.json({ ok: true, data: publicPayment(hotel, ledger) });
  } catch (error) {
    return errorResponse(error);
  }
}
