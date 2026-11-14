import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { errorMessage } from '../context/ToastContext';
import { supabase } from '../lib/supabase';
import type { DemoRoundPredictionRow } from '../types/database';

function isFinished(status: DemoRoundPredictionRow['status']): boolean {
  return status === 'CRASHED' || status === 'RESULT';
}

function statusLabel(status: DemoRoundPredictionRow['status']): string {
  switch (status) {
    case 'WAITING':
      return 'En attente';
    case 'BETTING':
      return 'Paris ouverts';
    case 'RUNNING':
      return 'Tour en cours';
    case 'CRASHED':
      return 'Tour terminé';
    case 'RESULT':
      return 'Résultat';
  }
}

function displayedMultiplier(round: DemoRoundPredictionRow): number {
  if (isFinished(round.status) && round.crash_multiplier !== null) {
    return Number(round.crash_multiplier);
  }
  return Number(round.target_multiplier);
}

export function PredictorPage() {
  const { session } = useAuth();
  const [round, setRound] = useState<DemoRoundPredictionRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const previousTitle = document.title;
    document.title = 'CRASHX — Cote du tour';
    return () => {
      document.title = previousTitle;
    };
  }, []);

  const loadCurrentRound = useCallback(async (): Promise<DemoRoundPredictionRow | null> => {
    const { data, error: queryError } = await supabase
      .from('demo_round_predictions')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (queryError) throw queryError;
    return data;
  }, []);

  useEffect(() => {
    let active = true;
    let refreshing = false;

    async function refresh() {
      if (refreshing) return;
      refreshing = true;
      try {
        const currentRound = await loadCurrentRound();
        if (active) {
          setRound(currentRound);
          setError(null);
        }
      } catch (loadError) {
        if (active) setError(errorMessage(loadError));
      } finally {
        refreshing = false;
        if (active) setLoading(false);
      }
    }

    void refresh();
    const refreshTimer = window.setInterval(() => void refresh(), 3000);
    const channel = supabase
      .channel('current-demo-round-prediction')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'demo_round_predictions' },
        () => {
          if (active) void refresh();
        },
      )
      .subscribe((status) => {
        if (active && status === 'CHANNEL_ERROR') {
          setError('Connexion en direct interrompue ; actualisation automatique en cours.');
        }
      });

    return () => {
      active = false;
      window.clearInterval(refreshTimer);
      void supabase.removeChannel(channel);
    };
  }, [loadCurrentRound]);

  const finished = round ? isFinished(round.status) : false;

  return (
    <main className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-[#078a43] px-5 py-12 text-white">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_center,_rgba(91,255,162,0.2),_transparent_62%)]"
      />

      <header className="absolute left-0 right-0 top-0 flex items-center justify-between gap-3 px-5 py-5 sm:px-8">
        <a href="/predictor" className="text-sm font-black tracking-[0.24em] text-white">
          CRASH<span className="text-[#b9ffcf]">X</span>
        </a>
        <div className="flex items-center gap-3">
          <span className="hidden text-xs text-white/75 sm:inline">{session?.user.email}</span>
          <button
            type="button"
            onClick={() => void supabase.auth.signOut()}
            className="rounded-full border border-white/25 bg-black/10 px-3 py-1.5 text-[10px] font-bold tracking-[0.08em] text-white/90 hover:bg-white/10"
          >
            Déconnexion
          </button>
        </div>
      </header>

      <section className="relative flex w-full max-w-xl flex-col items-center text-center">
        {loading ? (
          <p className="text-sm font-medium text-white/80">Chargement de la cote…</p>
        ) : round ? (
          <>
            <p className="text-sm font-semibold uppercase tracking-[0.22em] text-white/75">
              Tour n° {round.round_number}
            </p>
            <p className="mt-8 text-xs font-bold uppercase tracking-[0.3em] text-white/70">
              {finished ? 'Cote du crash' : 'Cote prévue'}
            </p>
            <h1 className="mt-2 text-[clamp(5rem,24vw,10rem)] font-black leading-none tracking-[-0.07em] tabular-nums drop-shadow-[0_8px_24px_rgba(0,0,0,0.15)]">
              {displayedMultiplier(round).toFixed(2)}x
            </h1>
            <span className="mt-7 inline-flex items-center gap-2 rounded-full border border-white/25 bg-black/10 px-4 py-2 text-xs font-semibold text-white/90">
              {!finished && (
                <span className="h-2 w-2 animate-pulse rounded-full bg-[#b9ffcf]" />
              )}
              {statusLabel(round.status)}
            </span>
            {round.status === 'RUNNING' && (
              <p className="mt-5 max-w-sm text-xs leading-5 text-white/65">
                Cote programmée pour la démonstration. Un arrêt manuel peut provoquer un crash plus tôt.
              </p>
            )}
          </>
        ) : (
          <div className="max-w-sm">
            <h1 className="text-xl font-bold">Aucun tour disponible</h1>
            <p className="mt-2 text-sm leading-6 text-white/75">
              La page se met à jour automatiquement dès que le serveur crée le prochain tour.
            </p>
          </div>
        )}

        {error && (
          <p
            role="alert"
            className="mt-6 max-w-md rounded-lg border border-white/25 bg-black/20 px-4 py-3 text-xs leading-5 text-white"
          >
            {error}
          </p>
        )}
      </section>

      <footer className="absolute bottom-5 px-5 text-center text-[10px] tracking-wide text-white/60">
        Démonstration CRASHX — argent virtuel uniquement
      </footer>
    </main>
  );
}
