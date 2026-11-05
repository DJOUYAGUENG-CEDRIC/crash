import { supabase } from '../lib/supabase';

export interface DashboardOverview {
  activePlayersToday: number;
  totalWageredToday: number;
  totalPaidOutToday: number;
  registeredPlayers: number;
  activeDevices: number;
}

function startOfTodayIso(): string {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}

export async function getDashboardOverview(): Promise<DashboardOverview> {
  const todayStart = startOfTodayIso();

  const [betsToday, cashoutsToday, invitations, devices] = await Promise.all([
    supabase.from('bets').select('user_id, amount').gte('placed_at', todayStart),
    supabase.from('transactions').select('amount').eq('type', 'CASHOUT').gte('created_at', todayStart),
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('authorized_devices').select('id', { count: 'exact', head: true }).eq('status', 'ACTIVE'),
  ]);

  if (betsToday.error) throw betsToday.error;
  if (cashoutsToday.error) throw cashoutsToday.error;
  if (invitations.error) throw invitations.error;
  if (devices.error) throw devices.error;

  const uniquePlayers = new Set((betsToday.data ?? []).map((b) => b.user_id));
  const totalWagered = (betsToday.data ?? []).reduce((sum, b) => sum + Number(b.amount), 0);
  const totalPaidOut = (cashoutsToday.data ?? []).reduce((sum, t) => sum + Math.abs(Number(t.amount)), 0);

  return {
    activePlayersToday: uniquePlayers.size,
    totalWageredToday: totalWagered,
    totalPaidOutToday: totalPaidOut,
    registeredPlayers: invitations.count ?? 0,
    activeDevices: devices.count ?? 0,
  };
}
