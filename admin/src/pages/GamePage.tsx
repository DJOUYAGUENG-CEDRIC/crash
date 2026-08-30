import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';
import { RoundStatusBadge } from '../components/Badge';
import { Button } from '../components/Button';
import { FieldWrapper, TextInput } from '../components/FormField';
import { ConfirmDialog } from '../components/ConfirmDialog';
import {
  getCurrentRound,
  getGameSettings,
  forceCrash,
  updateGameOperationalSettings,
} from '../services/game';
import type { GameRoundRow, GameSettingsRow } from '../types/database';
import { formatAmount, formatDate, formatMultiplier, formatRoundNumber } from '../lib/format';

export function GamePage() {
  const { hasPermission } = useAuth();
  const { showError, showSuccess } = useToast();

  const [round, setRound] = useState<GameRoundRow | null>(null);
  const [settings, setSettings] = useState<GameSettingsRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [confirmCrash, setConfirmCrash] = useState(false);
  const [crashing, setCrashing] = useState(false);

  const canControlGame = hasPermission('CONTROL_GAME');

  async function load() {
    try {
      const [r, s] = await Promise.all([getCurrentRound(), getGameSettings()]);
      setRound(r);
      setSettings(s);
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();

    const channel = supabase
      .channel('game_rounds_live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'game_rounds' }, (payload) => {
        const newRow = payload.new as GameRoundRow | undefined;
        if (newRow && 'id' in newRow) {
          setRound((prev) => (!prev || newRow.created_at >= prev.created_at ? newRow : prev));
        }
      })
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleForceCrash() {
    setCrashing(true);
    try {
      await forceCrash();
      showSuccess('La manche a été arrêtée.');
      setConfirmCrash(false);
      await load();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setCrashing(false);
    }
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Jeu</h1>
        <p className="text-sm text-zinc-500">Supervision et contrôle de la manche en cours.</p>
      </div>

      <div className="mb-6 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm font-semibold text-amber-400">
        CONTRÔLE DU JEU
      </div>

      {loading ? (
        <p className="text-sm text-zinc-500">Chargement…</p>
      ) : (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
            <h2 className="mb-4 text-sm font-semibold text-zinc-300">Manche en direct</h2>
            {round ? (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-2xl font-bold text-zinc-50">{formatRoundNumber(round.round_number)}</span>
                  <RoundStatusBadge status={round.status} />
                </div>

                {/* Admin-only visibility (VIEW_GAME): the exact crash point is
                    never exposed to players — see game_rounds_public /
                    spec §12. Kept prominent here since it's the whole
                    point of this permission. */}
                <div className="rounded-lg border border-amber-500/40 bg-amber-500/10 p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-amber-400">
                    Cote de crash programmée (visible admin uniquement)
                  </p>
                  <p className="mt-1 text-3xl font-bold text-amber-300">
                    {formatMultiplier(round.target_multiplier)}
                  </p>
                  <p className="mt-1 text-xs text-zinc-500">
                    Jamais visible par les joueurs — révélée dans l'app uniquement une fois la manche terminée.
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm">
                  <InfoRow label="Multiplicateur crash (révélé)" value={formatMultiplier(round.crash_multiplier)} />
                  <InfoRow label="Mode" value={round.demo_mode === 'MANUAL' ? 'Manuel' : 'Automatique'} />
                  <InfoRow label="Joueurs" value={String(round.total_players)} />
                  <InfoRow label="Total misé" value={formatAmount(round.total_bets_amount)} />
                  <InfoRow label="Débuté (paris)" value={formatDate(round.betting_started_at)} />
                </div>

                {canControlGame && (
                  <div className="pt-2">
                    <Button
                      variant="danger"
                      disabled={round.status !== 'RUNNING'}
                      onClick={() => setConfirmCrash(true)}
                    >
                      Arrêter la manche (force crash)
                    </Button>
                    {round.status !== 'RUNNING' && (
                      <p className="mt-1 text-xs text-zinc-600">
                        Disponible uniquement pendant qu'une manche est en cours (RUNNING).
                      </p>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <p className="text-sm text-zinc-500">Aucune manche trouvée.</p>
            )}
          </section>

          {canControlGame && settings && (
            <OperationalSettingsPanel
              settings={settings}
              onSaved={(s) => {
                setSettings(s);
                showSuccess('Paramètres du jeu mis à jour.');
              }}
              onError={showError}
            />
          )}
        </div>
      )}

      <ConfirmDialog
        open={confirmCrash}
        title="Arrêter la manche en cours"
        message="Cette action provoque immédiatement le crash de la manche en cours. Confirmez-vous ?"
        confirmLabel="Arrêter la manche"
        danger
        busy={crashing}
        onConfirm={() => void handleForceCrash()}
        onCancel={() => setConfirmCrash(false)}
      />
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-zinc-500">{label}</p>
      <p className="font-medium text-zinc-200">{value}</p>
    </div>
  );
}

function OperationalSettingsPanel({
  settings,
  onSaved,
  onError,
}: {
  settings: GameSettingsRow;
  onSaved: (s: GameSettingsRow) => void;
  onError: (msg: string) => void;
}) {
  const [bettingDuration, setBettingDuration] = useState(String(settings.betting_duration_seconds));
  const [minBet, setMinBet] = useState(String(settings.min_bet));
  const [maxBet, setMaxBet] = useState(String(settings.max_bet));
  const [houseEdge, setHouseEdge] = useState(String(settings.house_edge_percent));
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      await updateGameOperationalSettings({
        betting_duration_seconds: Number(bettingDuration),
        min_bet: Number(minBet),
        max_bet: Number(maxBet),
        house_edge_percent: Number(houseEdge),
      });
      onSaved({
        ...settings,
        betting_duration_seconds: Number(bettingDuration),
        min_bet: Number(minBet),
        max_bet: Number(maxBet),
        house_edge_percent: Number(houseEdge),
      });
    } catch (err) {
      onError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5 lg:col-span-2">
      <h2 className="mb-4 text-sm font-semibold text-zinc-300">Réglages opérationnels du jeu</h2>
      <form onSubmit={handleSubmit} className="grid grid-cols-1 gap-x-4 sm:grid-cols-2 lg:grid-cols-4">
        <FieldWrapper label="Durée des paris (secondes)">
          <TextInput type="number" min="1" value={bettingDuration} onChange={(e) => setBettingDuration(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Mise minimum (FCFA)">
          <TextInput type="number" min="0" step="1" value={minBet} onChange={(e) => setMinBet(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Mise maximum (FCFA)">
          <TextInput type="number" min="0" step="1" value={maxBet} onChange={(e) => setMaxBet(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Marge maison (%)">
          <TextInput type="number" min="0" step="0.1" value={houseEdge} onChange={(e) => setHouseEdge(e.target.value)} required />
        </FieldWrapper>
        <div className="sm:col-span-2 lg:col-span-4">
          <Button type="submit" variant="primary" disabled={saving}>
            {saving ? 'Enregistrement…' : 'Enregistrer les réglages'}
          </Button>
        </div>
      </form>
    </section>
  );
}
