import { supabase } from '../lib/supabase';

const DAYS_BACK = 14;
const HISTORY_ROW_LIMIT = 3000;

function daysAgoIso(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}

function dayKey(iso: string): string {
  return iso.slice(0, 10); // YYYY-MM-DD
}

export interface DailyPoint {
  date: string;
  rounds: number;
}

export interface WageredVsPaidPoint {
  date: string;
  wagered: number;
  paidOut: number;
}

export interface MultiplierBucket {
  bucket: string;
  count: number;
}

export interface TopPlayer {
  userId: string;
  displayName: string;
  totalWagered: number;
}

export interface StatisticsData {
  roundsPerDay: DailyPoint[];
  wageredVsPaid: WageredVsPaidPoint[];
  multiplierBuckets: MultiplierBucket[];
  topPlayers: TopPlayer[];
}

function buildDayScaffold(): string[] {
  const days: string[] = [];
  for (let i = DAYS_BACK - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push(d.toISOString().slice(0, 10));
  }
  return days;
}

const BUCKET_DEFS: { label: string; min: number; max: number }[] = [
  { label: '1.00–1.49x', min: 1, max: 1.5 },
  { label: '1.50–1.99x', min: 1.5, max: 2 },
  { label: '2.00–2.99x', min: 2, max: 3 },
  { label: '3.00–4.99x', min: 3, max: 5 },
  { label: '5.00–9.99x', min: 5, max: 10 },
  { label: '10x+', min: 10, max: Infinity },
];

export async function getStatistics(): Promise<StatisticsData> {
  const since = daysAgoIso(DAYS_BACK);

  const [roundsRes, betsRes, cashoutsRes, profilesRes] = await Promise.all([
    supabase
      .from('game_rounds')
      .select('created_at, status, crash_multiplier')
      .gte('created_at', since)
      .limit(HISTORY_ROW_LIMIT),
    supabase.from('bets').select('user_id, amount, placed_at').gte('placed_at', since).limit(HISTORY_ROW_LIMIT),
    supabase
      .from('transactions')
      .select('amount, created_at')
      .eq('type', 'CASHOUT')
      .gte('created_at', since)
      .limit(HISTORY_ROW_LIMIT),
    supabase.from('profiles').select('id, display_name, email'),
  ]);

  if (roundsRes.error) throw roundsRes.error;
  if (betsRes.error) throw betsRes.error;
  if (cashoutsRes.error) throw cashoutsRes.error;
  if (profilesRes.error) throw profilesRes.error;

  const dayScaffold = buildDayScaffold();

  // Rounds per day
  const roundsByDay = new Map<string, number>();
  for (const day of dayScaffold) roundsByDay.set(day, 0);
  for (const r of roundsRes.data ?? []) {
    const key = dayKey(r.created_at);
    if (roundsByDay.has(key)) roundsByDay.set(key, (roundsByDay.get(key) ?? 0) + 1);
  }
  const roundsPerDay: DailyPoint[] = dayScaffold.map((date) => ({ date, rounds: roundsByDay.get(date) ?? 0 }));

  // Wagered vs paid out per day
  const wageredByDay = new Map<string, number>();
  const paidByDay = new Map<string, number>();
  for (const day of dayScaffold) {
    wageredByDay.set(day, 0);
    paidByDay.set(day, 0);
  }
  for (const b of betsRes.data ?? []) {
    const key = dayKey(b.placed_at);
    if (wageredByDay.has(key)) wageredByDay.set(key, (wageredByDay.get(key) ?? 0) + Number(b.amount));
  }
  for (const t of cashoutsRes.data ?? []) {
    const key = dayKey(t.created_at);
    if (paidByDay.has(key)) paidByDay.set(key, (paidByDay.get(key) ?? 0) + Math.abs(Number(t.amount)));
  }
  const wageredVsPaid: WageredVsPaidPoint[] = dayScaffold.map((date) => ({
    date,
    wagered: wageredByDay.get(date) ?? 0,
    paidOut: paidByDay.get(date) ?? 0,
  }));

  // Multiplier distribution (CRASHED/RESULT rounds only)
  const bucketCounts = new Map<string, number>(BUCKET_DEFS.map((b) => [b.label, 0]));
  for (const r of roundsRes.data ?? []) {
    if (r.status !== 'CRASHED' && r.status !== 'RESULT') continue;
    if (r.crash_multiplier === null) continue;
    const m = Number(r.crash_multiplier);
    const bucket = BUCKET_DEFS.find((b) => m >= b.min && m < b.max);
    if (bucket) bucketCounts.set(bucket.label, (bucketCounts.get(bucket.label) ?? 0) + 1);
  }
  const multiplierBuckets: MultiplierBucket[] = BUCKET_DEFS.map((b) => ({
    bucket: b.label,
    count: bucketCounts.get(b.label) ?? 0,
  }));

  // Top players by total wagered
  const nameById = new Map<string, string>();
  for (const p of profilesRes.data ?? []) nameById.set(p.id, p.display_name ?? p.email);
  const wageredByUser = new Map<string, number>();
  for (const b of betsRes.data ?? []) {
    wageredByUser.set(b.user_id, (wageredByUser.get(b.user_id) ?? 0) + Number(b.amount));
  }
  const topPlayers: TopPlayer[] = Array.from(wageredByUser.entries())
    .map(([userId, totalWagered]) => ({ userId, totalWagered, displayName: nameById.get(userId) ?? 'Utilisateur' }))
    .sort((a, b) => b.totalWagered - a.totalWagered)
    .slice(0, 10);

  return { roundsPerDay, wageredVsPaid, multiplierBuckets, topPlayers };
}
