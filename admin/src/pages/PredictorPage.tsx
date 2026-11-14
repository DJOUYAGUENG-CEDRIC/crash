import { useCallback, useEffect, useState } from 'react';
import { errorMessage } from '../context/ToastContext';
import { supabase } from '../lib/supabase';
import type { DemoRoundPredictionRow } from '../types/database';

const backgroundColors = ['#e53935', '#7e57c2', '#1e88e5', '#fb8c00'];
const backgroundColorChangeInterval = 5 * 60 * 1000;

function isFinished(status: DemoRoundPredictionRow['status']): boolean {
  return status === 'CRASHED' || status === 'RESULT';
}

function getMultiplier(round: DemoRoundPredictionRow): number {
  if (isFinished(round.status) && round.crash_multiplier !== null) {
    return Number(round.crash_multiplier);
  }
  return Number(round.target_multiplier);
}

export function PredictorPage() {
  const [round, setRound] = useState<DemoRoundPredictionRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [backgroundColorIndex, setBackgroundColorIndex] = useState(0);

  useEffect(() => {
    document.title = 'CRASHX';
  }, []);

  useEffect(() => {
    const startedAt = Date.now();

    function updateBackgroundColor() {
      const elapsedIntervals = Math.floor(
        (Date.now() - startedAt) / backgroundColorChangeInterval,
      );
      setBackgroundColorIndex(elapsedIntervals % backgroundColors.length);
    }

    const timer = window.setInterval(
      updateBackgroundColor,
      backgroundColorChangeInterval,
    );
    document.addEventListener('visibilitychange', updateBackgroundColor);

    return () => {
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', updateBackgroundColor);
    };
  }, []);

  const loadCurrentRound = useCallback(async () => {
    const { data, error: queryError } = await supabase
      .from('demo_round_predictions')
      .select('*')
      .order('round_number', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (queryError) throw queryError;
    return data;
  }, []);

  useEffect(() => {
    let active = true;
    let refreshing = false;
    let refreshRequested = false;

    async function refresh() {
      if (refreshing) {
        refreshRequested = true;
        return;
      }
      refreshing = true;
      try {
        const currentRound = await loadCurrentRound();
        if (active) {
          if (currentRound && Number.isFinite(getMultiplier(currentRound))) {
            setRound(currentRound);
          }
          setError(null);
        }
      } catch (loadError) {
        if (active) setError(errorMessage(loadError));
      } finally {
        refreshing = false;
        if (active && refreshRequested) {
          refreshRequested = false;
          void refresh();
        }
      }
    }

    function refreshWhenVisible() {
      if (document.visibilityState === 'visible') void refresh();
    }

    void refresh();
    const timer = window.setInterval(() => void refresh(), 3000);
    document.addEventListener('visibilitychange', refreshWhenVisible);
    window.addEventListener('online', refreshWhenVisible);
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
        if (active && status === 'SUBSCRIBED') void refresh();
      });

    return () => {
      active = false;
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', refreshWhenVisible);
      window.removeEventListener('online', refreshWhenVisible);
      void supabase.removeChannel(channel);
    };
  }, [loadCurrentRound]);

  return (
    <main
      className="flex h-screen min-h-screen w-full items-center justify-center text-white transition-colors duration-500"
      style={{ backgroundColor: backgroundColors[backgroundColorIndex] }}
    >
      {round ? (
        <h1 className="m-0 text-[clamp(5rem,24vw,10rem)] font-black leading-none tracking-[-0.07em] tabular-nums">
          {getMultiplier(round).toFixed(2)}x
        </h1>
      ) : (
        <span className="sr-only">{error ?? 'Aucune cote disponible'}</span>
      )}
      {error && <span role="alert" className="sr-only">{error}</span>}
    </main>
  );
}
