/**
 * Server logic for paying a Flutter hotel booking with the existing web
 * payment stack (PaymentService: MoMo / PayPal -> SettlementService).
 *
 * The app authenticates with Supabase Auth (not Clerk), so every helper here
 * works from a verified Supabase user id and the service-role client.
 *
 * Shape:
 *   hotel_bookings (pending, created up front so "Đơn của tôi" shows it)
 *     .booking_id -> bookings (category 'hotel', what PaymentService charges)
 *        -> payment_transactions (momo/paypal)
 *   On success SettlementService marks bookings paid, and
 *   HotelSettlementHandler marks the linked hotel_bookings row paid.
 */

import { NextRequest, NextResponse } from "next/server";
import { supabaseServerClient as db } from "@/lib/hotel/supabaseServerClient";
import { generateBookingCode } from "@/utils/booking-codes";

export const PAYMENT_PROVIDERS = ["momo", "paypal"] as const;
export type MobilePaymentProvider = (typeof PAYMENT_PROVIDERS)[number];

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

export function errorResponse(error: unknown) {
  if (error instanceof HttpError) {
    return NextResponse.json(
      { ok: false, error: error.message },
      { status: error.status },
    );
  }
  const message = error instanceof Error ? error.message : String(error);
  // Gateway failures from the providers ("Momo gateway error", PayPal token).
  if (/momo|paypal/i.test(message)) {
    console.error("[MOBILE_PAYMENT] gateway error", message);
    return NextResponse.json({ ok: false, error: message }, { status: 502 });
  }
  console.error("[MOBILE_PAYMENT] unexpected error", error);
  return NextResponse.json(
    { ok: false, error: "Internal server error" },
    { status: 500 },
  );
}

/**
 * Fixed VND amount charged while testing (PAYMENT_TEST_AMOUNT_VND=10000).
 * Null when unset; the mobile route then refuses, because the price would
 * otherwise come from the client.
 */
export function paymentTestAmountVnd(): number | null {
  const raw = process.env.PAYMENT_TEST_AMOUNT_VND;
  if (!raw) return null;
  const value = Math.round(Number(raw));
  return Number.isFinite(value) && value >= 1000 ? value : null;
}

export interface MobileUser {
  id: string;
  email: string | null;
}

export async function requireSupabaseUser(
  request: NextRequest,
): Promise<MobileUser> {
  const header = request.headers.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) throw new HttpError(401, "Missing bearer token");
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Invalid session");
  return { id: data.user.id, email: data.user.email ?? null };
}

/**
 * hotel_bookings.user_uuid references users(id), and users rows are only
 * created by the Clerk sync on web. Bridge Supabase Auth accounts with a
 * users row whose id equals auth.uid().
 */
export async function ensureUserRow(user: MobileUser, fallbackEmail: string) {
  const { data: existing, error } = await db
    .from("users")
    .select("id")
    .eq("id", user.id)
    .maybeSingle();
  if (error) throw new HttpError(500, "Cannot read user profile");
  if (existing) return;
  const { error: insertError } = await db.from("users").insert({
    id: user.id,
    clerk_id: `supabase:${user.id}`,
    email: user.email || fallbackEmail,
  });
  if (insertError && insertError.code !== "23505") {
    throw new HttpError(500, "Cannot link Supabase account to users");
  }
}

const ALLOWED_FIELDS = [
  "hotel_id",
  "room_id",
  "partner_id",
  "confirmation_code",
  "check_in_date",
  "check_out_date",
  "guest_name",
  "guest_email",
  "guest_phone",
  "guest_count",
  "special_requests",
  "total_cents",
  "nightly_rate_cents",
  "tax_cents",
  "fees_cents",
  "currency",
  "metadata",
] as const;

const REQUIRED_FIELDS = [
  "hotel_id",
  "room_id",
  "confirmation_code",
  "check_in_date",
  "check_out_date",
  "guest_name",
  "guest_email",
  "guest_phone",
  "guest_count",
  "total_cents",
  "nightly_rate_cents",
] as const;

/** Whitelists the app's hotel_bookings payload; drops any status fields. */
export function pickBookingPayload(raw: any) {
  if (!raw || typeof raw !== "object") {
    throw new HttpError(400, "Missing booking payload");
  }
  const payload: Record<string, any> = {};
  for (const key of ALLOWED_FIELDS) {
    if (raw[key] !== undefined) payload[key] = raw[key];
  }
  for (const key of REQUIRED_FIELDS) {
    if (payload[key] === undefined || payload[key] === null || payload[key] === "") {
      throw new HttpError(400, `Missing field: ${key}`);
    }
  }
  if (!/^[A-Z0-9]{8}$/.test(String(payload.confirmation_code))) {
    throw new HttpError(400, "Invalid confirmation_code");
  }
  if (!Number.isInteger(payload.total_cents) || payload.total_cents < 0) {
    throw new HttpError(400, "Invalid total_cents");
  }
  if (
    payload.metadata !== undefined &&
    (typeof payload.metadata !== "object" || Array.isArray(payload.metadata))
  ) {
    throw new HttpError(400, "Invalid metadata");
  }
  return payload;
}

export const HOTEL_BOOKING_COLUMNS =
  "id,user_uuid,booking_id,confirmation_code,status,payment_status,total_cents,currency,hotel_id,room_id,check_in_date,check_out_date,guest_name,guest_email,guest_phone,guest_count,metadata";

export type HotelBookingRow = {
  id: string;
  user_uuid: string;
  booking_id: string | null;
  confirmation_code: string;
  status: string;
  payment_status: string;
  total_cents: number;
  currency: string;
  hotel_id: string;
  room_id: string;
  check_in_date: string;
  check_out_date: string;
  guest_name: string;
  guest_email: string;
  guest_phone: string;
  guest_count: Record<string, number>;
  metadata: Record<string, any> | null;
};

/** Reuses the row for a retried confirmation code, else inserts it. */
export async function findOrCreateHotelBooking(
  userId: string,
  payload: Record<string, any>,
): Promise<HotelBookingRow> {
  const { data: existing, error } = await db
    .from("hotel_bookings")
    .select(HOTEL_BOOKING_COLUMNS)
    .eq("confirmation_code", payload.confirmation_code)
    .maybeSingle();
  if (error) throw new HttpError(500, "Cannot read booking");
  if (existing) {
    if (existing.user_uuid !== userId) {
      throw new HttpError(409, "Confirmation code already used");
    }
    return existing as HotelBookingRow;
  }
  const { data, error: insertError } = await db
    .from("hotel_bookings")
    .insert({
      ...payload,
      user_uuid: userId,
      external_user_ref: userId,
      status: "pending",
      payment_status: "pending",
      booking_source: "mobile",
    })
    .select(HOTEL_BOOKING_COLUMNS)
    .single();
  if (insertError || !data) {
    if (insertError?.code === "23503") {
      throw new HttpError(422, "Hotel or room no longer exists");
    }
    if (["23502", "23514", "22P02", "22007", "22008"].includes(insertError?.code || "")) {
      throw new HttpError(400, "Invalid booking data");
    }
    console.error("[MOBILE_PAYMENT] hotel booking insert failed", insertError?.code);
    throw new HttpError(500, "Cannot create booking");
  }
  return data as HotelBookingRow;
}

export type LedgerBookingRow = {
  id: string;
  user_id: string;
  status: string;
  payment_status: string;
  total_amount: number;
  currency: string;
  booking_code: string;
};

/**
 * Creates the unified `bookings` row PaymentService charges, in the shape
 * HotelSettlementHandler reads, and links it from hotel_bookings.booking_id.
 */
export async function ensureLedgerBooking(
  userId: string,
  hotel: HotelBookingRow,
  amountVnd: number,
): Promise<LedgerBookingRow> {
  const columns = "id,user_id,status,payment_status,total_amount,currency,booking_code";
  if (hotel.booking_id) {
    const { data } = await db
      .from("bookings")
      .select(columns)
      .eq("id", hotel.booking_id)
      .maybeSingle();
    if (data) return data as LedgerBookingRow;
  }

  const { data: hotelInfo } = await db
    .from("hotels")
    .select("name,images")
    .eq("id", hotel.hotel_id)
    .maybeSingle();
  const guestDetails = {
    name: hotel.guest_name,
    email: hotel.guest_email,
    phone: hotel.guest_phone,
  };
  const { data, error } = await db
    .from("bookings")
    .insert({
      category: "hotel",
      user_id: userId,
      title: hotelInfo?.name || "Hotel booking",
      image_url: Array.isArray(hotelInfo?.images) ? hotelInfo.images[0] ?? null : null,
      total_amount: amountVnd,
      currency: "VND",
      status: "pending",
      payment_status: "unpaid",
      booking_code: generateBookingCode("hotel"),
      guest_details: guestDetails,
      guest_email: hotel.guest_email,
      start_date: new Date(hotel.check_in_date).toISOString(),
      end_date: new Date(hotel.check_out_date).toISOString(),
      metadata: {
        source: "mobile",
        hotelBookingId: hotel.id,
        hotelId: hotel.hotel_id,
        roomId: hotel.room_id,
        dates: { start: hotel.check_in_date, end: hotel.check_out_date },
        guestDetails,
        guestCount: hotel.guest_count,
        testAmount: true,
        quotedTotalCents: hotel.total_cents,
        quotedCurrency: hotel.currency,
      },
    })
    .select(columns)
    .single();
  if (error || !data) {
    console.error("[MOBILE_PAYMENT] ledger booking insert failed", error?.code);
    throw new HttpError(500, "Cannot create payment booking");
  }
  await db.from("booking_events").insert({
    booking_id: data.id,
    event_type: "BOOKING_CREATED",
  });
  const { error: linkError } = await db
    .from("hotel_bookings")
    .update({ booking_id: data.id, updated_at: new Date().toISOString() })
    .eq("id", hotel.id);
  if (linkError) throw new HttpError(500, "Cannot link payment booking");
  return data as LedgerBookingRow;
}

export async function loadOwnHotelBooking(userId: string, id: string) {
  const { data, error } = await db
    .from("hotel_bookings")
    .select(HOTEL_BOOKING_COLUMNS)
    .eq("id", id)
    .eq("user_uuid", userId)
    .maybeSingle();
  if (error) throw new HttpError(400, "Invalid bookingId");
  if (!data) throw new HttpError(404, "Booking not found");
  return data as HotelBookingRow;
}

/** Response shape the Flutter app reads. */
export function publicPayment(
  hotel: HotelBookingRow,
  ledger: LedgerBookingRow | null,
  payment?: { provider: string; paymentUrl: string } | null,
) {
  const paid = hotel.payment_status === "paid" || ledger?.payment_status === "paid";
  return {
    id: hotel.id,
    confirmation_code: hotel.confirmation_code,
    status: paid && hotel.status === "pending" ? "confirmed" : hotel.status,
    payment_status: paid ? "paid" : hotel.payment_status,
    total_cents: hotel.total_cents,
    currency: hotel.currency,
    payment: ledger
      ? {
          provider: payment?.provider ?? null,
          payment_url: payment?.paymentUrl ?? null,
          ledger_booking_id: ledger.id,
          amount: Number(ledger.total_amount),
          currency: ledger.currency,
          test_mode: true,
          status: paid ? "paid" : "pending",
        }
      : null,
  };
}

export function appBaseUrl(request: NextRequest) {
  return (
    process.env.PAYMENT_RETURN_BASE_URL ||
    process.env.NEXT_PUBLIC_APP_URL ||
    request.nextUrl.origin
  ).replace(/\/$/, "");
}
