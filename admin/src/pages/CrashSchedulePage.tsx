import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { errorMessage, useToast } from '../context/ToastContext';
import { formatDate, formatMultiplier, formatRoundNumber } from '../lib/format';
import { getCrashSchedule } from '../services/game';
import type { GameRoundRow } from '../types/database';

const growthRate = 0.06;

function timeUntilCrash(target: number | null): string {
  if (target === null || target <= 1) return 'Immédiat';
  const seconds = Math.ceil(Math.log(target) / growthRate);
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return minutes > 0 ? `${minutes} min ${remainder.toString().padStart(2, '0')} s` : `${seconds} s`;
}

export function CrashSchedulePage() {
  const { showError } = useToast();
  const [rounds, setRounds] = useState<GameRoundRow[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    try {
      setRounds(await getCrashSchedule());
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    const channel = supabase
      .channel('crash_schedule_live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'game_rounds' }, () => void load())
      .subscribe();
    return () => void supabase.removeChannel(channel);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const liveRound = rounds.find((round) => !['CRASHED', 'RESULT'].includes(round.status));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Crashes prévus</h1>
        <p className="text-sm text-zinc-500">
          Les cotes sont générées automatiquement par le serveur. Cette vue est réservée aux administrateurs autorisés.
        </p>
      </div>

      {liveRound && (
        <section className="mb-6 rounded-xl border border-amber-500/40 bg-amber-500/10 p-5">
          <p className="text-xs font-semibold uppercase tracking-wide text-amber-400">Manche active</p>
          <div className="mt-2 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p className="text-sm text-zinc-400">{formatRoundNumber(liveRound.round_number)} · {liveRound.status}</p>
              <p className="text-4xl font-bold text-amber-300">{formatMultiplier(liveRound.target_multiplier)}</p>
            </div>
            <p className="text-sm text-amber-100">
              Crash prévu environ <span className="font-bold">{timeUntilCrash(liveRound.target_multiplier)}</span> après le décollage.
            </p>
          </div>
        </section>
      )}

      <section className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/60">
        <div className="border-b border-zinc-800 px-5 py-4">
          <h2 className="text-sm font-semibold text-zinc-200">25 dernières manches</h2>
        </div>
        {loading ? (
          <p className="px-5 py-6 text-sm text-zinc-500">Chargement…</p>
        ) : rounds.length === 0 ? (
          <p className="px-5 py-6 text-sm text-zinc-500">Aucune manche disponible.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-zinc-950/40 text-xs uppercase tracking-wide text-zinc-500">
                <tr>
                  <th className="px-5 py-3 font-medium">Manche</th><th className="px-5 py-3 font-medium">État</th><th className="px-5 py-3 font-medium">Cote générée</th><th className="px-5 py-3 font-medium">Temps après décollage</th><th className="px-5 py-3 font-medium">Créée le</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800 text-zinc-300">
                {rounds.map((round) => (
                  <tr key={round.id}>
                    <td className="px-5 py-3 font-medium text-zinc-100">{formatRoundNumber(round.round_number)}</td><td className="px-5 py-3">{round.status}</td><td className="px-5 py-3 font-semibold text-amber-300">{formatMultiplier(round.target_multiplier)}</td><td className="px-5 py-3">{timeUntilCrash(round.target_multiplier)}</td><td className="px-5 py-3 text-zinc-500">{formatDate(round.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
