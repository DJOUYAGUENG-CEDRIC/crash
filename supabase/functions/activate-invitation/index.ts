// CRASHX DEMO — activate-invitation
// The ONLY way a player account can ever be created. Public signup
// (supabase.auth.signUp) must stay disabled in the project's Auth
// settings — see README. This function validates the invitation token
// server-side, creates the auth user with the service role (bypassing
// the disabled public signup), and consumes the invitation atomically.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

interface ActivateBody {
  token: string;
  email: string;
  password: string;
  display_name?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  let body: ActivateBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "INVALID_BODY" }, 400);
  }

  const { token, email, password, display_name } = body;
  if (!token || !email || !password || password.length < 8) {
    return jsonResponse({ error: "INVALID_INPUT" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: invitation, error: invError } = await admin
    .from("invitations")
    .select("*")
    .eq("token", token)
    .maybeSingle();

  if (invError || !invitation) {
    return jsonResponse({ error: "INVITATION_NOT_FOUND" }, 404);
  }
  if (invitation.status !== "PENDING") {
    return jsonResponse({ error: "INVITATION_ALREADY_USED_OR_REVOKED" }, 409);
  }
  if (new Date(invitation.expires_at) < new Date()) {
    return jsonResponse({ error: "INVITATION_EXPIRED" }, 409);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      display_name: display_name ?? invitation.invited_name,
      invitation_id: invitation.id,
    },
  });

  if (createError || !created.user) {
    return jsonResponse({ error: "ACCOUNT_CREATION_FAILED", details: createError?.message }, 400);
  }

  const { error: consumeError } = await admin
    .from("invitations")
    .update({ user_id: created.user.id, used_at: new Date().toISOString(), status: "USED" })
    .eq("id", invitation.id)
    .eq("status", "PENDING"); // guards against a second concurrent activation

  if (consumeError) {
    // Roll back the account so a failed consume never leaves an
    // orphaned login with no linked invitation.
    await admin.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: "INVITATION_RACE_CONDITION" }, 409);
  }

  return jsonResponse({ user_id: created.user.id });
});
