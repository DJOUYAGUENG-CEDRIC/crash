// CRASHX DEMO — get-invitation
// Public (anon-callable) endpoint backing the invite landing page
// (spec section 31). Never exposes invitations via direct table RLS —
// only this function, using the service role, reads the row, and it
// returns nothing beyond what the landing page needs to show.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  if (!token) {
    return jsonResponse({ error: "MISSING_TOKEN" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase
    .from("invitations")
    .select("invited_name, expires_at, status")
    .eq("token", token)
    .maybeSingle();

  if (error || !data) {
    return jsonResponse({ error: "NOT_FOUND" }, 404);
  }

  const isExpired = new Date(data.expires_at) < new Date();
  const effectiveStatus = isExpired && data.status === "PENDING" ? "EXPIRED" : data.status;

  return jsonResponse({
    invited_name: data.invited_name,
    expires_at: data.expires_at,
    status: effectiveStatus,
    valid: effectiveStatus === "PENDING",
  });
});
