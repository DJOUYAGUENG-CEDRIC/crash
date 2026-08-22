import { supabase } from '../lib/supabase';
import type { AppSettingsRow } from '../types/database';

export async function getAppSettings(): Promise<AppSettingsRow | null> {
  const { data, error } = await supabase.from('app_settings').select('*').eq('id', 1).maybeSingle();
  if (error) throw error;
  return data;
}

export async function updateAppSettings(params: {
  current_version: string;
  minimum_supported_version: string;
  download_url: string;
  maintenance_mode: boolean;
}): Promise<void> {
  const { error } = await supabase.rpc('update_app_settings', {
    p_current_version: params.current_version,
    p_minimum_supported_version: params.minimum_supported_version,
    p_download_url: params.download_url,
    p_maintenance_mode: params.maintenance_mode,
  });
  if (error) throw error;
}
