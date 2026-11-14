import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { hasActivePlayerProfile } from '../services/playerAccess';

interface PlayerProtectedRouteProps {
  children: ReactNode;
}

export function PlayerProtectedRoute({ children }: PlayerProtectedRouteProps) {
  const { session, loading } = useAuth();
  const [verifiedUserId, setVerifiedUserId] = useState<string | null>(null);
  const [deniedUserId, setDeniedUserId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const userId = session?.user.id ?? null;

  useEffect(() => {
    let active = true;

    async function verifyPlayer() {
      if (!userId) return;
      try {
        const isPlayer = await hasActivePlayerProfile(userId);
        if (!active) return;
        if (isPlayer) {
          setVerifiedUserId(userId);
          setDeniedUserId(null);
          setError(null);
        } else {
          setDeniedUserId(userId);
          setVerifiedUserId(null);
          await supabase.auth.signOut();
        }
      } catch {
        if (active) {
          setError('Impossible de vérifier le compte. Vérifiez votre connexion puis réessayez.');
        }
      }
    }

    if (!loading && userId) void verifyPlayer();

    return () => {
      active = false;
    };
  }, [loading, retry, userId]);

  if (loading) {
    return <PlayerGateMessage>Vérification de la connexion…</PlayerGateMessage>;
  }
  if (!session) return <Navigate to="/player-login" replace />;
  if (error) {
    return (
      <PlayerGateMessage>
        <p role="alert">{error}</p>
        <button
          type="button"
          onClick={() => {
            setError(null);
            setRetry((value) => value + 1);
          }}
          className="mt-4 rounded-full border border-white/40 px-4 py-2 text-sm font-semibold text-white hover:bg-white/10"
        >
          Réessayer
        </button>
      </PlayerGateMessage>
    );
  }
  if (deniedUserId === userId) {
    return <Navigate to="/player-login" replace state={{ denied: true }} />;
  }
  if (verifiedUserId !== userId) {
    return <PlayerGateMessage>Vérification du compte joueur…</PlayerGateMessage>;
  }

  return <>{children}</>;
}

function PlayerGateMessage({ children }: { children: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#078a43] px-5 text-center text-sm font-medium text-white">
      <div>{children}</div>
    </main>
  );
}
