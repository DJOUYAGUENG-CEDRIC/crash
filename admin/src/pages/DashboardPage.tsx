import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { StatCard } from '../components/StatCard';
import { RoundStatusBadge } from '../components/Badge';
import { getDashboardOverview } from '../services/dashboard';
import type { DashboardOverview } from '../services/dashboard';
import { getCurrentRound } from '../services/game';
import type { GameRoundRow } from '../types/database';
import { formatAmount, formatMultiplier, formatRoundNumber } from '../lib/format';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';

const QUICK_LINKS = [
  { to: '/game', label: 'Contrôler le jeu', icon: '🚀', permission: 'VIEW_GAME' as const },
  { to: '/users', label: 'Gérer les utilisateurs', icon: '👥', permission: 'VIEW_USERS' as const },
  { to: '/invitations', label: 'Invitations', icon: '✉️', permission: 'VIEW_USERS' as const },
  { to: '/statistics', label: 'Statistiques', icon: '📈', permission: 'VIEW_STATISTICS' as const },
];

export function DashboardPage() {
  const { hasPermission } = useAuth();
  const { showError } = useToast();
  const [overview, setOverview] = useState<DashboardOverview | null>(null);
  const [round, setRound] = useState<GameRoundRow | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    async function load() {
      try {
        const [ov, r] = await Promise.all([getDashboardOverview(), getCurrentRound()]);
        if (!mounted) return;
        setOverview(ov);
        setRound(r);
      } catch (err) {
        showError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    }
    void load();
    return () => {
      mounted = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Tableau de bord</h1>
        <p className="text-sm text-zinc-500">Vue d'ensemble de CRASH.</p>
      </div>

      {loading ? (
        <div className="text-sm text-zinc-500">Chargement des indicateurs…</div>
      ) : (
        <>
          <div className="mb-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-4 shadow-sm sm:col-span-2 lg:col-span-1">
              <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">Manche actuelle</p>
              {round ? (
                <>
                  <div className="mt-2 flex items-center gap-2">
                    <span className="text-lg font-semibold text-zinc-50">{formatRoundNumber(round.round_number)}</span>
                    <RoundStatusBadge status={round.status} />
                  </div>
                  <p className="mt-1 text-xs text-zinc-500">
                    Multiplicateur: {formatMultiplier(round.crash_multiplier ?? round.target_multiplier)}
                  </p>
                </>
              ) : (
                <p className="mt-2 text-sm text-zinc-500">Aucune manche trouvée</p>
              )}
            </div>

            <StatCard
              label="Joueurs actifs (aujourd'hui)"
              value={overview?.activePlayersToday ?? 0}
              icon="👥"
              accent="blue"
            />
            <StatCard
              label="Invitations en attente"
              value={overview?.pendingInvitations ?? 0}
              icon="✉️"
              accent="amber"
            />
            <StatCard
              label="Total misé (aujourd'hui)"
              value={formatAmount(overview?.totalWageredToday ?? 0)}
              icon="🎲"
              accent="violet"
            />
            <StatCard
              label="Total payé (aujourd'hui)"
              value={formatAmount(overview?.totalPaidOutToday ?? 0)}
              icon="💸"
              accent="green"
            />
            <StatCard
              label="Appareils actifs"
              value={overview?.activeDevices ?? 0}
              icon="📱"
              accent="blue"
            />
          </div>
        </>
      )}

      <div className="mt-8">
        <h2 className="mb-3 text-sm font-semibold text-zinc-300">Accès rapide</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {QUICK_LINKS.filter((l) => hasPermission(l.permission)).map((link) => (
            <Link
              key={link.to}
              to={link.to}
              className="flex flex-col items-center gap-2 rounded-lg border border-zinc-800 bg-zinc-900/50 px-4 py-5 text-center text-sm font-medium text-zinc-300 transition-colors hover:border-violet-500/40 hover:bg-zinc-900 hover:text-violet-300"
            >
              <span className="text-xl">{link.icon}</span>
              {link.label}
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
