import { supabase } from '../lib/supabase';
import type { GameRoundRow, GameSettingsRow } from '../types/database';

export async function getCurrentRound(): Promise<GameRoundRow | null> {
  const { data, error } = await supabase
    .from('game_rounds')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/** Admin-only rounds, including the server-generated target multiplier. */
export async function getCrashSchedule(limit = 25): Promise<GameRoundRow[]> {
  const { data, error } = await supabase
    .from('game_rounds')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data ?? [];
}

export async function getGameSettings(): Promise<GameSettingsRow | null> {
  const { data, error } = await supabase.from('game_settings').select('*').eq('id', 1).maybeSingle();
  if (error) throw error;
  return data;
}

export async function forceCrash(): Promise<void> {
  const { error } = await supabase.rpc('admin_force_crash');
  if (error) throw error;
}

export async function updateGameOperationalSettings(params: {
  betting_duration_seconds: number;
  min_bet: number;
  max_bet: number;
  house_edge_percent: number;
}): Promise<void> {
  const { error } = await supabase.rpc('update_game_operational_settings', {
    p_betting_duration_seconds: params.betting_duration_seconds,
    p_min_bet: params.min_bet,
    p_max_bet: params.max_bet,
    p_house_edge_percent: params.house_edge_percent,
  });
  if (error) throw error;
}
