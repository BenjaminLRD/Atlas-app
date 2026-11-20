// Supabase Edge Function: revenuecat-webhook
//
// RevenueCat calls this after store purchases, renewals and expirations. It
// sets profiles.subscription_tier, which the ai-proxy function trusts for
// quotas. The app can never change the tier itself (see the
// protect_subscription_tier trigger).
//
// Setup:
//   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<long random string>
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
//   RevenueCat dashboard > Integrations > Webhooks:
//     URL: https://<project>.supabase.co/functions/v1/revenuecat-webhook
//     Authorization header: Bearer <the same secret>

import { createClient } from "jsr:@supabase/supabase-js@2";

const ENTITLEMENT = "pro";
const GRANT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);
// CANCELLATION and BILLING_ISSUE keep access until EXPIRATION arrives.
const REVOKE_EVENTS = new Set(["EXPIRATION"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, "Method not allowed.");

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret || req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return reply(401, "Unauthorized.");
  }

  let event: Record<string, unknown>;
  try {
    event = (await req.json()).event ?? {};
  } catch {
    return reply(400, "Invalid JSON.");
  }

  const type = String(event.type ?? "");
  const entitlements = (event.entitlement_ids as string[] | undefined) ?? [];
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const setTier = async (userIds: unknown[], tier: "Pro" | "Free") => {
    const ids = userIds.map(String).filter((id) => UUID.test(id));
    if (ids.length === 0) return;
    const { error } = await admin.from("profiles").update({ subscription_tier: tier }).in("id", ids);
    if (error) throw error;
  };

  try {
    if (type === "TRANSFER") {
      await setTier((event.transferred_from as unknown[]) ?? [], "Free");
      await setTier((event.transferred_to as unknown[]) ?? [], "Pro");
    } else if (GRANT_EVENTS.has(type) && entitlements.includes(ENTITLEMENT)) {
      await setTier([event.app_user_id, ...((event.aliases as unknown[]) ?? [])], "Pro");
    } else if (REVOKE_EVENTS.has(type) && entitlements.includes(ENTITLEMENT)) {
      await setTier([event.app_user_id, ...((event.aliases as unknown[]) ?? [])], "Free");
    }
  } catch (_) {
    // A non-2xx response makes RevenueCat retry later.
    return reply(500, "Could not update the subscription.");
  }

  return reply(200, "ok");
});

function reply(status: number, message: string): Response {
  return new Response(JSON.stringify({ message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
