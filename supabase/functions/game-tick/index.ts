// CRASHX DEMO — game-tick
// Fallback heartbeat for the game engine, used only if pg_cron's
// sub-minute scheduling isn't available on this project (see
// supabase/seed.sql). Point an external scheduler (cron-job.org, a
// GitHub Actions schedule, etc.) at this endpoint every 5-15 seconds.
// Requires no body; authorizes itself using the service role key,
// which the caller must supply as a bearer token — treat this URL as
// a secret, it is not meant to be public.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ error: "ACCESS DENIED" }, 401);
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serviceRoleKey);
  const { error } = await admin.rpc("game_tick");

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({ ok: true });
});
