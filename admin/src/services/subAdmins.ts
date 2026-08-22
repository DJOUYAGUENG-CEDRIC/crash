import { supabase } from '../lib/supabase';
import type { AdminPermission, AdminUserRow } from '../types/database';

export interface SubAdminWithPermissions extends AdminUserRow {
  granted_permissions: AdminPermission[];
}

export async function listSubAdmins(): Promise<SubAdminWithPermissions[]> {
  const [{ data: admins, error: adminsError }, { data: perms, error: permsError }] = await Promise.all([
    supabase.from('admin_users').select('*').eq('role', 'SOUS_ADMIN').order('created_at', { ascending: false }),
    supabase.from('admin_permissions').select('admin_id, permission'),
  ]);

  if (adminsError) throw adminsError;
  if (permsError) throw permsError;

  const permsByAdmin = new Map<string, AdminPermission[]>();
  for (const p of perms ?? []) {
    const list = permsByAdmin.get(p.admin_id) ?? [];
    list.push(p.permission);
    permsByAdmin.set(p.admin_id, list);
  }

  return (admins ?? []).map((a) => ({ ...a, granted_permissions: permsByAdmin.get(a.id) ?? [] }));
}

export async function createSubAdmin(params: {
  email: string;
  password: string;
  display_name: string;
}): Promise<{ admin_id: string }> {
  const { data, error } = await supabase.functions.invoke<{ admin_id: string }>('create-sub-admin', {
    body: params,
  });
  if (error) throw error;
  if (!data) throw new Error("Réponse invalide du serveur lors de la création du sous-compte.");
  return data;
}

export async function setSubAdminPermissions(adminId: string, permissions: AdminPermission[]): Promise<void> {
  const { error } = await supabase.rpc('set_sub_admin_permissions', {
    p_admin_id: adminId,
    p_permissions: permissions,
  });
  if (error) throw error;
}

export async function updateSubAdmin(adminId: string, displayName: string): Promise<void> {
  const { error } = await supabase.rpc('admin_update_sub', {
    p_admin_id: adminId,
    p_display_name: displayName,
  });
  if (error) throw error;
}

export async function deactivateSubAdmin(adminId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_deactivate_sub', { p_admin_id: adminId });
  if (error) throw error;
}

export async function reactivateSubAdmin(adminId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_reactivate_sub', { p_admin_id: adminId });
  if (error) throw error;
}

export async function deleteSubAdmin(adminId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_delete_sub', { p_admin_id: adminId });
  if (error) throw error;
}
