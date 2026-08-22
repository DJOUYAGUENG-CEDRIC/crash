import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';
import { Button } from '../components/Button';
import { FieldWrapper, TextInput } from '../components/FormField';
import { getGameSettings } from '../services/game';
import { getAppSettings, updateAppSettings } from '../services/settings';
import type { GameSettingsRow, AppSettingsRow } from '../types/database';
import { formatAmount, formatDate } from '../lib/format';

export function SettingsPage() {
  const { isSuperAdmin, hasPermission } = useAuth();
  const { showError, showSuccess } = useToast();
  const [gameSettings, setGameSettings] = useState<GameSettingsRow | null>(null);
  const [appSettings, setAppSettings] = useState<AppSettingsRow | null>(null);
  const [loading, setLoading] = useState(true);

  const canControlGame = hasPermission('CONTROL_GAME') || hasPermission('CONTROL_DEMO_MULTIPLIER');

  async function load() {
    setLoading(true);
    try {
      const [g, a] = await Promise.all([getGameSettings(), getAppSettings()]);
      setGameSettings(g);
      setAppSettings(a);
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Paramètres</h1>
        <p className="text-sm text-zinc-500">Configuration du jeu démo et de l'application mobile.</p>
      </div>

      {loading ? (
        <p className="text-sm text-zinc-500">Chargement…</p>
      ) : (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-zinc-300">Paramètres du jeu (démo)</h2>
              {canControlGame && (
                <Link to="/game" className="text-xs text-violet-400 hover:underline">
                  Modifier sur la page Jeu →
                </Link>
              )}
            </div>
            {gameSettings ? (
              <div className="grid grid-cols-2 gap-3 text-sm">
                <InfoRow label="Mode démo" value={gameSettings.demo_mode === 'MANUAL' ? 'Manuel' : 'Automatique'} />
                <InfoRow
                  label="Prochain multiplicateur manuel"
                  value={gameSettings.next_manual_target_multiplier ? `${gameSettings.next_manual_target_multiplier}x` : '—'}
                />
                <InfoRow label="Durée des paris" value={`${gameSettings.betting_duration_seconds}s`} />
                <InfoRow label="Mise minimum" value={formatAmount(gameSettings.min_bet)} />
                <InfoRow label="Mise maximum" value={formatAmount(gameSettings.max_bet)} />
                <InfoRow label="Marge maison" value={`${gameSettings.house_edge_percent}%`} />
                <InfoRow label="Dernière mise à jour" value={formatDate(gameSettings.updated_at)} />
              </div>
            ) : (
              <p className="text-sm text-zinc-500">Aucun réglage trouvé.</p>
            )}
          </section>

          {appSettings && (
            <AppSettingsPanel
              settings={appSettings}
              editable={isSuperAdmin}
              onSaved={(s) => {
                setAppSettings(s);
                showSuccess('Paramètres de l\'application mis à jour.');
              }}
              onError={showError}
            />
          )}
        </div>
      )}
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

function AppSettingsPanel({
  settings,
  editable,
  onSaved,
  onError,
}: {
  settings: AppSettingsRow;
  editable: boolean;
  onSaved: (s: AppSettingsRow) => void;
  onError: (msg: string) => void;
}) {
  const [currentVersion, setCurrentVersion] = useState(settings.current_version);
  const [minVersion, setMinVersion] = useState(settings.minimum_supported_version);
  const [downloadUrl, setDownloadUrl] = useState(settings.download_url);
  const [maintenanceMode, setMaintenanceMode] = useState(settings.maintenance_mode);
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      await updateAppSettings({
        current_version: currentVersion,
        minimum_supported_version: minVersion,
        download_url: downloadUrl,
        maintenance_mode: maintenanceMode,
      });
      onSaved({
        ...settings,
        current_version: currentVersion,
        minimum_supported_version: minVersion,
        download_url: downloadUrl,
        maintenance_mode: maintenanceMode,
      });
    } catch (err) {
      onError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  if (!editable) {
    return (
      <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-300">Application mobile</h2>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <InfoRow label="Version actuelle" value={settings.current_version} />
          <InfoRow label="Version minimale requise" value={settings.minimum_supported_version} />
          <InfoRow label="URL de téléchargement" value={settings.download_url} />
          <InfoRow label="Mode maintenance" value={settings.maintenance_mode ? 'Activé' : 'Désactivé'} />
        </div>
        <p className="mt-4 text-xs text-zinc-600">Réservé aux super administrateurs.</p>
      </section>
    );
  }

  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
      <h2 className="mb-4 text-sm font-semibold text-zinc-300">Application mobile (super admin)</h2>
      <form onSubmit={handleSubmit}>
        <FieldWrapper label="Version actuelle">
          <TextInput value={currentVersion} onChange={(e) => setCurrentVersion(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Version minimale supportée">
          <TextInput value={minVersion} onChange={(e) => setMinVersion(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="URL de téléchargement de l'APK">
          <TextInput type="url" value={downloadUrl} onChange={(e) => setDownloadUrl(e.target.value)} required />
        </FieldWrapper>
        <label className="mb-4 flex items-center gap-2 text-sm text-zinc-300">
          <input
            type="checkbox"
            checked={maintenanceMode}
            onChange={(e) => setMaintenanceMode(e.target.checked)}
            className="h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-violet-600 focus:ring-violet-500"
          />
          Activer le mode maintenance (bloque l'accès à l'application mobile)
        </label>
        <Button type="submit" variant="primary" disabled={saving}>
          {saving ? 'Enregistrement…' : 'Enregistrer'}
        </Button>
      </form>
    </section>
  );
}
