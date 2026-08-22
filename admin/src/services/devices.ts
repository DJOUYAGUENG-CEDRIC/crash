import { supabase } from '../lib/supabase';
import type { AuthorizedDeviceRow, DeviceStatus, ProfileRow } from '../types/database';

export interface DeviceWithOwner extends AuthorizedDeviceRow {
  owner_display_name: string | null;
  owner_email: string | null;
}

export async function listDevicesWithOwners(): Promise<DeviceWithOwner[]> {
  const [{ data: devices, error: devicesError }, { data: profiles, error: profilesError }] = await Promise.all([
    supabase.from('authorized_devices').select('*').order('last_seen', { ascending: false }),
    supabase.from('profiles').select('id, display_name, email'),
  ]);

  if (devicesError) throw devicesError;
  if (profilesError) throw profilesError;

  const profileById = new Map<string, Pick<ProfileRow, 'display_name' | 'email'>>();
  for (const p of profiles ?? []) profileById.set(p.id, { display_name: p.display_name, email: p.email });

  return (devices ?? []).map((d) => ({
    ...d,
    owner_display_name: profileById.get(d.user_id)?.display_name ?? null,
    owner_email: profileById.get(d.user_id)?.email ?? null,
  }));
}

export async function setDeviceStatus(deviceId: string, status: DeviceStatus): Promise<void> {
  const { error } = await supabase.rpc('admin_set_device_status', {
    p_device_id: deviceId,
    p_status: status,
  });
  if (error) throw error;
}
