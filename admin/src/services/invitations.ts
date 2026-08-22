import { supabase } from '../lib/supabase';
import type { InvitationRow } from '../types/database';

export async function listInvitations(): Promise<InvitationRow[]> {
  const { data, error } = await supabase
    .from('invitations')
    .select('*')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function createInvitation(params: {
  invited_name: string;
  invited_email?: string | null;
  expires_hours?: number;
  max_devices?: number;
}): Promise<InvitationRow> {
  const { data, error } = await supabase.rpc('create_invitation', {
    p_invited_name: params.invited_name,
    p_invited_email: params.invited_email ?? null,
    p_expires_hours: params.expires_hours ?? 24,
    p_max_devices: params.max_devices ?? 1,
  });
  if (error) throw error;
  return data as InvitationRow;
}

export async function revokeInvitation(invitationId: string): Promise<void> {
  const { error } = await supabase.rpc('revoke_invitation', { p_invitation_id: invitationId });
  if (error) throw error;
}
