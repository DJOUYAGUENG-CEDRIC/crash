// CRASHX DEMO — get-invitation (browser-editor deploy copy, inlined)
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

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
