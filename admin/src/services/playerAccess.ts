import { supabase } from '../lib/supabase';

export const PLAYER_LOGIN_DOMAIN = 'joueurs.crashx.app';

const PLAYER_IDENTIFIER_PATTERN = /^[a-z0-9._-]{3,30}$/;

export function normalizePlayerLogin(login: string): string | null {
  const value = login.trim().toLowerCase();
  if (value.includes('@')) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? value : null;
  }
  return PLAYER_IDENTIFIER_PATTERN.test(value)
    ? `${value}@${PLAYER_LOGIN_DOMAIN}`
    : null;
}

export async function hasActivePlayerProfile(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('profiles')
    .select('status')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  return data?.status === 'ACTIVE';
}
