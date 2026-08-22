import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';
import { DeviceStatusBadge } from '../components/Badge';
import { Button } from '../components/Button';
import { listDevicesWithOwners, setDeviceStatus } from '../services/devices';
import type { DeviceWithOwner } from '../services/devices';
import type { DeviceStatus } from '../types/database';
import { formatDate } from '../lib/format';

export function DevicesPage() {
  const { hasPermission } = useAuth();
  const { showError, showSuccess } = useToast();
  const [devices, setDevices] = useState<DeviceWithOwner[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);

  const canManage = hasPermission('MANAGE_DEVICES');

  async function load() {
    setLoading(true);
    try {
      setDevices(await listDevicesWithOwners());
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

  async function handleSetStatus(device: DeviceWithOwner, status: DeviceStatus) {
    setBusyId(device.id);
    try {
      await setDeviceStatus(device.id, status);
      showSuccess('Statut de l\'appareil mis à jour.');
      await load();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Appareils</h1>
        <p className="text-sm text-zinc-500">Appareils autorisés à se connecter à l'application démo.</p>
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-800">
        <table className="min-w-full divide-y divide-zinc-800 text-sm">
          <thead className="bg-zinc-900/60">
            <tr className="text-left text-xs font-medium uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Utilisateur</th>
              <th className="px-4 py-3">Appareil</th>
              <th className="px-4 py-3">Plateforme</th>
              <th className="px-4 py-3">Statut</th>
              <th className="px-4 py-3">Première connexion</th>
              <th className="px-4 py-3">Dernière activité</th>
              {canManage && <th className="px-4 py-3 text-right">Actions</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {loading ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">Chargement…</td>
              </tr>
            ) : devices.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">Aucun appareil.</td>
              </tr>
            ) : (
              devices.map((d) => (
                <tr key={d.id} className="hover:bg-zinc-900/40">
                  <td className="px-4 py-3">
                    <div className="font-medium text-zinc-100">{d.owner_display_name ?? '—'}</div>
                    <div className="text-xs text-zinc-500">{d.owner_email ?? '—'}</div>
                  </td>
                  <td className="px-4 py-3 text-zinc-300">{d.device_name ?? d.device_identifier}</td>
                  <td className="px-4 py-3 text-zinc-400">{d.platform ?? '—'}</td>
                  <td className="px-4 py-3"><DeviceStatusBadge status={d.status} /></td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(d.first_seen)}</td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(d.last_seen)}</td>
                  {canManage && (
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-2">
                        {d.status !== 'ACTIVE' && (
                          <Button disabled={busyId === d.id} onClick={() => void handleSetStatus(d, 'ACTIVE')}>
                            Autoriser
                          </Button>
                        )}
                        {d.status !== 'BLOCKED' && (
                          <Button
                            variant="secondary"
                            disabled={busyId === d.id}
                            onClick={() => void handleSetStatus(d, 'BLOCKED')}
                          >
                            Bloquer
                          </Button>
                        )}
                        {d.status !== 'REVOKED' && (
                          <Button
                            variant="danger"
                            disabled={busyId === d.id}
                            onClick={() => void handleSetStatus(d, 'REVOKED')}
                          >
                            Révoquer
                          </Button>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
