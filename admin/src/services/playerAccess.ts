import { supabase } from '../lib/supabase';

export async function hasActivePlayerProfile(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('profiles')
    .select('status')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  return data?.status === 'ACTIVE';
}
