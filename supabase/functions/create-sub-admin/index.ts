// CRASHX DEMO — create-sub-admin
// The ONLY way a SOUS_ADMIN account can be created. Re-checks the
// caller's role here, in code, independently of the admin_users RLS
// policy (spec section 12: a hidden button is never enough). Creating
// an auth user requires the service role, which is why this can't be
// a plain RPC function callable from Postgres alone.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

interface CreateSubAdminBody {
  email: string;
  password: string;
  display_name: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "ACCESS DENIED" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Scoped client: resolves the caller's identity from their own JWT.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "ACCESS DENIED" }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: callerAdmin } = await admin
    .from("admin_users")
    .select("role, is_active")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (!callerAdmin || callerAdmin.role !== "SUPER_ADMIN" || !callerAdmin.is_active) {
    return jsonResponse({ error: "ACCESS DENIED" }, 403);
  }

  let body: CreateSubAdminBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "INVALID_BODY" }, 400);
  }

  const { email, password, display_name } = body;
  if (!email || !password || password.length < 8 || !display_name) {
    return jsonResponse({ error: "INVALID_INPUT" }, 400);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name },
  });

  if (createError || !created.user) {
    return jsonResponse({ error: "ACCOUNT_CREATION_FAILED", details: createError?.message }, 400);
  }

  // role is hard-coded to SOUS_ADMIN here — this endpoint can never be
  // used to mint a SUPER_ADMIN no matter what the request body sends.
  const { error: insertError } = await admin.from("admin_users").insert({
    id: created.user.id,
    role: "SOUS_ADMIN",
    display_name,
    created_by: userData.user.id,
  });

  if (insertError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: "ADMIN_ROW_CREATION_FAILED", details: insertError.message }, 400);
  }

  await admin.from("admin_logs").insert({
    admin_id: userData.user.id,
    action: "CREATE_SUB_ADMIN",
    target_type: "admin_users",
    target_id: created.user.id,
    metadata: { display_name, email },
  });

  return jsonResponse({ admin_id: created.user.id });
});
