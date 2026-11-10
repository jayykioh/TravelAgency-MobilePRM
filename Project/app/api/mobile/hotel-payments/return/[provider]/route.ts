/**
 * GET /api/mobile/hotel-payments/return/{momo|paypal}
 *
 * Gateway redirect target for the mobile flow. Confirms the payment
 * server-side (signed MoMo params / PayPal capture), then tells the user to
 * go back to the app, which re-reads /status.
 */

import { NextRequest } from "next/server";
import {
  confirmMomoRedirect,
  confirmPaypalOrder,
} from "@/lib/mobile/paymentConfirm";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: { provider: string } },
) {
  const query = Object.fromEntries(request.nextUrl.searchParams.entries());
  let paid = false;
  if (params.provider === "momo") {
    const result = await confirmMomoRedirect(query);
    paid = result === "success" || result === "already_processed";
  } else if (params.provider === "paypal" && query.token) {
    paid = await confirmPaypalOrder(query.token);
  }
  const title = paid ? "Thanh toán thành công" : "Chưa hoàn tất thanh toán";
  const text = paid
    ? "Quay lại ứng dụng TripC để xem đơn đã thanh toán."
    : "Thanh toán chưa hoàn tất hoặc đã bị hủy. Quay lại ứng dụng TripC để kiểm tra hoặc thử lại.";
  const html = `<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<style>body{font-family:system-ui,sans-serif;background:#fff7ed;color:#1e293b;margin:0;display:grid;place-items:center;min-height:100vh;padding:16px}
main{background:#fff;border-radius:20px;padding:28px;max-width:420px;text-align:center;box-shadow:0 10px 30px rgba(0,0,0,.08)}
h1{color:${paid ? "#16a34a" : "#ff5e1f"};font-size:22px}</style></head>
<body><main><h1>${title}</h1><p>${text}</p></main></body></html>`;
  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}
