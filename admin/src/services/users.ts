import { supabase } from '../lib/supabase';
import type { BetRow, ProfileRow, TransactionRow } from '../types/database';

export interface UserWithWallet extends ProfileRow {
  balance: number;
  last_device_activity: string | null;
}

export async function listUsersWithWallets(): Promise<UserWithWallet[]> {
  const [{ data: profiles, error: profilesError }, { data: wallets, error: walletsError }, { data: devices, error: devicesError }] =
    await Promise.all([
      supabase.from('profiles').select('*').order('created_at', { ascending: false }),
      supabase.from('wallets').select('user_id, balance'),
      supabase.from('authorized_devices').select('user_id, last_seen'),
    ]);

  if (profilesError) throw profilesError;
  if (walletsError) throw walletsError;
  if (devicesError) throw devicesError;

  const balanceByUser = new Map<string, number>();
  for (const w of wallets ?? []) balanceByUser.set(w.user_id, w.balance);

  const lastSeenByUser = new Map<string, string>();
  for (const d of devices ?? []) {
    const current = lastSeenByUser.get(d.user_id);
    if (!current || new Date(d.last_seen) > new Date(current)) {
      lastSeenByUser.set(d.user_id, d.last_seen);
    }
  }

  return (profiles ?? []).map((p) => ({
    ...p,
    balance: balanceByUser.get(p.id) ?? 0,
    last_device_activity: lastSeenByUser.get(p.id) ?? null,
  }));
}

export async function getUserTransactions(userId: string): Promise<TransactionRow[]> {
  const { data, error } = await supabase
    .from('transactions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(100);
  if (error) throw error;
  return data ?? [];
}

export async function getUserBets(userId: string): Promise<BetRow[]> {
  const { data, error } = await supabase
    .from('bets')
    .select('*')
    .eq('user_id', userId)
    .order('placed_at', { ascending: false })
    .limit(100);
  if (error) throw error;
  return data ?? [];
}

export async function blockUser(userId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_block_user', { p_user_id: userId });
  if (error) throw error;
}

export async function unblockUser(userId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_unblock_user', { p_user_id: userId });
  if (error) throw error;
}

export async function adjustBalance(userId: string, amount: number, reason: string): Promise<void> {
  const { error } = await supabase.rpc('admin_adjust_balance', {
    p_user_id: userId,
    p_amount: amount,
    p_reason: reason,
  });
  if (error) throw error;
}
