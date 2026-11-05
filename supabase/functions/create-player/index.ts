// CRASHX DEMO — create-player
// Staff create player logins directly: the admin picks the login and the
// password, hands them to the player, and the player signs in right away
// (no invitation step). Public signup stays disabled in Auth settings.
//
// Actions:
//   create        — needs CREATE_INVITATIONS ("créer des comptes joueurs")
//   set_password  — needs MANAGE_USERS
// Permissions are re-checked here against admin_users/admin_permissions,
// independently of what the calling app shows.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

// Logins without "@" are turned into an internal address so players can
// use a simple identifier. Must stay in sync with
// mobile/lib/core/utils/player_login.dart.
const PLAYER_LOGIN_DOMAIN = "joueurs.crashx.app";
const USERNAME_PATTERN = /^[a-z0-9._-]{3,30}$/;

function loginToEmail(login: string): string | null {
  const value = login.trim().toLowerCase();
  if (value.includes("@")) return value;
  return USERNAME_PATTERN.test(value) ? `${value}@${PLAYER_LOGIN_DOMAIN}` : null;
}

interface CreatePlayerBody {
  action?: "create" | "set_password";
  login?: string;
  password?: string;
  display_name?: string;
  max_devices?: number;
  user_id?: string;
}

async function hasPermission(
  admin: SupabaseClient,
  userId: string,
  permission: string,
): Promise<boolean> {
  const { data: caller } = await admin
    .from("admin_users")
    .select("role, is_active")
    .eq("id", userId)
    .maybeSingle();
  if (!caller || !caller.is_active) return false;
  if (caller.role === "SUPER_ADMIN") return true;

  const { data: granted } = await admin
    .from("admin_permissions")
    .select("permission")
    .eq("admin_id", userId)
    .eq("permission", permission)
    .maybeSingle();
  return !!granted;
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

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "ACCESS DENIED" }, 401);
  }
  const callerId = userData.user.id;

  let body: CreatePlayerBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "INVALID_BODY" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const action = body.action ?? "create";

  if (action === "set_password") {
    if (!(await hasPermission(admin, callerId, "MANAGE_USERS"))) {
      return jsonResponse({ error: "ACCESS DENIED" }, 403);
    }
    const { user_id, password } = body;
    if (!user_id || !password || password.length < 8) {
      return jsonResponse({ error: "INVALID_INPUT" }, 400);
    }

    // Only player accounts: staff passwords are never reset from here.
    const { data: staff } = await admin
      .from("admin_users")
      .select("id")
      .eq("id", user_id)
      .maybeSingle();
    if (staff) {
      return jsonResponse({ error: "ACCESS DENIED" }, 403);
    }

    const { error } = await admin.auth.admin.updateUserById(user_id, { password });
    if (error) {
      return jsonResponse({ error: "PASSWORD_UPDATE_FAILED", details: error.message }, 400);
    }

    await admin.from("admin_logs").insert({
      admin_id: callerId,
      action: "RESET_PLAYER_PASSWORD",
      target_type: "profiles",
      target_id: user_id,
      metadata: {},
    });
    return jsonResponse({ user_id });
  }

  if (action !== "create") {
    return jsonResponse({ error: "INVALID_ACTION" }, 400);
  }
  if (!(await hasPermission(admin, callerId, "CREATE_INVITATIONS"))) {
    return jsonResponse({ error: "ACCESS DENIED" }, 403);
  }

  const email = body.login ? loginToEmail(body.login) : null;
  const displayName = body.display_name?.trim();
  const maxDevices = Math.max(1, Math.floor(Number(body.max_devices ?? 1)) || 1);
  if (!email || !body.password || body.password.length < 8 || !displayName) {
    return jsonResponse({ error: "INVALID_INPUT" }, 400);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password: body.password,
    email_confirm: true,
    user_metadata: { display_name: displayName, max_devices: maxDevices },
  });

  if (createError || !created.user) {
    const alreadyExists = /already|registered|exists/i.test(createError?.message ?? "");
    return jsonResponse(
      {
        error: alreadyExists ? "LOGIN_ALREADY_USED" : "ACCOUNT_CREATION_FAILED",
        details: createError?.message,
      },
      400,
    );
  }

  await admin.from("admin_logs").insert({
    admin_id: callerId,
    action: "CREATE_PLAYER",
    target_type: "profiles",
    target_id: created.user.id,
    metadata: { login: body.login, display_name: displayName, max_devices: maxDevices },
  });

  return jsonResponse({ user_id: created.user.id, email });
});
